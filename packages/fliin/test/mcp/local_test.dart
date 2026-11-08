import 'dart:typed_data';

import 'package:fliin/fliin.dart';
import 'package:fliin/src/mcp/local/gates.dart';
import 'package:fliin/src/mcp/local/index_source.dart';
import 'package:fliin/src/mcp/local/selection_store.dart';
import 'package:fliin/src/mcp/ports.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/fake_registry.dart';
import '../support/source_versions.dart';

/// Compte les lectures du pointeur.
final class _Counting implements Registry {
  @override
  bool get servesPro => true;

  final FakeRegistry _inner = FakeRegistry();
  int pointerReads = 0;

  @override
  Future<IndexPointer> fetchPointer() {
    pointerReads++;
    return _inner.fetchPointer();
  }

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      _inner.fetchFragment(fragment);

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) =>
      _inner.fetchManifest(ref, version);

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) => _inner.fetchBlob(sha256);
}

final _button = ItemRef('button');
final _core = ItemRef('core');

void main() {
  group('LocalIndexSource', () {
    test(
      'devrait relire le pointeur quand dix minutes ont passé, pas avant',
      () async {
        var now = DateTime.utc(2026, 10, 18, 12);
        final registry = _Counting();
        final source = LocalIndexSource(registry, clock: () => now);
        final first = await source.snapshot();
        now = now.add(const Duration(minutes: 9, seconds: 59));
        expect(identical(await source.snapshot(), first), isTrue);
        expect(registry.pointerReads, 1);

        now = now.add(const Duration(seconds: 1));
        expect(identical(await source.snapshot(), first), isFalse);
        expect(registry.pointerReads, 2);
      },
    );

    test('devrait donner la fermeture de button sans regarder Flutter quand on la demande', () async {
      final snapshot = await LocalIndexSource(_Counting()).snapshot();
      expect(snapshot.entry(_button)?.ref, _button);
      expect(snapshot.entry(ItemRef('absent')), isNull);
      final plan = snapshot.closure(_button, Version.parse(sourceVersion('button'))) as InstallPlan;
      expect(
        [for (final item in plan.items) item.ref],
        [_core, ItemRef('spinner'), _button],
      );
      expect(
        snapshot.closure(_button, Version(9, 0, 0)),
        isA<NoVersionMatches>(),
      );
    });
  });

  test(
    'devrait nommer les seize variantes comme verify quand on les énumère',
    () {
      expect([for (final variant in GoldenVariant.all) variant.id], variantIds);
    },
  );

  group('MemorySelectionStore', () {
    test(
      'devrait rendre pending puis le choix quand l\'humain tranche',
      () async {
        final store = MemorySelectionStore();
        final opened = await store.open(
          candidates: [_button, _core],
          question: 'Lequel ?',
          variant: const GoldenVariant(),
        );
        expect(opened.status, isA<Pending>());
        expect((await store.find(opened.handle))?.candidates, [_button, _core]);

        final settled = await store.settle(opened.handle, Chosen(_button));
        expect((settled?.status as Chosen).item, _button);
        expect(
          (await store.settle(opened.handle, const Declined()))?.status,
          isA<Chosen>(),
          reason: 'un choix ne se reprend pas',
        );
        expect((await store.find(opened.handle))?.status, isA<Chosen>());
        expect(opened.formToken, isNot(opened.handle.value));
        expect(opened.handle.value, hasLength(22), reason: '128 bits');
        expect(
          await store.settle(const SelectionHandle('x'), const Declined()),
          isNull,
        );
      },
    );

    test(
      'devrait oublier une sélection quand trente minutes ont passé',
      () async {
        var now = DateTime.utc(2026, 10, 18, 12);
        final store = MemorySelectionStore(clock: () => now);
        final opened = await store.open(
          candidates: [_button],
          question: '?',
          variant: const GoldenVariant(),
        );
        now = now.add(const Duration(minutes: 30));
        expect(await store.find(opened.handle), isNull);
        await store.open(
          candidates: [_button],
          question: '?',
          variant: const GoldenVariant(),
        );
        final forgotten = await store.open(
          candidates: [_core],
          question: '?',
          variant: const GoldenVariant(),
        );
        now = now.add(const Duration(minutes: 31));
        await store.open(
          candidates: [_button],
          question: '?',
          variant: const GoldenVariant(),
        );
        expect(
          store.length,
          1,
          reason: 'les sélections expirées, jamais relues, sont purgées',
        );
        expect(await store.find(forgotten.handle), isNull);
      },
    );
  });

  test('devrait tout accorder et tout admettre quand les portes sont celles de la V1', () async {
    final entry = (await LocalIndexSource(
      _Counting(),
    ).snapshot()).entry(_button)!;
    expect(await const AllEntitled().resolve(entry), Entitlement.granted);
    expect(await const Unlimited().admit(QuotaScope.item), isA<Admitted>());
  });
}

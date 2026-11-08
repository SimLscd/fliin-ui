import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/cli_version.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/manifest_edit.dart';
import 'support.dart';

final _signedAt = DateTime.utc(2026, 10, 18, 9, 30);

/// La mineure de button que les tests publient au-dessus de celle du dépôt.
final _next = nextMinor(sourceVersion('button'));

Future<String> _build(
  String source, {
  String? out,
  int? version,
  DateTime? now,
  List<ItemRef> yank = const [],
}) async {
  final dist = out ?? tempDir().path;
  await DistWriter(dist).write(
    SourceRegistry.read(source),
    stamp: BuildStamp.following(
      dist,
      version: version,
      now: now ?? _signedAt,
      yank: yank,
    ),
    key: await testKey(),
  );
  return dist;
}

Future<IndexPointer> _pointer(String dist, {DateTime? now}) async {
  final decision =
      await SignedPointer.fromJson(
        jsonDecode(
          File(p.join(dist, DistLayout.pointerPath)).readAsStringSync(),
        ),
      ).open(
        Ed25519PointerVerifier([(await testKey()).publicKey]),
        cachedVersion: null,
        now: now ?? _signedAt,
      );
  return (decision as PointerAccepted).pointer;
}

Future<IndexFragment> _fragment(String dist) async => IndexFragment.fromJson(
  jsonDecode(
    File(p.join(dist, (await _pointer(dist)).fragments.single.path))
        .readAsStringSync(),
  ),
);

/// Les éléments de la source, lus sur disque : l'index doit les garder tous.
Set<String> _itemNames(String source) => {
  for (final file in Directory(p.join(source, 'items')).listSync())
    if (file is File && file.path.endsWith('.json'))
      p.basenameWithoutExtension(file.path),
};

Map<String, List<String>> _versions(IndexFragment fragment) => {
  for (final entry in fragment.entries)
    entry.ref.name: [for (final v in entry.versions) '${v.version}'],
};

void main() {
  group('breaking[]', breakingTests);
  group('relecture', relectureBuildTests);
  group('variantes', () {
    Future<ItemManifest> icons(String source, String dist) async {
      final manifest = File(p.join(source, 'items', 'icons.json'))
          .readAsStringSync();
      final version = (jsonDecode(manifest) as Map<String, Object?>)['version'];
      return ItemManifest.fromJson(
        jsonDecode(
          File(p.join(dist, 'items', 'fliin', 'icons', '$version.json'))
              .readAsStringSync(),
        ),
      );
    }

    test('devrait publier chaque jeu d’icônes en blob, son empreinte dans le manifeste d’icons', () async {
      final source = copiedSource();
      final dist = await _build(source);
      final file = (await icons(source, dist)).files.single;
      expect(
        file.variants.keys,
        unorderedEquals(['lucide', 'tabler', 'phosphor']),
      );
      for (final MapEntry(key: name, value: variant) in file.variants.entries) {
        final raw = File(
          p.join(source, 'lib', 'icons', 'sets', name, 'fl_icons.dart'),
        ).readAsBytesSync();
        expect(variant.sha256, Sha256.ofBytes(raw), reason: name);
        expect(
          File(p.join(dist, DistLayout.blobPath(variant.sha256)))
              .readAsBytesSync(),
          raw,
          reason: name,
        );
      }
    });

    test('devrait refuser une variante qui n’a pas l’API publique du fichier qu’elle remplace', () async {
      final source = copiedSource();
      final lucide = File(
        p.join(source, 'lib', 'icons', 'sets', 'lucide', 'fl_icons.dart'),
      );
      lucide.writeAsStringSync(
        lucide.readAsStringSync().replaceFirst(
          'FlIconData pauseFill',
          'FlIconData pause',
        ),
      );
      expect(
        () => SourceRegistry.read(source),
        throwsA(
          isA<InvalidSourceManifest>().having(
            (e) => e.reason,
            'reason',
            allOf(
              contains('icons/sets/lucide/fl_icons.dart'),
              contains('pauseFill'),
            ),
          ),
        ),
      );
    });

    test('devrait refuser une variante dont le fichier manque', () {
      final source = copiedSource();
      File(p.join(source, 'lib', 'icons', 'sets', 'tabler', 'fl_icons.dart'))
          .deleteSync();
      expect(
        () => SourceRegistry.read(source),
        throwsA(isA<MissingSourceFile>()),
      );
    });
  });

  test('devrait produire les mêmes octets quand on construit deux fois la même source à la même date', () async {
    final source = copiedSource();
    final first = tree(await _build(source));
    final second = tree(await _build(source));
    expect(first.keys, contains(DistLayout.pointerPath));
    expect(second, first);
  });

  test('devrait garder un blob déjà publié à son empreinte sans le réécrire, et remplacer un blob abîmé, quand on reconstruit dans le même out', () async {
    final source = copiedSource();
    final dist = await _build(source);
    final blobs = [
      for (final f in Directory(
        p.join(dist, 'blobs'),
      ).listSync(recursive: true).whereType<File>())
        f,
    ];
    expect(blobs, isNotEmpty);
    final past = DateTime.utc(2001);
    for (final blob in blobs) {
      blob.setLastModifiedSync(past);
    }
    final damaged = blobs.first;
    final original = damaged.readAsBytesSync();
    damaged.writeAsBytesSync([...original.reversed]);
    damaged.setLastModifiedSync(past);

    await _build(source, out: dist, version: 2);

    expect(damaged.readAsBytesSync(), original, reason: 'blob abîmé remplacé');
    expect(
      [
        for (final blob in blobs.skip(1))
          if (!blob.lastModifiedSync().isAtSameMomentAs(past)) blob.path,
      ],
      isEmpty,
      reason: 'un blob intact n’est pas réécrit',
    );
  });

  test('devrait dater le pointeur de la signature et le numéroter 1 quand out est vide (synthèse #6)', () async {
    final dist = await _build(copiedSource());
    final pointer = await _pointer(dist);
    expect(pointer.version, 1);
    expect(pointer.publishedAt, _signedAt);
    expect(pointer.expires, isNull, reason: 'ADR 0020 §11 : le pointeur publié n’expire pas');
    expect('${pointer.minCli}', cliVersion);
    expect(
      pointer.fragments.single.sha256,
      Sha256.ofBytes(
        File(p.join(dist, pointer.fragments.single.path)).readAsBytesSync(),
      ),
    );
  });

  test('devrait numéroter après le pointeur déjà publié dans out, sans git, et refuser une version qui ne monte pas (synthèse #6)', () async {
    final source = copiedSource();
    final later = _signedAt.add(const Duration(days: 20));
    final dist = await _build(source);
    await _build(source, out: dist, now: later);
    final pointer = await _pointer(dist, now: later);
    expect(pointer.version, 2);
    expect(pointer.publishedAt, later);
    await expectLater(
      _build(source, out: dist, version: 2),
      throwsA(isA<PointerVersionNotIncreasing>()),
    );
    await _build(source, out: dist, version: 7);
    expect((await _pointer(dist)).version, 7);
  });

  test('devrait garder l\'ancien fragment lisible, à son empreinte, quand on republie (synthèse #7)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    final before = await _pointer(dist);
    final sha256 = before.fragments.single.sha256;
    expect(before.fragments.single.path, DistLayout.fragmentPath(sha256));

    bumpSource(source, 'button', _next, 'components/button/fl_button.dart');
    await _build(source, out: dist);
    final after = await _pointer(dist);
    expect(after.fragments.single.path, isNot(before.fragments.single.path));
    for (final fragment in [before, after].map((x) => x.fragments.single)) {
      expect(
        Sha256.ofBytes(File(p.join(dist, fragment.path)).readAsBytesSync()),
        fragment.sha256,
      );
    }
  });

  test('devrait garder les versions déjà publiées dans l\'index quand on publie une nouvelle version (synthèse #2, règle 12)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    final published = {
      for (final m in SourceRegistry.read(source).manifests)
        m.name: '${m.version}',
    };
    expect(published['button'], sourceVersion('button'));
    bumpSource(source, 'button', _next, 'components/button/fl_button.dart');
    await _build(source, out: dist);
    final fragment = await _fragment(dist);
    expect(_versions(fragment), {
      for (final name in _itemNames(source))
        name: name == 'button'
            ? [published['button']!, _next]
            : [published[name]!],
    });
    final button = fragment.entries.singleWhere((e) => e.ref.name == 'button');
    for (final release in button.versions) {
      final manifest = File(
        p.join(dist, DistLayout.manifestPath(button.ref, release.version)),
      );
      expect(
        Sha256.ofBytes(manifest.readAsBytesSync()),
        release.manifestSha256,
        reason: '${release.version}',
      );
    }
  });

  test('devrait retirer une version avec yank, garder ce retrait aux builds suivants et refuser un retrait d\'une version non publiée (tour 3, R3 ; règle 12)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    bumpSource(source, 'button', _next, 'components/button/fl_button.dart');
    await _build(source, out: dist);
    expect((await _pointer(dist)).yanked, isEmpty);

    final broken = ItemRef.parse('button@$_next');
    await _build(source, out: dist, yank: [broken]);
    expect((await _pointer(dist)).yanked.map((r) => '$r'), ['button@$_next']);
    expect(_versions(await _fragment(dist))['button'], [
      sourceVersion('button'),
      _next,
    ]);

    await _build(source, out: dist, yank: [broken]);
    expect((await _pointer(dist)).yanked.map((r) => '$r'), ['button@$_next']);
    final core = 'core@${sourceVersion('core')}';
    await _build(source, out: dist, yank: [ItemRef.parse(core)]);
    expect((await _pointer(dist)).yanked.map((r) => '$r'), [
      'button@$_next',
      core,
    ]);

    final before = tree(dist);
    await expectLater(
      _build(source, out: dist, yank: [ItemRef.parse('button@9.9.9')]),
      throwsA(isA<UnknownYank>()),
    );
    expect(tree(dist), before);
  });

  test('devrait indexer titre, description, catégories et dépendances de chaque élément', () async {
    final dist = await _build(copiedSource());
    final button = (await _fragment(dist)).entries
        .singleWhere((e) => e.ref.name == 'button');
    expect(button.title, 'Button');
    expect(button.categories, ['actions']);
    expect(button.description, startsWith('Triggers the main action'));
    final release = button.versions.single;
    final declared =
        (jsonDecode(
              File(p.join(sourceRoot, 'items', 'button.json'))
                  .readAsStringSync(),
            ) as Map<String, Object?>)['registryDependencies']!
            as List<Object?>;
    expect([
      '${release.registryDependencies.first}',
      '${release.registryDependencies.last}',
    ], declared);
    final manifest = File(
      p.join(dist, DistLayout.manifestPath(button.ref, release.version)),
    );
    expect(Sha256.ofBytes(manifest.readAsBytesSync()), release.manifestSha256);
  });

  test('devrait calculer l\'empreinte sur le brut aux fins de ligne LF quand le fichier est en CRLF', () async {
    final source = copiedSource();
    final file = File(p.join(source, 'lib/components/button/fl_button.dart'));
    final lf = file.readAsStringSync();
    file.writeAsStringSync(lf.replaceAll('\n', '\r\n'));
    final manifest = SourceRegistry.read(source).manifests
        .singleWhere((m) => m.name == 'button');
    final sha256 = manifest.files.single.sha256;
    expect(sha256, Sha256.ofString(lf));
    final dist = await _build(source);
    expect(
      File(p.join(dist, DistLayout.blobPath(sha256))).readAsStringSync(),
      lf,
    );
  });

  test(
    'devrait refuser la source quand un path du manifeste n\'existe pas',
    () async {
      final source = copiedSource();
      File(p.join(source, 'lib/components/button/fl_button.dart')).deleteSync();
      expect(
        () => SourceRegistry.read(source),
        throwsA(
          isA<MissingSourceFile>().having(
            (e) => e.path,
            'path',
            'components/button/fl_button.dart',
          ),
        ),
      );
    },
  );

  test('devrait refuser de republier une version quand son contenu a changé (règle 2)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    final before = tree(dist);
    File(p.join(source, 'lib/components/button/fl_button.dart'))
        .writeAsStringSync('// changé\n', mode: FileMode.append);
    await expectLater(
      _build(source, out: dist),
      throwsA(isA<PublishedVersionChanged>()),
    );
    expect(tree(dist), before);
  });

  test('devrait refuser de construire quand le latest.json déjà publié est illisible, en disant comment repartir (tour 3, R12)', () async {
    final source = copiedSource();
    final dist = await _build(source, version: 3);
    final latest = File(p.join(dist, DistLayout.pointerPath))
      ..writeAsStringSync('{');
    final unreadable = throwsA(
      isA<UnreadablePublished>().having(
        (e) => '$e',
        'message',
        allOf(
          contains(latest.path),
          contains('delete it'),
          contains('--version'),
        ),
      ),
    );
    await expectLater(_build(source, out: dist), unreadable);
    await expectLater(_build(source, out: dist, version: 9), unreadable);
    expect(latest.readAsStringSync(), '{');
    latest.deleteSync();
    await _build(source, out: dist, version: 9);
    expect((await _pointer(dist)).version, 9);
    expect(tree(dist).keys.where((k) => k.endsWith('.tmp')), isEmpty);
  });

  test('devrait garder la contrainte Flutter propre à chaque version publiée quand elles diffèrent', () async {
    final source = copiedSource();
    final dist = await _build(source);
    bumpSource(source, 'button', _next, 'components/button/fl_button.dart');
    final manifest = File(p.join(source, 'items/button.json'));
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceFirst(
        RegExp(r'"flutter": "[^"]+"'),
        '"flutter": ">=9.0.0"',
      ),
    );
    await _build(source, out: dist);
    final button = (await _fragment(dist)).entries
        .singleWhere((e) => e.ref.name == 'button');
    expect(
      {for (final v in button.versions) '${v.version}': v.flutter},
      {
        sourceVersion('button'): isNot(VersionConstraint.parse('>=9.0.0')),
        _next: VersionConstraint.parse('>=9.0.0'),
      },
    );
  });
}

ItemManifest _published(String dist, String item, String version) =>
    ItemManifest.fromJson(
      jsonDecode(
        File(
          p.join(
            dist,
            DistLayout.manifestPath(ItemRef(item), Version.parse(version)),
          ),
        ).readAsStringSync(),
      ),
    );

void _editSource(String root, String path, String Function(String text) edit) {
  final file = File(p.join(root, path));
  file.writeAsStringSync(edit(file.readAsStringSync()));
}

void breakingTests() {
  test('devrait écrire dans le manifeste signé les cassures que le diff de l’API publique trouve, plus celles que l’auteur déclare (DESIGN §4.4)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    _editSource(
      source,
      'lib/components/button/fl_button.dart',
      (text) => text
          .replaceFirst('    this.loading = false,\n', '')
          .replaceFirst(
            '  final bool loading;\n',
            '  bool get loading => false;\n',
          )
          .replaceFirst(
            '    required this.onPressed,\n',
            '    required this.onPressed,\n    required this.tooltip,\n',
          )
          .replaceFirst(
            '  final Widget? leading;\n',
            '  final Widget? leading;\n  final String tooltip;\n',
          ),
    );
    _editSource(
      source,
      'items/button.json',
      (text) =>
          withChangelog(
            withVersion(text, _next),
            'Infobulle obligatoire.',
          ).replaceFirst(
            '"l10n": {},',
            '"l10n": {},\n  "breaking": [{"kind": "semantic", "description": "Le chargement ne se règle plus."}],',
          ),
    );
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 1)),
    );

    final manifest = _published(dist, 'button', _next);
    expect(manifest.changelog, 'Infobulle obligatoire.');
    expect(manifest.breaking, [
      const ChangedSignature(
        'FlButton.new',
        before: 'const new({super.key, required String label, required VoidCallback? onPressed, FlButtonVariant variant, FlButtonSize? size, bool loading, Widget? leading, Widget? trailing, FlButtonFeedback feedback, WidgetStatesController? statesController, bool? selected, bool fullWidth})',
        after: 'const new({super.key, required String label, required VoidCallback? onPressed, required String tooltip, FlButtonVariant variant, FlButtonSize? size, Widget? leading, Widget? trailing, FlButtonFeedback feedback, WidgetStatesController? statesController, bool? selected, bool fullWidth})',
      ),
      const RequiredParameterAdded('FlButton.new', parameter: 'tooltip'),
      const SemanticBreak('Le chargement ne se règle plus.'),
    ]);
    final release = (await _fragment(dist)).entries
        .singleWhere((e) => e.ref.name == 'button')
        .versions
        .singleWhere((v) => v.version == Version.parse(_next));
    final bytes = File(
      p.join(
        dist,
        DistLayout.manifestPath(ItemRef('button'), Version.parse(_next)),
      ),
    ).readAsBytesSync();
    expect(
      Sha256.ofBytes(bytes),
      release.manifestSha256,
      reason: 'les cassures sont signées avec le manifeste',
    );
    expect(
      _published(dist, 'button', sourceVersion('button')).breaking,
      isEmpty,
    );
  });

  test('devrait calculer les cassures d’une version Pro dans le registre public avec les blobs du registre Pro, au manifeste près (ADR 0020 §4)', skip: withoutPro, () async {
    final source = copiedSource();
    final key = await testKey();
    Future<void> build(String out, {required bool pro, String? blobsFrom, required int version}) => DistWriter(out, blobsFrom: blobsFrom).write(
      pro ? SourceRegistry.read(source) : SourceRegistry.read(source).withoutProCode(),
      stamp: BuildStamp(version: version, publishedAt: _signedAt.add(Duration(minutes: version))),
      key: key,
    );
    final proDist = tempDir().path;
    final publicDist = tempDir().path;
    await build(proDist, pro: true, version: 1);
    await build(publicDist, pro: false, version: 1);
    final next = nextMinor(sourceVersion('empty-state'));
    _editSource(source, 'lib/components/empty_state/fl_empty_state.dart', (text) => text.replaceFirst('  final String title;\n', '  final String heading;\n'));
    _editSource(source, 'items/empty-state.json', (text) => withVersion(text, next));
    await build(proDist, pro: true, version: 2);
    expect(
      () => build(publicDist, pro: false, version: 2),
      throwsA(isA<UnreadablePublished>().having((e) => e.message, 'message', contains('--blobs-from'))),
    );
    await build(publicDist, pro: false, blobsFrom: proDist, version: 2);
    final path = DistLayout.manifestPath(ItemRef('empty-state'), Version.parse(next));
    expect(_published(proDist, 'empty-state', next).breaking, isNotEmpty);
    expect(File(p.join(publicDist, path)).readAsBytesSync(), File(p.join(proDist, path)).readAsBytesSync());
  });

  test('ne devrait déclarer aucune cassure quand la nouvelle version ne touche pas l’API publique', () async {
    final source = copiedSource();
    final dist = await _build(source);
    bumpSource(source, 'button', _next, 'components/button/fl_button.dart');
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 1)),
    );
    expect(_published(dist, 'button', _next).breaking, isEmpty);
  });

  test('devrait refuser un manifeste source qui déclare à la main une cassure calculée', () async {
    final source = copiedSource();
    _editSource(
      source,
      'items/button.json',
      (text) => text.replaceFirst(
        '"l10n": {},',
        '"l10n": {},\n  "breaking": [{"kind": "removed", "symbol": "FlButton"}],',
      ),
    );
    expect(
      () => SourceRegistry.read(source),
      throwsA(
        isA<InvalidSourceManifest>().having(
          (e) => e.reason,
          'reason',
          contains('only "semantic"'),
        ),
      ),
    );
  });
}

void relectureBuildTests() {
  test('devrait reconstruire une version déjà publiée quand un correctif a été intercalé depuis, en gardant ses cassures (H7)', () async {
    final source = copiedSource();
    final dist = await _build(source);
    _editSource(
      source,
      'lib/components/button/fl_button.dart',
      (t) => t.replaceFirst('    this.loading = false,\n', ''),
    );
    _editSource(source, 'items/button.json', (t) => withVersion(t, _next));
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 1)),
    );
    final patch = nextPatch(sourceVersion('button'));
    final v2 = File(p.join(source, 'lib/components/button/fl_button.dart'))
        .readAsStringSync();
    final published = _published(dist, 'button', _next);
    expect(published.breaking, isNotEmpty);

    File(p.join(source, 'lib/components/button/fl_button.dart'))
        .writeAsStringSync('$v2\n// $patch : même API que $_next\n');
    _editSource(source, 'items/button.json', (t) => withVersion(t, patch));
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 2)),
    );

    File(p.join(source, 'lib/components/button/fl_button.dart'))
        .writeAsStringSync(v2);
    _editSource(source, 'items/button.json', (t) => withVersion(t, _next));
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 3)),
    );
    expect(_published(dist, 'button', _next).toJson(), published.toJson());
  });

  test('devrait refuser de retirer le Pro quand un élément gratuit exige un élément Pro', skip: withoutPro, () {
    final root = copiedSource();
    final button = File(p.join(root, 'items', 'button.json'));
    final json = jsonDecode(button.readAsStringSync()) as Map<String, Object?>;
    json['registryDependencies'] = [
      ...json['registryDependencies']! as List<Object?>,
      'empty-state@^${sourceVersion('empty-state')}',
    ];
    button.writeAsStringSync(jsonEncode(json));
    expect(
      () => SourceRegistry.read(root).withoutProCode(),
      throwsA(isA<ProDependency>().having((e) => e.message, 'message', contains('button is free and requires empty-state'))),
    );
  });

  test('devrait refuser de construire sans le code Pro dans un out/ qui en contient déjà, sans rien écrire', skip: withoutPro, () async {
    final out = tempDir().path;
    final key = await testKey();
    await DistWriter(out).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: DateTime.utc(2026, 10, 22)),
      key: key,
    );
    final before = tree(out);
    expect(
      () => DistWriter(out).write(SourceRegistry.read(sourceRoot).withoutProCode(), stamp: BuildStamp(version: 2, publishedAt: DateTime.utc(2026, 10, 23)), key: key),
      throwsA(isA<ProAlreadyInOut>().having((e) => e.message, 'message', contains('--include-pro'))),
    );
    expect(tree(out), before);
  });

  test('devrait refuser un changelog vide dans le manifeste source', () {
    final source = copiedSource();
    _editSource(source, 'items/button.json', (t) => withChangelog(t, ' '));
    expect(
      () => SourceRegistry.read(source),
      throwsA(
        isA<InvalidSourceManifest>().having(
          (e) => e.reason,
          'reason',
          contains('changelog: empty'),
        ),
      ),
    );
  });

  test('devrait compter comme cassure un fichier Dart retiré d’une version à l’autre', () async {
    final source = copiedSource();
    File(p.join(source, 'lib/components/button/fl_button_extra.dart'))
        .writeAsStringSync('const flExtra = 1;\n');
    _editSource(
      source,
      'items/button.json',
      (t) => withFileAfter(
        t,
        '@components/button/fl_button.dart',
        '{ "path": "components/button/fl_button_extra.dart", "type": "registry:component", "target": "@components/button/fl_button_extra.dart" }',
      ),
    );
    final dist = await _build(source);
    _editSource(
      source,
      'items/button.json',
      (t) => withVersion(
        t.replaceFirst(
          ',\n    { "path": "components/button/fl_button_extra.dart", "type": "registry:component", "target": "@components/button/fl_button_extra.dart" }',
          '',
        ),
        _next,
      ),
    );
    await _build(
      source,
      out: dist,
      now: _signedAt.add(const Duration(minutes: 1)),
    );
    expect(
      _published(dist, 'button', _next).breaking,
      contains(
        const RemovedDeclaration('@components/button/fl_button_extra.dart'),
      ),
    );
  });
}

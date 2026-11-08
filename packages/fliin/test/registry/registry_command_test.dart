@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('devrait signer un latest.json que verify-pointer accepte quand on enchaîne keygen puis build, et prévenir quand out n\'a pas de latest.json (tour 3, R4)', () async {
    final dir = tempDir().path;
    final keyFile = p.join(dir, 'fliin-signing.key');
    final keygen = await fliin(['registry', 'keygen', '--out', keyFile]);
    expect(keygen.exitCode, 0, reason: '${keygen.stderr}');
    final publicKey = '${keygen.stdout}'.trim();
    expect(base64Decode(publicKey), hasLength(32));

    final source = copiedSource();
    final out = p.join(dir, 'dist');
    final build = await fliin([
      'registry',
      'build',
      '--source',
      source,
      '--out',
      out,
      '--key',
      keyFile,
      '--json',
    ]);
    expect(build.exitCode, 0, reason: '${build.stderr}');
    final expected = SourceRegistry.read(source).withoutProCode();
    expect(jsonDecode('${build.stdout}'), {
      'items': expected.manifests.length,
      'blobs': expected.blobs.length,
      'pointerVersion': 1,
    });
    expect(
      '${build.stderr}',
      allOf(
        contains('No latest.json'),
        contains('version 1'),
        contains(
          'No previous version in $out, so no breaking change was computed',
        ),
      ),
      reason: 'tour 3, R4 : un out vide repart de 1, il faut le dire',
    );
    final again = await fliin([
      'registry',
      'build',
      '--source',
      source,
      '--out',
      out,
      '--key',
      keyFile,
      '--json',
    ]);
    expect(again.exitCode, 0, reason: '${again.stderr}');
    expect('${again.stderr}', isEmpty);
    expect(
      (jsonDecode('${again.stdout}') as Map<String, Object?>)['pointerVersion'],
      2,
    );

    final latest = p.join(out, 'latest.json');
    final accepted = await fliin([
      'registry',
      'verify-pointer',
      latest,
      '--key',
      publicKey,
    ]);
    expect(accepted.exitCode, 0, reason: '${accepted.stderr}');
    final other = (await testKey(9)).publicKey;
    expect(
      (await fliin(['registry', 'verify-pointer', latest, '--key', other]))
          .exitCode,
      5,
    );
  });

  test('devrait faire connaître le Pro sans servir son code sans --include-pro, et tout garder avec (ADR 0020 §4)', skip: withoutPro, () async {
    final dir = tempDir().path;
    final keyFile = p.join(dir, 'fliin-signing.key');
    expect((await fliin(['registry', 'keygen', '--out', keyFile])).exitCode, 0);
    final source = SourceRegistry.read(sourceRoot);
    final pro = [
      for (final manifest in source.manifests)
        if (manifest.meta.tier == Tier.pro) manifest,
    ];
    expect(pro.map((m) => m.name), containsAll(['empty-state', 'account-settings']));
    for (final (flag, served) in [(<String>[], false), (['--include-pro'], true)]) {
      final out = p.join(dir, served ? 'pro' : 'public');
      final build = await fliin([
        'registry',
        'build',
        '--source',
        sourceRoot,
        '--out',
        out,
        '--key',
        keyFile,
        ...flag,
      ]);
      expect(build.exitCode, 0, reason: '${build.stderr}');
      final index = [
        for (final file in Directory(
          p.join(out, 'index'),
        ).listSync().whereType<File>())
          for (final entry
              in (jsonDecode(file.readAsStringSync())
                      as Map<String, Object?>)['entries']!
                  as List<Object?>)
            (entry! as Map<String, Object?>)['ref'],
      ];
      for (final manifest in pro) {
        final reason = '${manifest.name} ${served ? 'avec' : 'sans'} --include-pro';
        expect(index, contains(manifest.name), reason: reason);
        expect(Directory(p.join(out, 'items', Namespace.fliin.bare, manifest.name)).existsSync(), isTrue, reason: reason);
        for (final file in manifest.files) {
          expect(File(p.join(out, DistLayout.blobPath(file.sha256))).existsSync(), served, reason: '$reason, ${file.path}');
        }
        for (final sha in manifest.verify?.goldens?.variants.values ?? const <Sha256>[]) {
          expect(File(p.join(out, DistLayout.blobPath(sha))).existsSync(), isTrue, reason: '$reason, golden');
        }
      }
    }
    final over = await fliin([
      'registry', 'build', '--source', sourceRoot, '--out', p.join(dir, 'pro'), '--key', keyFile,
    ]);
    expect(over.exitCode, 1, reason: 'sans --include-pro sur un out/ qui a le code Pro');
    expect('${over.stderr}', contains('--include-pro'));
  });

  test('devrait signer les retraits de --yank, cumulés avec ceux du latest.json précédent, et refuser un --yank sans version (tour 3, R3)', () async {
    final dir = tempDir().path;
    final keyFile = p.join(dir, 'fliin-signing.key');
    expect((await fliin(['registry', 'keygen', '--out', keyFile])).exitCode, 0);
    final out = p.join(dir, 'dist');
    Future<ProcessResult> build(List<String> extra) => fliin([
      'registry',
      'build',
      '--source',
      sourceRoot,
      '--out',
      out,
      '--key',
      keyFile,
      ...extra,
    ]);
    List<Object?> yanked() {
      final signed = SignedPointer.fromJson(
        jsonDecode(File(p.join(out, 'latest.json')).readAsStringSync()),
      );
      return IndexPointer.fromJson(jsonDecode(signed.payload)).yanked
          .map((r) => '$r')
          .toList();
    }

    expect((await build([])).exitCode, 0);
    expect(yanked(), isEmpty);
    final button = 'button@${sourceVersion('button')}';
    final core = 'core@${sourceVersion('core')}';
    final first = await build(['--yank', button]);
    expect(first.exitCode, 0, reason: '${first.stderr}');
    expect(yanked(), [button]);
    final second = await build(['--yank', core, '--yank', button]);
    expect(second.exitCode, 0, reason: '${second.stderr}');
    expect(yanked(), [button, core]);

    final unversioned = await build(['--yank', 'button']);
    expect(unversioned.exitCode, 64);
    expect('${unversioned.stderr}', contains('--yank'));
    final unknown = await build(['--yank', 'button@9.9.9']);
    expect(unknown.exitCode, 1);
    expect('${unknown.stderr}', contains('button@9.9.9'));
  });

  test('devrait sortir 5 en nommant la version vue, la version reçue et le cache quand le registre a reculé (règle 12 ; tour 3, R4)', () async {
    final dir = tempDir().path;
    final home = p.join(dir, 'home');
    final out = p.join(dir, 'dist');
    final key = await testKey();
    Future<void> build(int version) => DistWriter(out).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: version, publishedAt: DateTime.now()),
      key: key,
    );
    List<String> search() => [
      'search',
      "bouton d'action principal",
      '--registry',
      '${Directory(out).uri}',
      '--key',
      key.publicKey,
    ];
    await build(5);
    final accepted = await fliin(search(), home: home);
    expect(accepted.exitCode, 0, reason: '${accepted.stderr}');
    await build(4);
    final refused = await fliin(search(), home: home);
    expect(refused.exitCode, 5, reason: '${refused.stderr}');
    expect(
      '${refused.stderr}',
      allOf(
        contains('older than the last one accepted'),
        contains('received version 4'),
        contains('already saw 5'),
        contains(p.join(home, '.cache', 'fliin')),
        contains('pointer.version'),
      ),
    );
  });

  test('devrait sortir en 3 quand la clé de signature est absente', () async {
    final dir = tempDir().path;
    final build = await fliin([
      'registry',
      'build',
      '--source',
      sourceRoot,
      '--out',
      p.join(dir, 'dist'),
      '--key',
      p.join(dir, 'absente.key'),
    ]);
    expect(build.exitCode, 3);
  });

  test(
    'devrait refuser d\'écraser une clé quand keygen vise un fichier existant',
    () async {
      final keyFile = p.join(tempDir().path, 'fliin-signing.key');
      expect(
        (await fliin(['registry', 'keygen', '--out', keyFile])).exitCode,
        0,
      );
      expect(
        (await fliin(['registry', 'keygen', '--out', keyFile])).exitCode,
        1,
      );
    },
  );
}

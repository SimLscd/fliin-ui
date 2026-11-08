import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart';

late String _dist;
late String _publicKey;

List<String> _search(String intent, [List<String> extra = const []]) => [
  'search',
  intent,
  '--registry',
  '${Directory(_dist).uri}',
  '--key',
  _publicKey,
  ...extra,
];

void main() {
  setUpAll(() async {
    _dist = tempDir().path;
    final key = await testKey();
    _publicKey = key.publicKey;
    await DistWriter(_dist).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: DateTime.now()),
      key: key,
    );
  });

  test('devrait imprimer button en JSON quand on cherche « bouton d\'action principal »', () async {
    final result = await fliin(
      _search("bouton d'action principal", ['--json']),
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final first =
        ((jsonDecode('${result.stdout}') as Map<String, Object?>)['results']!
                as List<Object?>)
            .first;
    expect(first, containsPair('id', 'button'));
    expect(
      first,
      containsPair('requires', [
        'core@${sourceVersion('core')}',
        'spinner@${sourceVersion('spinner')}',
      ]),
    );
    expect(first, containsPair('install', 'fliin add button'));
    expect(first, containsPair('entitled', true));
    expect(first, containsPair('previewUrl', null));
    expect(
      (first! as Map<String, Object?>)['apiSummary'],
      contains('FlButton.new: const new({super.key, required String label'),
      reason: 'les signatures publiques, comme le MCP',
    );
  });

  test('devrait sortir 0 avec button sans apiSummary, raison donnée, quand le registre ne sert pas son fichier', () async {
    final dist = tempDir().path;
    final key = await testKey();
    await DistWriter(dist).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: DateTime.now()),
      key: key,
    );
    final sha = Sha256.ofBytes(
      File(p.join(sourceRoot, 'lib', 'components', 'button', 'fl_button.dart'))
          .readAsBytesSync(),
    );
    File(p.join(dist, DistLayout.blobPath(sha))).deleteSync();
    final result = await fliin([
      'search',
      "bouton d'action principal",
      '--registry',
      '${Directory(dist).uri}',
      '--key',
      key.publicKey,
      '--json',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final results =
        ((jsonDecode('${result.stdout}') as Map<String, Object?>)['results']!
                as List<Object?>)
            .cast<Map<String, Object?>>();
    final button = results.firstWhere((r) => r['id'] == 'button');
    expect(button['apiSummary'], isNull);
    expect(button['unavailable'], contains(sha.hex.substring(0, 2)));
    expect([
      for (final r in results)
        if (r['id'] != 'button') r['apiSummary'],
    ], everyElement(isNotEmpty));
  });

  test('devrait lire le registre et ses clés dans fliin.yaml quand --registry est absent', () async {
    final project = tempDir().path;
    File(p.join(project, 'fliin.yaml')).writeAsStringSync('''
root: lib/ui/fliin
prefix: Fl
package: demo
registries:
  '@fliin':
    url: ${Directory(_dist).uri}
    trustedKeys: [$_publicKey]
''');
    final result = await fliin([
      'search',
      'valider un formulaire',
    ], workingDirectory: project);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      LineSplitter.split('${result.stdout}').first,
      'button ${sourceVersion('button')}',
    );
  });

  test('devrait lire fliin.yaml du projet désigné par -C quand on cherche depuis un autre dossier (synthèse #10)', () async {
    final project = tempDir().path;
    File(p.join(project, 'fliin.yaml')).writeAsStringSync('''
root: lib/ui/fliin
prefix: Fl
package: demo
registries:
  '@fliin':
    url: ${Directory(_dist).uri}
    trustedKeys: [$_publicKey]
''');
    final result = await fliin([
      '-C',
      project,
      'search',
      'valider un formulaire',
      '--json',
    ], workingDirectory: tempDir().path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final first =
        ((jsonDecode('${result.stdout}') as Map<String, Object?>)['results']!
                as List<Object?>)
            .first;
    expect(first, containsPair('id', 'button'));
  });

  test(
    'devrait sortir en 1 quand le fliin.yaml du projet n\'est pas du YAML',
    () async {
      final project = tempDir().path;
      File(p.join(project, 'fliin.yaml')).writeAsStringSync('root: [\n');
      final result = await fliin([
        '-C',
        project,
        'search',
        'valider un formulaire',
      ]);
      expect(result.exitCode, 1);
      expect('${result.stderr}', contains('fliin.yaml'));
    },
  );

  test('devrait sortir en 64 avec INVALID_INPUT et des suggestions quand l\'intention fait 2 mots', () async {
    final result = await fliin(_search('bouton principal', ['--json']));
    expect(result.exitCode, 64);
    final error = jsonDecode('${result.stdout}') as Map<String, Object?>;
    expect(error['code'], 'INVALID_INPUT');
    expect(error['details'], {
      'suggestions': isA<List<Object?>>()
          .having(
            (s) => s.first,
            'première',
            contains("bouton d'action principal"),
          )
          .having((s) => s.length, 'nombre', inInclusiveRange(1, 3)),
    });
  });

  test('devrait sortir en 5 quand latest.json est falsifié', () async {
    final forged = tempDir().path;
    for (final MapEntry(key: path, value: bytes) in tree(_dist).entries) {
      File(p.join(forged, path))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
    final latest = File(p.join(forged, DistLayout.pointerPath));
    latest.writeAsStringSync(
      latest.readAsStringSync().replaceFirst(
        r'\"version\":1',
        r'\"version\":7',
      ),
    );
    final result = await fliin([
      'search',
      "bouton d'action principal",
      '--registry',
      '${Directory(forged).uri}',
      '--key',
      _publicKey,
    ]);
    expect(result.exitCode, 5);
  });
}

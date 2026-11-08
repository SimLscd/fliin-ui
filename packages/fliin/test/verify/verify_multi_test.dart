@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/fliin.dart' show run;
import 'package:fliin/src/project/flutter_sdk.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart'
    show compiledCli, copiedSource, tempDir, testKey;
import '../support/cli.dart';
import '../support/fake_registry.dart';
import '../support/temp_project.dart';

const _one = ['--variants', 'ios.light.1.0.ltr'];

/// Le registre source, avec `verify.entry` remplacé pour les éléments de
/// [entries].
FakeRegistry _withEntries(Map<String, String> entries) {
  final registry = FakeRegistry();
  for (final MapEntry(key: name, value: entry) in entries.entries) {
    final json = jsonDecode(
      jsonEncode(registry.manifests[ItemRef(name)]!.toJson()),
    ) as Map<String, Object?>;
    (json['verify']! as Map<String, Object?>)['entry'] = entry;
    registry.manifests[ItemRef(name)] = ItemManifest.fromJson(json);
  }
  return registry;
}

Map<String, Object?> _withoutTiming(Object? report) =>
    {...report! as Map<String, Object?>}..remove('elapsedMs');

List<Map<String, Object?>> _items(CliRun run) =>
    (jsonOf(run)['items']! as List<Object?>).cast<Map<String, Object?>>();

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await createFlutterProject('verify_multi_app');
    expect((await fliin(dir, ['init'])).code, 0);
    expect((await fliin(dir, ['add', 'separator', 'text', 'surface'])).code, 0);
  });
  tearDownAll(deleteCreatedProjects);

  test('devrait rendre sous items, dans l’ordre demandé, l’objet que chaque élément rendrait seul quand on vérifie deux éléments en --json', () async {
    final variants = ['--variants', 'ios.light.1.0.ltr,android.dark.2.0.rtl'];
    final alone = {
      for (final name in ['separator', 'text'])
        name: await fliin(dir, ['verify', name, '--json', ...variants]),
    };
    for (final run in alone.values) {
      expect(run.code, 0, reason: run.err);
    }
    final both = await fliin(dir, [
      'verify',
      'separator',
      'text',
      '--json',
      ...variants,
    ]);
    expect(both.code, 0, reason: both.err);
    final items = _items(both);
    expect(items.map((item) => item['item']), ['separator', 'text']);
    for (final item in items) {
      expect(
        _withoutTiming(item),
        _withoutTiming(jsonOf(alone[item['item']]!)),
      );
      expect(item['summary'], ['2/2 variants pass']);
      final report = File(
        p.join(dir.path, 'build/fliin/verify/${item['item']}/report.json'),
      );
      expect(
        _withoutTiming(jsonDecode(report.readAsStringSync())),
        _withoutTiming(item),
      );
    }
  });

  test('devrait refuser l’élément dont un fichier ne passe pas l’analyse et rendre l’autre, en sortant 2, quand on vérifie les deux', () async {
    final file = File(
      p.join(dir.path, 'lib/ui/fliin/components/separator/fl_separator.dart'),
    );
    final original = file.readAsStringSync();
    addTearDown(() => file.writeAsStringSync(original));
    file.writeAsStringSync('$original\nfinal Object broken = Undefined();\n');
    final run = await fliin(dir, ['verify', 'text', 'separator', ..._one]);
    expect(run.code, 2, reason: run.err);
    expect(run.err, contains('dart analyze rejects separator'));
    expect(run.err, contains('fl_separator.dart'));
    expect(run.err, isNot(contains('flutter test')));
    final lines = run.out.trim().split('\n');
    expect(lines.first, matches(RegExp(r'^text@\S+: 1/1 variants pass$')));
    expect(run.out, isNot(contains('separator@')));
  });

  test('devrait mettre en échec le seul élément dont le test ne compile pas quand il partage flutter test avec des éléments sains, avant et après lui', () async {
    final run = await fliin(dir, [
      'verify',
      'text',
      'separator',
      'surface',
      '--json',
      ..._one,
    ], registry: _withEntries({'separator': 'Inexistant()'}));
    expect(run.code, 2, reason: run.err);
    final [text, separator, surface] = _items(run);
    final error = separator['error']! as Map<String, Object?>;
    expect(error['code'], 2);
    expect(error['message'], contains('produced no report'));
    expect(error['message'], contains('Inexistant'));
    for (final healthy in [text, surface]) {
      expect(healthy['summary'], ['1/1 variants pass']);
      expect((healthy['test']! as Map<String, Object?>)['exitCode'], 0);
    }
    expect(run.err, isNot(contains('flutter test failed')));
  });

  test('devrait sortir avec le code le plus grave des éléments, quelle que soit sa position, quand l’un déborde et qu’un autre ne compile pas', () async {
    final registry = _withEntries({
      'separator': 'Row(children: [const SizedBox(width: 3000)])',
      'surface': 'Inexistant()',
    });
    final failing = await fliin(dir, [
      'verify',
      'separator',
      'text',
      ..._one,
    ], registry: registry);
    expect(failing.code, 1, reason: failing.err);
    expect(
      failing.out,
      matches(
        RegExp(
          r'^separator@\S+: .*\btext@\S+: 1/1 variants pass',
          dotAll: true,
        ),
      ),
    );
    final all = await fliin(dir, [
      'verify',
      'surface',
      'separator',
      'text',
      ..._one,
    ], registry: registry);
    expect(all.code, 2, reason: all.err);
  });

  test('devrait faire sortir 1 le seul élément dont golden/ n’a pas été créé par verify quand deux éléments sont vérifiés', () async {
    final taken = Directory(
      p.join(dir.path, 'build/fliin/verify-taken/separator/golden'),
    )..createSync(recursive: true);
    final run = await fliin(dir, [
      'verify',
      'separator',
      'text',
      '--out',
      'build/fliin/verify-taken',
      '--json',
      ..._one,
    ]);
    expect(run.code, 1, reason: run.err);
    final [separator, text] = _items(run);
    expect(
      (separator['error']! as Map<String, Object?>)['message'],
      contains('exists and fliin verify did not create it'),
    );
    expect(text['summary'], ['1/1 variants pass']);
    expect(taken.existsSync(), isTrue);
  });

  test('devrait sortir 1 sans rien rendre quand le manifeste d’un des éléments n’a pas de verify', () async {
    final registry = FakeRegistry();
    final json = jsonDecode(
      jsonEncode(registry.manifests[ItemRef('separator')]!.toJson()),
    ) as Map<String, Object?>..remove('verify');
    registry.manifests[ItemRef('separator')] = ItemManifest.fromJson(json);
    final run = await fliin(dir, [
      'verify',
      'text',
      'separator',
      '--out',
      'build/sans-verify',
      ..._one,
    ], registry: registry);
    expect(run.code, 1);
    expect(
      run.err,
      contains('The manifest of separator has no verify entry'),
    );
    expect(
      Directory(p.join(dir.path, 'build/sans-verify')).existsSync(),
      isFalse,
    );
  });

  test('devrait rendre pour l’élément dont un fichier installé manque l’issue qu’il aurait seul, et vérifier les autres', () async {
    final file = File(
      p.join(dir.path, 'lib/ui/fliin/components/text/fl_text.dart'),
    );
    final original = file.readAsStringSync();
    addTearDown(() => file.writeAsStringSync(original));
    file.deleteSync();
    final alone = await fliin(dir, ['verify', 'text', '--json', ..._one]);
    expect(alone.code, 3, reason: alone.err);
    final run = await fliin(dir, [
      'verify',
      'separator',
      'text',
      '--json',
      ..._one,
    ]);
    expect(run.code, 3, reason: run.err);
    final [separator, text] = _items(run);
    expect(separator['summary'], ['1/1 variants pass']);
    expect(text, jsonOf(alone));
    expect(
      (text['error']! as Map<String, Object?>)['message'],
      contains('fl_text.dart'),
    );
  });

  test('devrait garder sur son seul élément la cause d’un flutter_tester qui tombe quand il partage flutter test', () async {
    final file = File(
      p.join(dir.path, 'lib/ui/fliin/components/separator/fl_separator.dart'),
    );
    final original = file.readAsStringSync();
    addTearDown(() => file.writeAsStringSync(original));
    file.writeAsStringSync(
      original
          .replaceFirst(
            "import 'package:flutter/widgets.dart';",
            "import 'dart:io' as io;\n\nimport 'package:flutter/widgets.dart';",
          )
          .replaceFirst(
            'Widget build(BuildContext context) {',
            'Widget build(BuildContext context) {\n    io.exit(3);',
          ),
    );
    final run = await fliin(dir, [
      'verify',
      'text',
      'separator',
      '--json',
      ..._one,
    ]);
    expect(run.code, 2, reason: run.err);
    final [text, separator] = _items(run);
    expect(text['summary'], ['1/1 variants pass']);
    final message =
        (separator['error']! as Map<String, Object?>)['message']! as String;
    expect(message, contains('produced no report'));
    // La cause que flutter_tools écrit varie selon la course entre la mort
    // du tester et la fin du test (« Shell subprocess crashed », « Cannot
    // add event ») ; seule la console la porte, avec « did not complete ».
    expect(message, contains('separator_verify_test.dart'));
    expect(message, contains('did not complete'));
    expect(message, isNot(contains('text_verify_test.dart')));
  });

  test('devrait ouvrir le registre une seule fois quand plusieurs éléments sont vérifiés', () async {
    for (final name in ['separator', 'text']) {
      Directory(p.join(dir.path, 'build/fliin/verify-once/$name/golden'))
          .createSync(recursive: true);
    }
    var opened = 0;
    final code = await run(
      [
        '-C',
        dir.path,
        'verify',
        'separator',
        'text',
        '--out',
        'build/fliin/verify-once',
        ..._one,
      ],
      openRegistry: (_) async {
        opened++;
        return FakeRegistry();
      },
      io: (out: StringBuffer(), err: StringBuffer()),
    );
    expect(code, 1);
    expect(opened, 1);
  });

  test('devrait écrire stderr et stdout dans l’ordre de main quand un seul élément est vérifié en --json', () async {
    Future<String> interleaved(List<String> args) async {
      final both = StringBuffer();
      await run(
        ['-C', dir.path, 'verify', 'text', '--json', ..._one, ...args],
        openRegistry: (_) async => FakeRegistry(),
        io: (out: both, err: both),
      );
      return '$both';
    }

    final failed = await interleaved(['--entry', 'Inexistant()']);
    expect(failed.indexOf('flutter test produced no report'), 0);
    expect(failed.indexOf('{"error"'), greaterThan(0));
    final rendered = await interleaved([
      '--strict',
      '--entry',
      'const SizedBox(width: 10, height: 10)',
    ]);
    expect(rendered.indexOf('{"item"'), 0);
    expect(
      rendered.indexOf('--strict requires a comparable reference'),
      greaterThan(0),
    );
  });

  test('devrait refuser --entry et --import (code 64) quand plusieurs éléments sont demandés', () async {
    for (final option in [
      ['--entry', 'SizedBox()'],
      ['--import', 'lib/main.dart'],
    ]) {
      final run = await fliin(dir, ['verify', 'separator', 'text', ...option]);
      expect(run.code, 64, reason: option.first);
      expect(run.err, contains('--entry and --import render a single item'));
    }
  });

  test('devrait refuser (code 64) un élément demandé deux fois, même écrit avec son espace de noms', () async {
    for (final args in [
      ['text', 'separator', 'text'],
      ['text', '@fliin/text'],
    ]) {
      final run = await fliin(dir, ['verify', ...args]);
      expect(run.code, 64, reason: '$args');
      expect(run.err, contains('text is requested twice'));
    }
  });

  test('devrait refuser (code 64) deux éléments distincts du même nom, qui partageraient leur dossier de sortie', () async {
    final run = await fliin(dir, ['verify', 'text', '@acme/text']);
    expect(run.code, 64);
    expect(
      run.err,
      contains('text and @acme/text would both write under'),
    );
  });

  test('devrait sortir 1 sans rien rendre quand un des éléments demandés n’est pas installé', () async {
    final run = await fliin(dir, [
      'verify',
      'text',
      'carousel',
      '--out',
      'build/absent',
      ..._one,
    ]);
    expect(run.code, 1);
    expect(
      run.err,
      contains('carousel is not installed. Run fliin add carousel.'),
    );
    expect(Directory(p.join(dir.path, 'build/absent')).existsSync(), isFalse);
  });

  test('devrait dire --all et --changed quand aucun élément n’est nommé, et refuser de les mêler à une liste', () async {
    final none = await fliin(dir, ['verify']);
    expect(none.code, 64);
    expect(none.err, contains('Expected an item, or --all'));
    expect(none.err, contains('--changed'));
    expect((await fliin(dir, ['verify', '--all', 'text'])).code, 64);
    expect((await fliin(dir, ['verify', '--all', '--changed'])).code, 64);
  });

  test('devrait nommer sans le rendre l’élément retenu par --changed dont le manifeste n’a pas de verify, et sortir 0', () async {
    final registry = FakeRegistry();
    final json = jsonDecode(
      jsonEncode(registry.manifests[ItemRef('separator')]!.toJson()),
    ) as Map<String, Object?>..remove('verify');
    registry.manifests[ItemRef('separator')] = ItemManifest.fromJson(json);
    final file = File(
      p.join(dir.path, 'lib/ui/fliin/components/separator/fl_separator.dart'),
    );
    final before = file.readAsStringSync();
    addTearDown(() => file.writeAsStringSync(before));
    file.writeAsStringSync('$before\n// local\n');
    final run = await fliin(dir, [
      'verify',
      '--changed',
      ..._one,
    ], registry: registry);
    expect(run.code, 0, reason: run.err);
    expect(run.out, '--changed: no verifiable item is touched by a local change\n  no verify entry, not rendered: separator\n');
  });

  test('devrait suggérer l’élément installé le plus proche quand le nom est mal tapé', () async {
    final run = await fliin(dir, ['verify', 'texte', ..._one]);
    expect(run.code, 1);
    expect(run.err, contains('texte is not installed. Did you mean text?'));
  });

  group('avec le vrai CLI et un SDK qui journalise ses appels', () {
    late String journal;
    late File afterTest;
    late Directory app;
    late Map<String, String> environment;

    setUpAll(() async {
      final source = copiedSource();
      final surface = File(p.join(source, 'items', 'surface.json'));
      final manifest =
          jsonDecode(surface.readAsStringSync()) as Map<String, Object?>;
      (manifest['verify']! as Map<String, Object?>)['entry'] =
          'const SizedBox.expand(child: ColoredBox(color: Color(0xFFFF0000)))';
      surface.writeAsStringSync(jsonEncode(manifest));
      final dist = tempDir().path;
      final key = await testKey();
      await DistWriter(dist).write(
        SourceRegistry.read(source),
        stamp: BuildStamp.following(dist),
        key: key,
      );
      final real = await FlutterSdk.locate(Platform.environment);
      final sdk = tempDir();
      journal = p.join(sdk.path, 'journal.txt');
      afterTest = File(p.join(sdk.path, 'after-test.sh'));
      for (final tool in ['flutter', 'dart']) {
        final executable = p.join(real.root.path, 'bin', tool);
        final script = File(p.join(sdk.path, 'bin', tool))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            '#!/bin/sh\n'
            'echo "$tool \$1" >> "$journal"\n'
            'if [ "\$1" = test ] && [ -f "${afterTest.path}" ]; then\n'
            '  "$executable" "\$@"; code=\$?; sh "${afterTest.path}"; exit \$code\n'
            'fi\n'
            'exec "$executable" "\$@"\n',
          );
        await Process.run('chmod', ['+x', script.path]);
      }
      environment = {'HOME': tempDir().path, 'FLIIN_FLUTTER_ROOT': sdk.path};
      app = await createFlutterProject('verify_journal_app');
      for (final args in [
        [
          'init',
          '--registry',
          '${Directory(dist).uri}',
          '--trusted-key',
          key.publicKey,
        ],
        ['add', 'separator', 'text', 'surface'],
      ]) {
        final run = await _cli(app, args, environment);
        expect(run.exitCode, 0, reason: '${run.stderr}');
      }
    });

    test('devrait lancer un seul dart analyze et un seul flutter test quand deux éléments qui passent sont vérifiés', () async {
      File(journal).writeAsStringSync('');
      final run = await _cli(app, [
        'verify',
        'separator',
        'text',
        '--json',
        ..._one,
      ], environment);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final items =
          (jsonDecode('${run.stdout}') as Map<String, Object?>)['items']!
              as List<Object?>;
      expect(items, hasLength(2));
      final calls = File(journal).readAsLinesSync();
      expect(calls.where((call) => call == 'dart analyze'), hasLength(1));
      expect(calls.where((call) => call == 'flutter test'), hasLength(1));
    });

    test('devrait rendre sous --all tout élément installé, core compris, en un seul flutter test', () async {
      File(journal).writeAsStringSync('');
      final run = await _cli(app, ['verify', '--all', '--json', ..._one], environment);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
      expect(json['selection'], 'all');
      expect(_itemsOf(run).map((i) => i['item']), unorderedEquals(['core', 'separator', 'text', 'surface']));
      expect(json['skipped'], isEmpty);
      final calls = File(journal).readAsLinesSync();
      expect(calls.where((call) => call == 'flutter test'), hasLength(1));
    });

    test('devrait ne rendre sous --changed que l’élément modifié, et rien quand rien ne l’est', () async {
      final quiet = await _cli(app, ['verify', '--changed'], environment);
      expect(quiet.exitCode, 0, reason: '${quiet.stderr}');
      expect('${quiet.stdout}', contains('--changed: no verifiable item is touched'));

      final text = File(p.join(app.path, 'lib/ui/fliin/components/text/fl_text.dart'));
      final before = text.readAsStringSync();
      addTearDown(() => text.writeAsStringSync(before));
      text.writeAsStringSync('$before\n// local\n');
      final run = await _cli(app, ['verify', '--changed', '--json', ..._one], environment);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect((jsonDecode('${run.stdout}') as Map<String, Object?>)['selection'], 'changed');
      expect(_itemsOf(run).map((i) => i['item']), ['text']);
    });

    test('devrait retenir sous --changed tout élément qui dépend d’un fichier de core modifié', () async {
      final density = File(p.join(app.path, 'lib/ui/fliin/core/theme/fl_density.dart'));
      final before = density.readAsStringSync();
      addTearDown(() => density.writeAsStringSync(before));
      density.writeAsStringSync('$before\n// local\n');
      final run = await _cli(app, ['verify', '--changed', ..._one], environment);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      final chosen = '${run.stdout}'.split('\n').first.substring('--changed: '.length).split(', ');
      expect(chosen, unorderedEquals(['core', 'separator', 'text', 'surface']));
    });

    test('devrait faire échouer sous --strict le seul élément qui s’écarte de sa référence quand deux éléments sont vérifiés', () async {
      final args = ['verify', 'surface', 'text', '--json', ..._one];
      final lenient = await _cli(app, args, environment);
      expect(lenient.exitCode, 0, reason: '${lenient.stderr}');
      final strict = await _cli(app, [...args, '--strict'], environment);
      expect(strict.exitCode, 1, reason: '${strict.stderr}');
      double? diffOf(Map<String, Object?> item) =>
          ((((item['variants']! as List<Object?>).single
                          as Map<String, Object?>)['golden']
                      as Map<String, Object?>?)?['diffPct']
                  as num?)
              ?.toDouble();
      final [surface, text] = _itemsOf(strict);
      expect(diffOf(surface), greaterThan(2));
      expect(diffOf(text), 0.0);
      expect('${strict.stderr}', isNot(contains('--strict requires')));
    });

    test('devrait faire sortir 3 le seul élément dont report.json est illisible, et finir les suivants', () async {
      afterTest.writeAsStringSync(
        'printf "{tronqué" > build/fliin/verify/separator/report.json\n',
      );
      addTearDown(afterTest.deleteSync);
      final run = await _cli(app, [
        'verify',
        'separator',
        'text',
        '--json',
        ..._one,
      ], environment);
      expect(run.exitCode, 3, reason: '${run.stderr}');
      final [separator, text] = _itemsOf(run);
      final error = separator['error']! as Map<String, Object?>;
      expect(error['code'], 3);
      expect(error['message'], contains('report.json is unreadable'));
      expect(text['summary'], ['1/1 variants pass']);
      final written = jsonDecode(
        File(p.join(app.path, 'build/fliin/verify/text/report.json'))
            .readAsStringSync(),
      ) as Map<String, Object?>;
      expect(written['test'], {'exitCode': 0, 'missingVariants': <Object>[]});
    });

    test('devrait faire sortir 1 le seul élément dont une variante demandée manque au rapport', () async {
      afterTest.writeAsStringSync(
        'python3 -I -c "import json;f=\'build/fliin/verify/text/report.json\';'
        'r=json.load(open(f));r[\'variants\']=r[\'variants\'][:1];'
        'json.dump(r,open(f,\'w\'))"\n',
      );
      addTearDown(afterTest.deleteSync);
      final run = await _cli(app, [
        'verify',
        'separator',
        'text',
        '--json',
        '--variants',
        'ios.light.1.0.ltr,android.dark.2.0.rtl',
      ], environment);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      final [separator, text] = _itemsOf(run);
      expect(
        (separator['test']! as Map<String, Object?>)['missingVariants'],
        isEmpty,
      );
      expect((text['test']! as Map<String, Object?>)['missingVariants'], [
        'android.dark.2.0.rtl',
      ]);
      expect(
        '${run.stderr}',
        contains('Variants requested but not rendered: android.dark.2.0.rtl'),
      );
    });
  });
}

List<Map<String, Object?>> _itemsOf(ProcessResult run) =>
    ((jsonDecode('${run.stdout}') as Map<String, Object?>)['items']!
            as List<Object?>)
        .cast<Map<String, Object?>>();

Future<ProcessResult> _cli(
  Directory app,
  List<String> args,
  Map<String, String> environment,
) async => Process.run(Platform.resolvedExecutable, [
  await compiledCli(),
  '-C',
  app.path,
  ...args,
], environment: environment);

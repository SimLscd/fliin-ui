@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/install/lockfile_io.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart';
import '../support/temp_project.dart';

const _icons = 'lib/ui/fliin/icons/fl_icons.dart';

/// Une ligne de `fl_icons.dart` que `dart_style` laisse telle quelle dans
/// chaque jeu : le début de la classe.
const _class = 'abstract final class AcIcons {';

/// Le code d'un préréglage qui ne change que le jeu d'icônes.
String _code(PresetIcons icons) => Preset(icons: icons).encode();

/// Le registre construit par `DistWriter` depuis une copie de la source, une
/// app où `init` puis `add icons` l'ont installé (jeu par défaut), et un
/// HOME : tout à ce scénario.
final class _Scenario {
  _Scenario._(this.source, this.dist, this.app, this.home);

  final String source;
  final String dist;
  final Directory app;
  final String home;

  static Future<_Scenario> create({
    String? preset,
    List<String> add = const ['icons'],
    void Function(String source)? edit,
  }) async {
    final source = copiedSource();
    edit?.call(source);
    final dist = tempDir().path;
    final s = _Scenario._(source, dist, await createFlutterProject('icons_app'), tempDir().path);
    await s.build();
    final init = await s.cli([
      'init',
      '--registry',
      '${Directory(dist).uri}',
      '--trusted-key',
      (await testKey()).publicKey,
      '--prefix',
      'Ac',
      '--allow-dirty',
      if (preset != null) ...['--preset', preset],
    ]);
    expect(init.exitCode, 0, reason: '${init.stdout}${init.stderr}');
    if (add.isNotEmpty) {
      final added = await s.cli(['add', ...add, '--accept-deps']);
      expect(added.exitCode, 0, reason: '${added.stdout}${added.stderr}');
    }
    return s;
  }

  Future<void> build() async =>
      DistWriter(dist).write(SourceRegistry.read(source), stamp: BuildStamp.following(dist), key: await testKey());

  Future<ProcessResult> cli(List<String> args) => fliin(['-C', app.path, ...args], home: home);

  String read(String path) => File(p.join(app.path, path)).readAsStringSync();

  void write(String path, String text) => File(p.join(app.path, path)).writeAsStringSync(text);

  LockedFile locked(String path) => readLockfile(app)!.items[ItemRef('icons')]!.files[path]!;

  /// L'empreinte du fichier de la source qui porte [icons].
  Sha256 sourceSha(PresetIcons icons) => Sha256.ofBytes(
    File(
      p.join(
        source,
        'lib',
        icons.variant == null ? 'icons/fl_icons.dart' : 'icons/sets/${icons.variant}/fl_icons.dart',
      ),
    ).readAsBytesSync(),
  );

  Future<String> state(String path) async {
    final run = await cli(['status', '--json']);
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    return (json['files']! as List).cast<Map<String, Object?>>().singleWhere((f) => f['path'] == path)['state']!
        as String;
  }
}

Map<String, Object?> _json(ProcessResult run) => jsonDecode('${run.stdout}') as Map<String, Object?>;

void main() {
  tearDownAll(deleteCreatedProjects);

  test(
    'devrait installer le fl_icons.dart de Lucide quand init --preset choisit Lucide et qu’un élément qui en dépend l’ajoute',
    () async {
      final s = await _Scenario.create(preset: _code(PresetIcons.lucide), add: const ['list-row']);
      expect(s.read(_icons), contains('Lucide 1.65.0'));
      expect(s.read(_icons), contains(_class));
      expect(s.locked(_icons).raw, s.sourceSha(PresetIcons.lucide));
      expect(await s.state(_icons), 'intact');
    },
  );

  test(
    'devrait passer de Gravity UI à Tabler puis revenir, le lockfile au brut du jeu installé et status intact',
    () async {
      final s = await _Scenario.create();
      expect(s.read(_icons), contains('Gravity UI Icons 2.23.0'));

      final tabler = await s.cli(['theme', '--preset', _code(PresetIcons.tabler), '--json']);
      expect(tabler.exitCode, 0, reason: '${tabler.stdout}${tabler.stderr}');
      expect(_json(tabler)['icons'], {'path': _icons, 'set': 'tabler', 'overwritten': false});
      expect(s.read(_icons), contains('Tabler Icons 3.50.0'));
      expect(s.read(_icons), contains(_class));
      expect(s.locked(_icons).raw, s.sourceSha(PresetIcons.tabler));
      expect(s.locked(_icons).installed, Sha256.ofString(s.read(_icons)));
      expect(await s.state(_icons), 'intact');
      expect(s.read('fliin.yaml'), contains('preset: ${_code(PresetIcons.tabler)}'));

      final again = await s.cli(['theme', '--preset', _code(PresetIcons.tabler), '--json']);
      expect(_json(again).containsKey('icons'), isFalse, reason: 'même jeu : rien à remplacer');

      final back = await s.cli(['theme', '--preset', 'c0000000000000']);
      expect(back.exitCode, 0, reason: '${back.stdout}${back.stderr}');
      expect('${back.stdout}', contains('Gravity UI icon set: $_icons replaced.'));
      expect(s.read(_icons), contains('Gravity UI Icons 2.23.0'));
      expect(s.locked(_icons).raw, s.sourceSha(PresetIcons.fliin));
      expect(await s.state(_icons), 'intact');
    },
  );

  test('devrait dire la retouche locale de fl_icons.dart écrasée quand le préréglage change de jeu', () async {
    final s = await _Scenario.create();
    s.write(_icons, s.read(_icons).replaceFirst(_class, '/// Retouche locale.\n$_class'));
    expect(await s.state(_icons), 'modified');

    final run = await s.cli(['theme', '--preset', _code(PresetIcons.lucide), '--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect((_json(run)['icons']! as Map)['overwritten'], isTrue);
    expect(_json(run)['warnings'], contains(allOf(contains('local change overwritten: $_icons'), contains('Lucide'))));
    expect(s.read(_icons), isNot(contains('Retouche locale.')));
    expect(await s.state(_icons), 'intact');
  });

  test('devrait fusionner fl_icons.dart à trois voies dans le jeu choisi quand icons monte', () async {
    final s = await _Scenario.create();
    expect((await s.cli(['theme', '--preset', _code(PresetIcons.lucide)])).exitCode, 0);
    s.write(_icons, s.read(_icons).replaceFirst(_class, '/// Retouche locale.\n$_class'));

    final lucide = File(p.join(s.source, 'lib', 'icons', 'sets', 'lucide', 'fl_icons.dart'));
    lucide.writeAsStringSync('${lucide.readAsStringSync()}\n// Amont.\n');
    final manifest = File(p.join(s.source, 'items', 'icons.json'));
    final next = nextPatch(sourceVersion('icons', root: s.source));
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceFirst(RegExp(r'"version": "[^"]+"'), '"version": "$next"'),
    );
    await s.build();

    final diff = await s.cli(['diff', 'icons']);
    expect(diff.exitCode, 6, reason: '${diff.stdout}${diff.stderr}');
    expect('${diff.stdout}', contains('+// Amont.'));
    expect('${diff.stdout}', isNot(contains('Gravity UI')), reason: 'B et T dans le jeu du projet');

    final run = await s.cli(['update', 'icons', '--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    final file = [
      for (final item in (_json(run)['items']! as List).cast<Map<String, Object?>>())
        ...(item['files']! as List).cast<Map<String, Object?>>(),
    ].singleWhere((f) => f['path'] == _icons);
    expect(file['status'], 'merged');
    final text = s.read(_icons);
    expect(text, contains('Lucide 1.65.0'));
    expect(text, contains('/// Retouche locale.'));
    expect(text, contains('// Amont.'));
    expect(s.locked(_icons).raw, s.sourceSha(PresetIcons.lucide));
    expect(s.locked(_icons).installed, Sha256.ofString(text));
    expect(s.locked(_icons).base, isNot(s.locked(_icons).installed), reason: 'la retouche locale reste à fusionner');

    final back = await s.cli(['theme', '--preset', 'c0000000000000', '--json']);
    expect(back.exitCode, 0, reason: '${back.stdout}${back.stderr}');
    expect((_json(back)['icons']! as Map)['overwritten'], isTrue, reason: 'la retouche fusionnée est dans installed, pas dans base');
  });

  test('devrait refuser de changer de jeu quand fl_icons.dart porte des marqueurs de conflit', () async {
    final s = await _Scenario.create();
    s.write(_icons, s.read(_icons).replaceFirst(_class, '<<<<<<< local\n// a\n=======\n// b\n>>>>>>> amont\n$_class'));
    final before = tree(s.app.path);
    final run = await s.cli(['theme', '--preset', _code(PresetIcons.lucide)]);
    expect(run.exitCode, 1, reason: '${run.stdout}${run.stderr}');
    expect('${run.stderr}', contains('its conflict markers'));
    expect(tree(s.app.path), before);
  });

  test('devrait réparer par theme --preset un fliin.yaml qui nomme Lucide sur un fichier resté Gravity UI', () async {
    final s = await _Scenario.create();
    final code = _code(PresetIcons.lucide);
    s.write('fliin.yaml', '${s.read('fliin.yaml').trimRight()}\ntheme:\n  preset: $code\n');
    final run = await s.cli(['theme', '--preset', code]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(s.read(_icons), contains('Lucide 1.65.0'));
    expect(s.locked(_icons).raw, s.sourceSha(PresetIcons.lucide));
  });

  test('devrait refuser sans rien écrire un jeu que la version installée d’icons ne sert pas', () async {
    final s = await _Scenario.create(
      edit: (source) {
        final manifest = File(p.join(source, 'items', 'icons.json'));
        final json = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
        for (final file in (json['files']! as List).cast<Map<String, Object?>>()) {
          (file['variants']! as Map<String, Object?>).remove('phosphor');
        }
        manifest.writeAsStringSync(jsonEncode(json));
      },
    );
    final before = tree(s.app.path);
    final run = await s.cli(['theme', '--preset', _code(PresetIcons.phosphor)]);
    expect(run.exitCode, 1, reason: '${run.stdout}${run.stderr}');
    expect('${run.stderr}', contains('does not serve the preset’s phosphor icon set'));
    expect(tree(s.app.path), before);
  });
}

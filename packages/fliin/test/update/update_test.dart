@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/install/kept_raws.dart';
import 'package:fliin/src/install/lockfile_io.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/tokens/project_tokens.dart';
import 'package:fliin/src/update/journal.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../registry/support.dart';
import '../support/manifest_edit.dart';
import '../support/temp_project.dart';

/// Le correctif de spinner que les scénarios publient, au-dessus de celui du dépôt.
final _spinnerNext = nextPatch(sourceVersion('spinner'));

/// La mineure de button que les scénarios publient au-dessus de celle du
/// dépôt, puis la suivante.
final _v2 = nextMinor(sourceVersion('button'));
final _v3 = nextMinor(_v2);

/// La mineure de core que les scénarios publient au-dessus de celle du dépôt.
final _coreNext = nextMinor(sourceVersion('core'));

const button = 'lib/ui/fliin/components/button/fl_button.dart';
const buttonSource = 'components/button/fl_button.dart';
const density = 'lib/ui/fliin/core/theme/fl_density.dart';
const hitTarget = 'lib/ui/fliin/core/interaction/fl_hit_target.dart';
const tokensJson = 'lib/ui/fliin/core/tokens/fliin.tokens.json';
const tokensDart = 'lib/ui/fliin/core/tokens/tokens.g.dart';

/// Une ligne que `dart_style` laisse telle quelle : les deux côtés y
/// ajoutent un commentaire, le projet compile des deux côtés.
const radius = '    final paint = _paint(theme);';

/// Une app où `init` puis `add button` ont installé la v1 d'un registre
/// construit par `DistWriter`, comme `fliin registry build`.
late _Scenario _base;

void main() {
  setUpAll(() async {
    _base = await _Scenario.create();
  });
  tearDownAll(deleteCreatedProjects);
  group('relecture', relecture);
  group('diff, Flutter et suggestions (X2b)', x2b);

  group('les trois cas de DESIGN.md §4.4', () {
    test('devrait remplacer le fichier par la version amont quand il est resté la base (avance rapide)', () async {
      final s = await _base.fork();
      s.editSource(buttonSource, (t) => t.replaceFirst('class FlButton', '/// v2.\nclass FlButton'));
      await s.publish('button', _v2);

      final run = await s.update(['--json']);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect(s.statusOf(run, button), 'fastForward');
      expect(s.read(button), contains('/// v2.\nclass FlButton'));
      final file = s.locked('button', button);
      expect(file.installed, file.base);
      expect(file.installed, Sha256.ofString(s.read(button)));
      expect(file.raw, s.sourceSha(buttonSource));
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
      expect(await s.state(button), 'intact');
    });

    test('ne devrait rien écrire quand seul le local a changé, et avancer raw et base', () async {
      final s = await _base.fork();
      s.editApp(density, (t) => t.replaceFirst('enum ', '/// local.\nenum '));
      final before = s.read(density);
      final installed = s.locked('core', density).installed;
      s.editSource('core/interaction/fl_hit_target.dart', (t) => '$t\n// v${nextPatch(sourceVersion('core'))}\n');
      await s.publish('core', nextPatch(sourceVersion('core')));

      final run = await s.update(['core', '--json']);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect(s.statusOf(run, density), 'localOnly');
      expect(s.statusOf(run, hitTarget), 'fastForward');
      expect(s.read(density), before);
      final file = s.locked('core', density);
      expect(file.raw, s.sourceSha('core/theme/fl_density.dart'));
      expect(file.installed, installed);
      expect(await s.state(density), 'modified');
    });

    test('devrait fusionner sans conflit quand les deux côtés changent des lignes séparées', () async {
      final s = await _base.fork();
      s.editApp(button, (t) => t.replaceFirst('class FlButton', '/// Local.\nclass FlButton'));
      s.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
      await s.publish('button', _v2);

      final run = await s.update(['--json']);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect(s.statusOf(run, button), 'merged');
      final merged = s.read(button);
      expect(merged, contains('/// Local.\nclass FlButton'));
      expect(merged, contains('int flRevision() => 2;'));
      expect(merged, isNot(contains('<<<<<<<')));
      final file = s.locked('button', button);
      expect(file.installed, Sha256.ofString(merged));
      expect(file.base, isNot(file.installed), reason: 'base est la v2 rendue, sans le local');
      expect(await s.state(button), 'modified', reason: 'la retouche fusionnée reste locale : diff --local la montre');
      final status = await s.cli(['status']);
      expect('${status.stdout}', matches(RegExp(r'^button +\S+ +1 modified$', multiLine: true)));
      final local = await s.cli(['diff', 'button', '--local']);
      expect('${local.stdout}', contains('+/// Local.'));

      s.editSource(buttonSource, (t) => '$t\n// $_v3\n');
      await s.publish('button', _v3);
      final add = await s.cli(['add', 'button@^$_v3']);
      expect(add.exitCode, 1, reason: 'add n’écrase pas un fichier fusionné : ${add.stdout}');
      expect('${add.stderr}', contains('fliin update <item>'));
      expect(s.read(button), merged);
    });

    test('devrait laisser le local en place et écrire la version amont dans .fliin-new quand les deux côtés se chevauchent (sidecar, règle 5)', () async {
      final s = await _base.fork();
      final before = s.locked('button', button);
      s.editApp(button, (t) => t.replaceFirst(radius, '$radius // local'));
      final local = s.read(button);
      s.editSource(buttonSource, (t) => t.replaceFirst(radius, '$radius // upstream'));
      await s.publish('button', _v2);

      final run = await s.update(['--json']);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      final report = s.fileReport(run, button);
      expect(report, {'path': button, 'status': 'conflict', 'strategy': 'sidecar', 'sidecar': '$button.fliin-new'});
      expect(s.read(button), local);
      expect(s.read('$button.fliin-new'), contains('$radius // upstream'));
      final file = s.locked('button', button);
      expect(file.base, before.base, reason: 'base n’avance qu’à la résolution');
      expect(file.conflicted!.targetVersion, Version.parse(_v2));
      expect(file.conflicted!.base, Sha256.ofString(s.read('$button.fliin-new')));
      expect(await s.state(button), 'conflicted');
      expect(await s.analyzeErrors(), isEmpty, reason: 'le projet compile toujours');
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(sourceVersion('button')), reason: 'un élément en conflit ne monte pas');

      s.editSource(buttonSource, (t) => '$t\n// $_v3\n');
      await s.publish('button', _v3);
      final blocked = await s.update();
      expect(blocked.exitCode, 1);
      expect('${blocked.stderr}', contains('$button (upstream version: $button.fliin-new)'));
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(sourceVersion('button')));

      File(p.join(s.app.path, '$button.fliin-new')).deleteSync();
      final status = await s.cli(['status', '--json']);
      expect((jsonDecode('${status.stdout}') as Map<String, Object?>)['resolved'], [button]);
      final resolved = s.locked('button', button);
      expect(resolved.conflicted, isNull);
      expect(resolved.base, file.conflicted!.base);
      expect(resolved.raw, file.conflicted!.raw);
      expect(await s.state(button), 'modified', reason: 'le local gardé diffère de la v2');
    });

    test('devrait écrire les marqueurs de git dans le fichier et avancer base quand on demande --conflict=markers', () async {
      final s = await _base.fork();
      s.editApp(button, (t) => t.replaceFirst(radius, '$radius // local'));
      s.editSource(buttonSource, (t) => t.replaceFirst(radius, '$radius // upstream'));
      await s.publish('button', _v2);

      final run = await s.update(['--conflict=markers', '--json']);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      expect(s.fileReport(run, button), {'path': button, 'status': 'conflict', 'strategy': 'markers'});
      expect(
        s.read(button),
        contains(
          '<<<<<<< local\n$radius // local\n'
          '||||||| base\n$radius\n'
          '=======\n$radius // upstream\n'
          '>>>>>>> button@$_v2\n',
        ),
      );
      expect(File(p.join(s.app.path, '$button.fliin-new')).existsSync(), isFalse);
      final file = s.locked('button', button);
      expect(file.raw, s.sourceSha(buttonSource));
      expect(file.installed, Sha256.ofString(s.read(button)));
      expect(file.conflicted, isNull);
    });
  });

  test('devrait créer un fichier ajouté en amont, puis garder sur le disque un fichier retiré en amont et le sortir du lockfile', () async {
    final s = await _base.fork();
    const extra = 'components/button/fl_button_extra.dart';
    const installedExtra = 'lib/ui/fliin/$extra';
    s.writeSource(extra, 'const flButtonExtra = 1;\n');
    s.editManifest('button', (t) => withFileAfter(
      t,
      '@components/button/fl_button.dart',
      '{ "path": "$extra", "type": "registry:component", "target": "@$extra" }',
    ));
    await s.publish('button', _v2);
    final added = await s.update(['--json']);
    expect(added.exitCode, 0, reason: '${added.stderr}');
    expect(s.statusOf(added, installedExtra), 'addedUpstream');
    expect(s.read(installedExtra), 'const flButtonExtra = 1;\n');
    expect(s.lock().items[ItemRef('button')]!.files.keys, contains(installedExtra));

    s.editManifest('button', (t) => t.replaceFirst(
      ',\n    { "path": "$extra", "type": "registry:component", "target": "@$extra" }',
      '',
    ));
    await s.publish('button', _v3);
    final removed = await s.update(['--json']);
    expect(removed.exitCode, 0, reason: '${removed.stderr}');
    expect(s.statusOf(removed, installedExtra), 'removedUpstream');
    expect(File(p.join(s.app.path, installedExtra)).existsSync(), isTrue, reason: 'jamais effacé');
    expect(s.lock().items[ItemRef('button')]!.files.keys, isNot(contains(installedExtra)));
    final status = jsonDecode('${(await s.cli(['status', '--json'])).stdout}') as Map<String, Object?>;
    expect(status['orphans'], contains(installedExtra));
  });

  test('devrait mettre en conflit sidecar un fichier supprimé localement que l’amont a changé, sans le recréer', () async {
    final s = await _base.fork();
    File(p.join(s.app.path, button)).deleteSync();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);

    final run = await s.update(['--conflict=markers', '--json']);
    expect(run.exitCode, 1, reason: '${run.stderr}');
    expect(s.fileReport(run, button)['strategy'], 'sidecar', reason: 'aucune ligne locale à marquer');
    expect(File(p.join(s.app.path, button)).existsSync(), isFalse);
    expect(s.read('$button.fliin-new'), contains('// v2'));
  });

  test('ne devrait ni déplacer ni toucher au lockfile quand l’analyse des fichiers touchés régresse (DESIGN §4.4, point 5)', () async {
    final s = await _base.fork();
    final lockBytes = s.lockBytes();
    final before = s.read(button);
    s.editSource(buttonSource, (t) => '$t\nfinal flBroken = undefinedSymbol;\n');
    await s.publish('button', _v2);

    final run = await s.update(['--json']);
    expect(run.exitCode, 2, reason: '${run.stderr}');
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    expect(json['lockfileWritten'], isFalse);
    expect(
      ((json['analyze']! as Map)['diagnostics'] as List).cast<Map<String, Object?>>().map((d) => d['file']),
      everyElement(button),
    );
    expect('${run.stderr}', contains('Nothing was written'));
    expect(s.lockBytes(), lockBytes);
    expect(s.read(button), before);
    expect(Directory(p.join(s.app.path, 'lib/ui/fliin/.fliin-transit')).existsSync(), isFalse);
    expect(File(p.join(s.app.path, UpdateJournal.path)).existsSync(), isFalse);
  });

  test('devrait terminer une mise à jour interrompue entre le déplacement et le lockfile sans refusionner ce qu’elle a déjà écrit (règle 4)', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => t.replaceFirst(radius, '$radius // local'));
    s.editSource(buttonSource, (t) => t.replaceFirst(radius, '$radius // upstream'));
    await s.publish('button', _v2);
    final lockBytes = s.lockBytes();
    final blocker = Directory(p.join(s.app.path, '$lockfileName.tmp'))..createSync();

    final interrupted = await s.update(['--conflict=markers']);
    expect(interrupted.exitCode, 3, reason: '${interrupted.stderr}');
    expect('${interrupted.stderr}', contains('Run fliin update again'));
    final marked = s.read(button);
    expect(marked, contains('<<<<<<< local'));
    expect(s.lockBytes(), lockBytes);
    expect(File(p.join(s.app.path, UpdateJournal.path)).existsSync(), isTrue);

    blocker.deleteSync();
    final resumed = await s.update(['--json']);
    expect(resumed.exitCode, 1, reason: '${resumed.stderr}');
    final json = jsonDecode('${resumed.stdout}') as Map<String, Object?>;
    expect(json['resumed'], isTrue);
    expect(s.fileReport(resumed, button)['strategy'], 'markers');
    expect(s.read(button), marked, reason: 'le fichier marqué n’est pas refusionné');
    expect('<<<<<<<'.allMatches(s.read(button)), hasLength(1));
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
    expect(s.locked('button', button).installed, Sha256.ofString(marked));
    expect(File(p.join(s.app.path, UpdateJournal.path)).existsSync(), isFalse);
  });

  test('devrait signaler une version disponible en sortant 6 sans rien écrire avec --check, et 0 une fois à jour', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2, changelog: 'Commentaire de fin.');
    final snapshot = tree(s.app.path);

    final run = await s.update(['--check', '--json']);
    expect(run.exitCode, 6, reason: '${run.stderr}');
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    expect(json['upToDate'], isFalse);
    expect(json['updates'], [
      {
        'ref': 'button',
        'from': sourceVersion('button'),
        'to': _v2,
        'changelog': [
          {'version': _v2, 'text': 'Commentaire de fin.'},
        ],
        'breaking': <Object?>[],
      },
    ]);
    expect(s.treeNow(), snapshot);
    expect((await s.update()).exitCode, 0);
    expect((await s.update(['--check'])).exitCode, 0);
  });

  test('devrait montrer chaque résultat sans rien écrire avec --dry-run', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => t.replaceFirst(radius, '$radius // local'));
    s.editSource(buttonSource, (t) => t.replaceFirst(radius, '$radius // upstream'));
    await s.publish('button', _v2);
    final snapshot = tree(s.app.path);

    final run = await s.update(['--dry-run', '--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.statusOf(run, button), 'conflict');
    expect((jsonDecode('${run.stdout}') as Map)['lockfileWritten'], isFalse);
    expect(s.treeNow(), snapshot);
  });

  test('devrait recalculer base depuis .fliin/base pour un élément Pro absent du cache et du registre, pas pour un élément gratuit (règle 3)', () async {
    final s = await _base.fork(proButton: true);
    final v1 = s.locked('button', button).raw;
    expect(File(p.join(s.app.path, keptRawsDir, v1.hex)).existsSync(), isTrue);
    s.editApp(button, (t) => t.replaceFirst('class FlButton', '/// Local.\nclass FlButton'));
    s.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
    await s.publish('button', _v2);
    File(p.join(s.dist, DistLayout.blobPath(v1))).deleteSync();

    final run = await s.cli(['update', '--json'], home: tempDir().path);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.statusOf(run, button), 'merged');
    final v2 = s.locked('button', button).raw;
    expect(File(p.join(s.app.path, keptRawsDir, v2.hex)).existsSync(), isTrue);
    expect(File(p.join(s.app.path, keptRawsDir, v1.hex)).existsSync(), isFalse, reason: 'plus désigné par le lockfile');

    final free = await _base.fork();
    free.editApp(button, (t) => t.replaceFirst('class FlButton', '/// Local.\nclass FlButton'));
    free.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
    await free.publish('button', _v2);
    File(p.join(free.dist, DistLayout.blobPath(free.locked('button', button).raw))).deleteSync();
    final failed = await free.cli(['update'], home: tempDir().path);
    expect(failed.exitCode, 3, reason: '${failed.stderr}');
    expect('${failed.stderr}', contains(DistLayout.blobPath(free.locked('button', button).raw)));
  });

  test('ne devrait jamais choisir une version retirée (règle 12)', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);
    s.editSource(buttonSource, (t) => '$t\n// v3\n');
    await s.publish('button', _v3, yank: [ItemRef.parseVersioned('button@$_v3')]);

    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
    expect(s.read(button), isNot(contains('// v3')));
  });

  test('devrait monter la dépendance avec l’élément quand sa nouvelle contrainte l’exige', () async {
    final s = await _base.fork();
    s.editSource('core/theme/fl_density.dart', (t) => '$t\n// core $_coreNext\n');
    s.setVersion('core', _coreNext);
    s.followCoreNextWithSpinner();
    s.editManifest('button', (t) => t.replaceFirst(RegExp(r'"core@\^[^"]+"'), '"core@^$_coreNext"'));
    await s.publish('button', _v2);

    final run = await s.update(['button', '--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    final items = s.lock().items;
    expect(items[ItemRef('core')]!.version, Version.parse(_coreNext));
    expect(items[ItemRef('button')]!.version, Version.parse(_v2));
    expect(items[ItemRef('button')]!.registryDependencies, [
      ItemRef.parseVersioned('core@$_coreNext'),
      ItemRef.parseVersioned('spinner@$_spinnerNext'),
    ]);
    expect(items[ItemRef('spinner')]!.version, Version.parse(_spinnerNext), reason: 'spinner retenait core à sa mineure');
    expect(s.read(density), contains('// core $_coreNext'));
  });

  test('devrait dire comment monter core quand un thème posé par fliin theme met fliin.tokens.json en conflit, puis monter une fois ce chemin suivi (ADR 0019 §6)', () async {
    final s = await _base.fork();
    expect((await s.cli(['theme', '--primary', '#7C3AED'])).exitCode, 0);
    s.editSource('core/tokens/fliin.tokens.json', (t) => t.replaceAll('0.1451,', '0.1412,').replaceAll('"hex": "#2563EB"', '"hex": "#2463EB"'));
    s.editSource('core/tokens/tokens.g.dart', (_) => renderTokensDart(
      jsonDecode(File(p.join(s.source, 'lib/core/tokens/fliin.tokens.json')).readAsStringSync()),
      prefix: 'Fl',
    ));
    s.setVersion('core', _coreNext);
    s.followCoreNextWithSpinner();
    s.editManifest('button', (t) => t.replaceFirst(RegExp(r'"core@\^[^"]+"'), '"core@^$_coreNext"'));
    await s.publish('button', _v2);

    final first = await s.update(['--json']);
    expect(first.exitCode, 1, reason: '${first.stdout}${first.stderr}');
    final warnings = ((jsonDecode('${first.stdout}') as Map)['tokenWarnings']! as List).cast<String>();
    expect(warnings, [allOf(contains('$tokensJson.fliin-new'), contains('fliin tokens'), contains('fliin theme'))]);
    expect(s.lock().items[ItemRef('core')]!.version, isNot(Version.parse(_coreNext)));

    final upstream = File(p.join(s.app.path, '$tokensJson.fliin-new'));
    File(p.join(s.app.path, tokensJson)).writeAsStringSync(upstream.readAsStringSync());
    upstream.deleteSync();
    expect((await s.cli(['tokens'])).exitCode, 0);
    final second = await s.update(['--json']);
    expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
    expect(s.lock().items[ItemRef('core')]!.version, Version.parse(_coreNext));
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
    expect((await s.cli(['theme', '--primary', '#7C3AED'])).exitCode, 0);
    expect((await s.cli(['tokens', '--check'])).exitCode, 0);
  });

  test('ne devrait pas monter d’office une dépendance quand l’élément nommé monte sans elle', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    s.setVersion('spinner', _spinnerNext);
    await s.publish('button', _v2);

    final run = await s.update(['button', '--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
    expect(s.lock().items[ItemRef('spinner')]!.version, Version.parse(sourceVersion('spinner')));
  });

  test('devrait régénérer tokens.g.dart depuis le JSON fusionné au lieu de le fusionner (ADR 0003 §7)', () async {
    final s = await _base.fork();
    s.editApp(tokensJson, (t) => _setSpace(t, 'sm', 8, 10));
    expect((await s.cli(['tokens'])).exitCode, 0);
    s.editSource('core/tokens/fliin.tokens.json', (t) => _setSpace(t, 'md', 12, 14));
    s.editSource('core/tokens/tokens.g.dart', (_) => renderTokensDart(
      jsonDecode(File(p.join(s.source, 'lib/core/tokens/fliin.tokens.json')).readAsStringSync()),
      prefix: 'Fl',
    ));
    await s.publish('core', nextPatch(sourceVersion('core')));

    final run = await s.update(['core', '--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(s.statusOf(run, tokensJson), 'merged');
    expect(s.statusOf(run, tokensDart), 'regenerated');
    expect(s.read(tokensDart), contains('sm: 10'));
    expect(s.read(tokensDart), contains('md: 14'));
    expect((await s.cli(['tokens', '--check'])).exitCode, 0);
    expect(File(p.join(s.app.path, '$tokensDart.fliin-new')).existsSync(), isFalse);
  });

  test('devrait fusionner fliin.tokens.json sous le préréglage de fliin.yaml : l’amont repassé par lui, la retouche locale gardée, sans conflit (ADR 0016, M4)', () async {
    final s = await _base.fork();
    const preset = Preset(primary: PresetPrimary.violet, radius: PresetRadius.large, spacing: PresetSpacing.compact);
    final themed = await s.cli(['theme', '--preset', preset.encode()]);
    expect(themed.exitCode, 0, reason: '${themed.stdout}${themed.stderr}');
    expect(s.read('fliin.yaml'), contains('preset: ${preset.encode()}'));
    expect(_valueOf(s.read(tokensJson), 'radius', 'card'), 30);
    s.editApp(tokensJson, (t) => _setValue(t, 'size', 'focusRing', 2, 3));
    expect((await s.cli(['tokens'])).exitCode, 0);
    s.editSource('core/tokens/fliin.tokens.json', (t) => _setValue(t, 'radius', 'card', 20, 16));
    s.editSource('core/tokens/tokens.g.dart', (_) => renderTokensDart(
      jsonDecode(File(p.join(s.source, 'lib/core/tokens/fliin.tokens.json')).readAsStringSync()),
      prefix: 'Fl',
    ));
    await s.publish('core', nextPatch(sourceVersion('core')));

    final run = await s.update(['core', '--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(s.statusOf(run, tokensJson), 'merged');
    expect(File(p.join(s.app.path, '$tokensJson.fliin-new')).existsSync(), isFalse);
    expect(_valueOf(s.read(tokensJson), 'radius', 'card'), 24, reason: '16 × 1,5 : l’amont passé par le préréglage');
    expect(_valueOf(s.read(tokensJson), 'size', 'focusRing'), 3, reason: 'la retouche hors préréglage reste');
    expect((await s.cli(['tokens', '--check'])).exitCode, 0);
    final again = await s.cli(['theme', '--preset', preset.encode(), '--json']);
    expect(again.exitCode, 0, reason: '${again.stdout}${again.stderr}');
    expect((jsonDecode(again.stdout as String) as Map<String, Object?>)['patch'], isEmpty);
  });
}

/// Change la valeur de `space.<name>` dans le texte du JSON, sans toucher au
/// reste : une édition à la main.
/// [json] où la valeur [from] du jeton [name] du groupe [group] devient [to].
String _setValue(String json, String group, String name, int from, int to) {
  final at = json.indexOf('"$name": {', json.indexOf('"$group": {'));
  final value = json.indexOf('"value": $from', at);
  return json.replaceRange(value, value + '"value": $from'.length, '"value": $to');
}

/// La valeur du jeton [name] du groupe [group] dans [json].
num _valueOf(String json, String group, String name) {
  final at = json.indexOf('"$name": {', json.indexOf('"$group": {'));
  return num.parse(RegExp(r'"value": (-?[0-9.]+)').firstMatch(json.substring(at))![1]!);
}

String _setSpace(String json, String name, int from, int to) {
  final at = json.indexOf('"$name": {', json.indexOf('"space": {'));
  final value = json.indexOf('"value": $from', at);
  return json.replaceRange(value, value + '"value": $from'.length, '"value": $to');
}

final class _Scenario {
  _Scenario._(this.source, this.dist, this.app, this.home);

  /// La source, le registre, l'app et le HOME de ce scénario, à lui seul.
  final String source;
  final String dist;
  final Directory app;
  final String home;

  static Future<_Scenario> create({bool pro = false}) async {
    final source = copiedSource();
    if (pro) {
      final manifest = File(p.join(source, 'items', 'button.json'));
      manifest.writeAsStringSync(
        manifest.readAsStringSync().replaceFirst('"tier": "free"', '"tier": "pro"'),
      );
    }
    final dist = tempDir().path;
    final app = await createFlutterProject(pro ? 'pro_app' : 'update_app');
    final s = _Scenario._(source, dist, app, tempDir().path);
    await s._build();
    final init = await s.cli([
      'init',
      '--registry',
      '${Directory(dist).uri}',
      '--trusted-key',
      (await testKey()).publicKey,
    ]);
    expect(init.exitCode, 0, reason: '${init.stderr}');
    final add = await s.cli(['add', 'button']);
    expect(add.exitCode, 0, reason: '${add.stderr}');
    return s;
  }

  static _Scenario? _pro;

  /// Une copie indépendante : source, registre, app et HOME.
  Future<_Scenario> fork({bool proButton = false}) async {
    final from = proButton ? (_pro ??= await create(pro: true)) : this;
    final copy = _Scenario._(
      _copied(from.source),
      _copied(from.dist),
      Directory(_copied(from.app.path)),
      tempDir().path,
    );
    final yaml = File(p.join(copy.app.path, 'fliin.yaml'));
    yaml.writeAsStringSync(
      yaml.readAsStringSync().replaceAll(
        '${Directory(from.dist).uri}',
        '${Directory(copy.dist).uri}',
      ),
    );
    return copy;
  }

  static String _copied(String from) {
    final to = p.join(tempDir().path, 'copy');
    copyTree(Directory(from), Directory(to));
    return to;
  }

  Future<void> _build({List<ItemRef> yank = const []}) async =>
      DistWriter(dist).write(
        SourceRegistry.read(source),
        stamp: BuildStamp.following(dist, yank: yank),
        key: await testKey(),
      );

  Future<void> publish(
    String item,
    String version, {
    List<ItemRef> yank = const [],
    String? changelog,
  }) async {
    setVersion(item, version);
    if (changelog != null) editManifest(item, (t) => withChangelog(t, changelog));
    await _build(yank: yank);
  }

  void setVersion(String item, String version) => editManifest(
    item,
    (t) => t.replaceFirst(RegExp(r'"version": "[^"]+"'), '"version": "$version"'),
  );

  /// `spinner`, que `button` installe avec lui, suit la mineure suivante de `core` : sans
  /// lui, le résolveur refuserait la montée de `button`.
  void followCoreNextWithSpinner() {
    editManifest('spinner', (t) => t.replaceFirst(RegExp(r'"core@\^[^"]+"'), '"core@^$_coreNext"'));
    setVersion('spinner', _spinnerNext);
  }

  void editManifest(String item, String Function(String text) edit) =>
      _edit(p.join(source, 'items', '$item.json'), edit);

  void editSource(String path, String Function(String text) edit) =>
      _edit(p.join(source, 'lib', path), edit);

  void writeSource(String path, String text) => File(p.join(source, 'lib', path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  void editApp(String path, String Function(String text) edit) =>
      _edit(p.join(app.path, path), edit);

  static void _edit(String path, String Function(String text) edit) {
    final file = File(path);
    final text = file.readAsStringSync();
    final edited = edit(text);
    if (edited == text) throw StateError('édition sans effet sur $path');
    file.writeAsStringSync(edited);
  }

  Sha256 sourceSha(String path) =>
      Sha256.ofBytes(File(p.join(source, 'lib', path)).readAsBytesSync());

  String read(String path) => File(p.join(app.path, path)).readAsStringSync();

  Lockfile lock() => readLockfile(app)!;

  List<int> lockBytes() => File(p.join(app.path, lockfileName)).readAsBytesSync();

  LockedFile locked(String item, String path) =>
      lock().items[ItemRef(item)]!.files[path]!;

  Map<String, List<int>> treeNow() => tree(app.path);

  Future<ProcessResult> cli(
    List<String> args, {
    String? home,
    Map<String, String> environment = const {},
  }) => fliin(
    ['-C', app.path, ...args],
    home: home ?? this.home,
    environment: environment,
  );

  Future<ProcessResult> update([List<String> args = const []]) =>
      cli(['update', ...args]);

  Map<String, Object?> fileReport(ProcessResult run, String path) {
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    return [
      for (final item in (json['items']! as List).cast<Map<String, Object?>>())
        ...(item['files']! as List).cast<Map<String, Object?>>(),
    ].singleWhere((f) => f['path'] == path);
  }

  Object? statusOf(ProcessResult run, String path) =>
      fileReport(run, path)['status'];

  Future<String> state(String path) async {
    final run = await cli(['status', '--json']);
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    return (json['files']! as List)
        .cast<Map<String, Object?>>()
        .singleWhere((f) => f['path'] == path)['state']! as String;
  }

  Future<List<Object?>> analyzeErrors() async {
    final run = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--format=json',
      'lib',
    ], workingDirectory: app.path);
    final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
    return [
      for (final d in (json['diagnostics']! as List).cast<Map<String, Object?>>())
        if (d['severity'] == 'ERROR') d,
    ];
  }
}

/// Les constats de la relecture adversariale, un scénario chacun.
void relecture() {
  test('devrait écrire le vrai texte, sans import vers .fliin-transit, quand deux fichiers qui s’importent montent ensemble (H1)', () async {
    final s = await _base.fork();
    s.editSource('core/fliin.dart', (t) => '$t\n// core ${nextPatch(sourceVersion('core'))}\n');
    await s.publish('core', nextPatch(sourceVersion('core')));
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);

    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(await s.analyzeErrors(), isEmpty);
    for (final file in Directory(p.join(s.app.path, 'lib')).listSync(recursive: true).whereType<File>()) {
      expect(file.readAsStringSync(), isNot(contains('.fliin-transit')), reason: file.path);
    }
    expect(s.locked('button', button).installed, Sha256.ofString(s.read(button)), reason: 'le lockfile hache ce qui est écrit');
  });

  test('devrait traiter un fichier passé en CRLF comme la base, sans fusion (B1)', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => t.replaceAll('\n', '\r\n'));
    s.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
    await s.publish('button', _v2);
    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.statusOf(run, button), 'fastForward');
    expect(s.read(button), isNot(contains('\r\n')));
  });

  test('devrait garder le style local d’une fusion propre, sans la reformater (B2)', () async {
    final s = await _base.fork();
    const odd = 'int   flLocal( )   =>   1;';
    s.editApp(button, (t) => t.replaceFirst('class FlButton', '$odd\n\nclass FlButton'));
    s.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
    await s.publish('button', _v2);
    final run = await s.update(['--json']);
    expect(s.statusOf(run, button), 'merged');
    expect(s.read(button), contains(odd));
  });

  test('devrait sortir 1 sans rien écrire quand un fichier local n’est pas du texte UTF-8 (B3)', () async {
    final s = await _base.fork();
    File(p.join(s.app.path, button)).writeAsBytesSync([0x63, 0x6c, 0xff, 0xfe, 0x0a]);
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);
    final snapshot = tree(s.app.path);
    final run = await s.update();
    expect(run.exitCode, 1, reason: '${run.stderr}');
    expect('${run.stderr}', contains('$button: not UTF-8 text'));
    expect(s.treeNow(), snapshot);
  });

  test('devrait dire qu’un fichier retiré en amont est modifié localement (M6)', () async {
    final s = await _base.fork();
    const extra = 'components/button/fl_button_extra.dart';
    const installedExtra = 'lib/ui/fliin/$extra';
    s.writeSource(extra, 'const flButtonExtra = 1;\n');
    s.editManifest('button', (t) => withFileAfter(
      t,
      '@components/button/fl_button.dart',
      '{ "path": "$extra", "type": "registry:component", "target": "@$extra" }',
    ));
    await s.publish('button', _v2);
    expect((await s.update()).exitCode, 0);
    s.editApp(installedExtra, (t) => '$t// local\n');
    s.editManifest('button', (t) => t.replaceFirst(
      ',\n    { "path": "$extra", "type": "registry:component", "target": "@$extra" }',
      '',
    ));
    await s.publish('button', _v3);
    final run = await s.update(['--json']);
    expect(s.fileReport(run, installedExtra), {'path': installedExtra, 'status': 'removedUpstream', 'locallyModified': true});
  });

  test('ne devrait pas réécrire le texte d’une cassure semantic (B7)', () async {
    final s = await _base.fork();
    const prose = 'Importez package:fliin_ui/core/fliin.dart à la main.';
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    s.editManifest('button', (t) => t.replaceFirst('"l10n": {},', '"l10n": {},\n  "breaking": [{"kind": "semantic", "description": "$prose"}],'));
    await s.publish('button', _v2);
    final run = await s.update(['--check', '--json']);
    final updates = (jsonDecode('${run.stdout}') as Map<String, Object?>)['updates']! as List;
    expect(((updates.single as Map)['breaking'] as List).single, containsPair('description', prose));
  });

  test('devrait mettre en conflit sidecar un tokens.g.dart édité à la main au lieu de l’écraser (H2)', () async {
    final s = await _base.fork();
    s.editApp(tokensDart, (t) => '$t\n// MON AJOUT\n');
    final local = s.read(tokensDart);
    s.editSource('core/interaction/fl_hit_target.dart', (t) => '$t\n// v${nextPatch(sourceVersion('core'))}\n');
    await s.publish('core', nextPatch(sourceVersion('core')));
    final run = await s.update(['core', '--json']);
    expect(run.exitCode, 1, reason: '${run.stdout}${run.stderr}');
    expect(s.fileReport(run, tokensDart), containsPair('sidecar', '$tokensDart.fliin-new'));
    expect(s.read(tokensDart), local);
    expect(s.read('$tokensDart.fliin-new'), isNot(contains('MON AJOUT')));
  });

  test('ne devrait jamais rétrograder quand la version installée est retirée : elle est gardée et le rapport le dit (H3)', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);
    expect((await s.update()).exitCode, 0);
    s.editSource(buttonSource, (t) => '$t\n// v3\n');
    await s.publish('button', _v3, yank: [ItemRef.parseVersioned('button@$_v2'), ItemRef.parseVersioned('button@$_v3')]);
    final snapshot = tree(s.app.path);

    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
    final held = ((jsonDecode('${run.stdout}') as Map<String, Object?>)['held']! as List).single as Map;
    expect(held, containsPair('ref', 'button'));
    expect(held['reason'], contains('so $_v2 is kept'));
    expect(s.treeNow(), snapshot);
    expect((await s.update(['--check'])).exitCode, 0);
  });

  test('devrait ignorer et supprimer un journal dont les versions sont déjà au lockfile, --check compris (H4)', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);
    expect((await s.update()).exitCode, 0);
    final journal = File(p.join(s.app.path, UpdateJournal.path))
      ..writeAsStringSync('{"targets":{"button":"$_v2"},"written":{}}');
    s.editSource(buttonSource, (t) => '$t\n// v3\n');
    await s.publish('button', _v3);

    expect((await s.update(['--check'])).exitCode, 6);
    expect(journal.existsSync(), isTrue, reason: '--check n’écrit rien');
    final run = await s.update();
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v3));
    expect(journal.existsSync(), isFalse);
  });

  test('devrait refuser update <autre> tant qu’une mise à jour interrompue attend, et ignorer le journal dans git (H4)', () async {
    final s = await _base.fork();
    expect(s.read('.gitignore'), contains('${UpdateJournal.path}\n'));
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    await s.publish('button', _v2);
    File(p.join(s.app.path, UpdateJournal.path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"targets":{"button":"$_v2"},"written":{}}');
    final run = await s.update(['core']);
    expect(run.exitCode, 1);
    expect('${run.stderr}', contains('An interrupted update to button@$_v2'));
    expect((await s.update()).exitCode, 0);
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
  });

  test('devrait voir la contrainte de button avant de choisir core : la mineure suivante de core publiée ne monte pas sous la contrainte de button (M5)', () async {
    final s = await _base.fork();
    s.editSource('core/theme/fl_density.dart', (t) => '$t\n// core $_coreNext\n');
    await s.publish('core', _coreNext);
    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(s.lock().items[ItemRef('core')]!.version, Version.parse(sourceVersion('core')));
  });

  test('ne devrait pas enregistrer base = installed = T pour un fichier ajouté en amont qui heurte un fichier de l’utilisateur (B4)', () async {
    final s = await _base.fork();
    const extra = 'components/button/fl_button_extra.dart';
    const installedExtra = 'lib/ui/fliin/$extra';
    File(p.join(s.app.path, installedExtra)).writeAsStringSync('const mine = 1;\n');
    s.writeSource(extra, 'const flButtonExtra = 1;\n');
    s.editManifest('button', (t) => withFileAfter(
      t,
      '@components/button/fl_button.dart',
      '{ "path": "$extra", "type": "registry:component", "target": "@$extra" }',
    ));
    await s.publish('button', _v2);
    final run = await s.update(['--json']);
    expect(run.exitCode, 1, reason: '${run.stderr}');
    expect(s.fileReport(run, installedExtra), containsPair('sidecar', '$installedExtra.fliin-new'));
    expect(s.read(installedExtra), 'const mine = 1;\n');
    final file = s.locked('button', installedExtra);
    expect(file.installed, Sha256.ofString('const mine = 1;\n'));
    expect(file.installed, isNot(file.base));
    expect(file.conflicted, isNotNull);
  });

  test('devrait refuser sans rien écrire une nouvelle version qui ajoute un fichier qu’un autre élément possède (B4)', () async {
    final s = await _base.fork();
    s.writeSource('components/button/stolen.dart', 'const flStolen = 1;\n');
    s.editManifest('button', (t) => withFileAfter(
      t,
      '@components/button/fl_button.dart',
      '{ "path": "components/button/stolen.dart", "type": "registry:component", "target": "@core/theme/fl_density.dart" }',
    ));
    await s.publish('button', _v2);
    final snapshot = tree(s.app.path);
    final run = await s.update();
    expect(run.exitCode, 1);
    expect('${run.stderr}', contains('$density belongs to core'));
    expect(s.treeNow(), snapshot);
  });

  test('devrait calculer les cassures franchies entre le brut installé et la cible, pas reprendre celles publiées depuis une autre version (M3)', () async {
    final s = await _base.fork();
    String withoutLoading(String t) => t
        .replaceAll('    this.loading = false,\n', '')
        .replaceFirst('  final bool loading;\n', '  bool get loading => false;\n');
    s.editSource(buttonSource, withoutLoading);
    final v2 = File(p.join(s.source, 'lib', buttonSource)).readAsStringSync();
    s.editManifest('button', (t) => t.replaceFirst('"l10n": {},', '"l10n": {},\n  "breaking": [{"kind": "semantic", "description": "Le chargement disparaît."}],'));
    await s.publish('button', _v2);
    s.editManifest('button', (t) => t.replaceFirst(',\n  "breaking": [{"kind": "semantic", "description": "Le chargement disparaît."}]', ''));
    final patch = nextPatch(sourceVersion('button'));
    File(p.join(s.source, 'lib', buttonSource)).writeAsStringSync('$v2\n// $patch, correctif sur la ligne installée\n');
    await s.publish('button', patch);
    expect((await s.update(['button@<$_v2'])).exitCode, 0);
    expect(s.lock().items[ItemRef('button')]!.version, Version.parse(patch));

    final run = await s.update(['--check', '--json']);
    expect(run.exitCode, 6, reason: '${run.stderr}');
    final update = ((jsonDecode('${run.stdout}') as Map<String, Object?>)['updates']! as List).single as Map;
    expect(update['breaking'], [
      {'version': _v2, 'origin': 'published', 'kind': 'semantic', 'description': 'Le chargement disparaît.'},
    ], reason: '$patch n’a déjà plus loading : rien de calculé entre $patch et $_v2');

    final fresh = await _base.fork();
    fresh.editSource(buttonSource, withoutLoading);
    await fresh.publish('button', _v2);
    final direct = await fresh.update(['--check', '--json']);
    final breaking = ((((jsonDecode('${direct.stdout}') as Map<String, Object?>)['updates']! as List).single as Map)['breaking']! as List).cast<Map<String, Object?>>();
    expect(breaking.map((b) => (b['origin'], b['symbol'])), [('computed', 'FlButton.new')]);
  });

  group('conflit et nouvelle API utilisée ailleurs (H5)', () {
    const scope = 'lib/ui/fliin/core/theme/fl_scope.dart';
    const scopeLine = 'class FlScope extends StatefulWidget {';

    Future<_Scenario> scenario() async {
      final s = await _base.fork();
      s.editApp(scope, (t) => t.replaceFirst(scopeLine, '$scopeLine // local'));
      s.editSource('core/theme/fl_scope.dart', (t) => t.replaceFirst(scopeLine, '$scopeLine // upstream'));
      s.editSource('core/theme/fl_density.dart', (t) => '$t\nint flDensityRevision() => 2;\n');
      s.setVersion('core', _coreNext);
      s.followCoreNextWithSpinner();
      s.editSource(buttonSource, (t) => '$t\nfinal flButtonRevision = flDensityRevision();\n');
      s.editManifest('button', (t) => t.replaceFirst(RegExp(r'"core@\^[^"]+"'), '"core@^$_coreNext"'));
      await s.publish('button', _v2);
      return s;
    }

    test('devrait, en sidecar, ne rien faire monter de l’élément en conflit ni de ce qui exige sa nouvelle version, puis tout finir après résolution', () async {
      final s = await scenario();
      final density0 = s.read(density);
      final run = await s.update(['--json']);
      expect(run.exitCode, 1, reason: '${run.stdout}${run.stderr}');
      final json = jsonDecode('${run.stdout}') as Map<String, Object?>;
      final held = {for (final h in (json['held']! as List).cast<Map<String, Object?>>()) h['ref']: h['reason']};
      expect(held.keys, unorderedEquals(['core', 'spinner', 'button']));
      expect(held['spinner'], contains('core@$_coreNext'));
      expect(held['button'], contains('spinner@$_spinnerNext'));
      expect(s.fileReport(run, scope), containsPair('sidecar', '$scope.fliin-new'));
      expect(s.read(density), density0, reason: 'aucun autre fichier de core ne monte');
      expect(s.lock().items[ItemRef('core')]!.version, Version.parse(sourceVersion('core')));
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(sourceVersion('button')));
      expect(await s.analyzeErrors(), isEmpty, reason: 'le projet compile toujours');

      File(p.join(s.app.path, '$scope.fliin-new')).deleteSync();
      expect((await s.cli(['status'])).exitCode, 0);
      final second = await s.update(['--json']);
      expect(second.exitCode, 0, reason: '${second.stdout}${second.stderr}');
      expect(s.statusOf(second, scope), 'localOnly');
      expect(s.statusOf(second, density), 'fastForward');
      expect(s.statusOf(second, button), 'fastForward');
      expect(s.lock().items[ItemRef('core')]!.version, Version.parse(_coreNext));
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
      expect(s.read(scope), contains('$scopeLine // local'));
      expect(await s.analyzeErrors(), isEmpty);
    });

    test('devrait, en markers, tout faire monter en écartant de l’analyse les fichiers marqués et ceux qui les importent', () async {
      final s = await scenario();
      final run = await s.update(['--conflict=markers', '--json']);
      expect(run.exitCode, 1, reason: '${run.stdout}${run.stderr}');
      expect((jsonDecode('${run.stdout}') as Map<String, Object?>)['lockfileWritten'], isTrue);
      expect(s.lock().items[ItemRef('core')]!.version, Version.parse(_coreNext));
      expect(s.lock().items[ItemRef('button')]!.version, Version.parse(_v2));
      expect(s.read(scope), contains('<<<<<<< local'));

      s.editApp(scope, (t) {
        final from = t.indexOf('<<<<<<< local\n');
        final close = '>>>>>>> core@$_coreNext\n';
        return t.replaceRange(from, t.indexOf(close) + close.length, '$scopeLine // local\n');
      });
      expect(await s.analyzeErrors(), isEmpty);
    });
  });

  test('ne devrait pas compter comme régression une erreur que le fichier avait déjà avant la mise à jour (M4)', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => t.replaceFirst('class FlButton', 'final flLocalBroken = missingSymbol;\n\nclass FlButton'));
    s.editSource(buttonSource, (t) => '$t\nint flRevision() => 2;\n');
    await s.publish('button', _v2);
    final run = await s.update(['--json']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(s.statusOf(run, button), 'merged');
  });
}

/// `fliin diff`, le contrôle du SDK Flutter de `update`, `diff` et `verify`,
/// et les suggestions de nom (ADR 0017 §9 à §12).
void x2b() {
  test('devrait montrer en diff unifié ce que la version publiée change, fichier ajouté compris, sans rien écrire, et sortir 6 comme update --check', () async {
    final s = await _base.fork();
    const extra = 'components/button/fl_button_extra.dart';
    s.editSource(buttonSource, (t) => t.replaceFirst('class FlButton', '/// v2.\nclass FlButton'));
    s.writeSource(extra, 'const flButtonExtra = 1;\n');
    s.editManifest('button', (t) => withFileAfter(
      t,
      '@components/button/fl_button.dart',
      '{ "path": "$extra", "type": "registry:component", "target": "@$extra" }',
    ));
    await s.publish('button', _v2);
    final snapshot = s.treeNow();

    final run = await s.cli(['diff']);
    expect(run.exitCode, 6, reason: '${run.stderr}');
    final out = '${run.stdout}';
    expect(out, contains('button ${sourceVersion('button')} → $_v2'));
    expect(out, contains('--- a/$button\n+++ b/$button\n@@ '));
    expect(out, contains('\n+/// v2.\n class FlButton'));
    expect(out, contains('--- /dev/null\n+++ b/lib/ui/fliin/$extra\n@@ -0,0 +1 @@\n+const flButtonExtra = 1;'));
    expect(s.treeNow(), snapshot);

    final json = jsonDecode('${(await s.cli(['diff', 'button', '--json'])).stdout}') as Map<String, Object?>;
    final check = jsonDecode('${(await s.update(['--check', '--json'])).stdout}') as Map<String, Object?>;
    final update = (json['updates']! as List).cast<Map<String, Object?>>().single;
    expect({...update}..remove('files'), (check['updates']! as List).single, reason: 'les mêmes clés que --check, plus files');
    expect(json['upToDate'], isFalse);
    expect(
      {for (final f in (update['files']! as List).cast<Map<String, Object?>>()) f['path']: f['change']},
      {button: 'modified', 'lib/ui/fliin/$extra': 'added'},
    );
  });

  test('devrait dire en une ligne qu’un élément nommé est à jour, et sortir 0', () async {
    final s = await _base.fork();
    final run = await s.cli(['diff', 'button']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect('${run.stdout}'.trim(), 'button ${sourceVersion('button')}: up to date');
    expect('${(await s.cli(['diff'])).stdout}'.trim(), 'Everything is up to date.');
  });

  test('devrait montrer les retouches locales avec --local, hors ligne aussi, et dire que la version publiée ne se lit pas sans registre', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => t.replaceFirst('class FlButton', '/// Local.\nclass FlButton'));
    // Le cache des blobs de l'installation, sans lequel aucun brut ne se lit
    // hors ligne.
    final home = _Scenario._copied(_base.home);
    Directory(s.dist).deleteSync(recursive: true);

    final local = await s.cli(['diff', '--local'], home: home);
    expect(local.exitCode, 0, reason: '${local.stderr}');
    expect('${local.stdout}', startsWith('button ${sourceVersion('button')}: local changes\n--- a/$button\n+++ b/$button\n'));
    expect('${local.stdout}', contains('+/// Local.\n class FlButton'));
    expect('${local.stdout}', isNot(contains('core')), reason: 'seuls les éléments retouchés');
    final json = jsonDecode('${(await s.cli(['diff', '--local', '--json'], home: home)).stdout}') as Map<String, Object?>;
    expect(json['items'], [
      {
        'ref': 'button',
        'version': sourceVersion('button'),
        'files': [
          {'path': button, 'change': 'modified', 'diff': isA<String>()},
        ],
        'pendingConflicts': <Object?>[],
        'interruptedUpdate': null,
      },
    ]);

    final upstream = await s.cli(['diff'], home: home);
    expect(upstream.exitCode, 3, reason: '${upstream.stdout}');
    expect('${upstream.stderr}', contains('fliin diff --local shows local changes without the registry'));
  });

  test('devrait suggérer l’élément installé le plus proche à update, diff et verify pour un nom mal tapé', () async {
    final s = await _base.fork();
    for (final command in ['update', 'diff', 'verify']) {
      final run = await s.cli([command, 'buton']);
      expect(run.exitCode, 1, reason: command);
      expect('${run.stderr}', contains('buton is not installed. Did you mean button?'), reason: command);
    }
  });

  test('devrait sortir 3 avec --check et diff, et le dire dans update, quand la seule version plus récente exige un autre Flutter', () async {
    final s = await _base.fork();
    s.editSource(buttonSource, (t) => '$t\n// v2\n');
    s.editManifest('button', (t) => t.replaceFirst(RegExp(r'"flutter": "[^"]+"'), '"flutter": ">=9.0.0 <10.0.0"'));
    await s.publish('button', _v2);

    final check = await s.update(['--check', '--json']);
    expect(check.exitCode, 3, reason: '${check.stdout}${check.stderr}');
    final json = jsonDecode('${check.stdout}') as Map<String, Object?>;
    expect(json['upToDate'], isFalse);
    expect(json['updates'], isEmpty);
    expect(json['needsFlutter'], [
      {'ref': 'button', 'kept': sourceVersion('button'), 'to': _v2, 'flutter': '>=9.0.0 <10.0.0'},
    ]);
    final diff = await s.cli(['diff']);
    expect(diff.exitCode, 3);
    expect('${diff.stdout}', contains('button $_v2 requires Flutter >=9.0.0 <10.0.0. The project has '));
    final update = await s.update();
    expect(update.exitCode, 0, reason: '${update.stderr}');
    expect('${update.stdout}', contains('so button stays at ${sourceVersion('button')}'));
    expect('${update.stdout}', contains('Everything is up to date.'));
  });

  test('ne devrait montrer sous un préréglage que les retouches à la main de fliin.tokens.json, pas tokens.g.dart régénéré (relecture X2b)', () async {
    final s = await _base.fork();
    const preset = Preset(primary: PresetPrimary.violet, radius: PresetRadius.large);
    expect((await s.cli(['theme', '--preset', preset.encode()])).exitCode, 0);
    final themed = await s.cli(['diff', '--local']);
    expect(themed.exitCode, 0, reason: '${themed.stderr}');
    expect('${themed.stdout}'.trim(), 'No local changes.');

    s.editApp(tokensJson, (t) => _setValue(t, 'size', 'focusRing', 2, 3));
    expect((await s.cli(['tokens'])).exitCode, 0);
    final edited = await s.cli(['diff', '--local']);
    expect('${edited.stdout}', contains('--- a/$tokensJson'));
    expect('${edited.stdout}', isNot(contains('tokens.g.dart')));
  });

  test('devrait dire dans diff --local qu’une mise à jour interrompue a pu écrire les lignes montrées (relecture X2b)', () async {
    final s = await _base.fork();
    s.editApp(button, (t) => '$t\n// amont\n');
    File(p.join(s.app.path, UpdateJournal.path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"targets":{"button":"$_v2"},"written":{}}');
    final run = await s.cli(['diff', '--local']);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect('${run.stdout}', contains('interrupted update to $_v2'));
  });

  test('ne devrait pas dire qu’un autre Flutter ferait monter core quand la contrainte de button le retient de toute façon (relecture X2b)', () async {
    final s = await _base.fork();
    s.editSource('core/theme/fl_density.dart', (t) => '$t\n// core $_coreNext\n');
    s.editManifest('core', (t) => t.replaceFirst(RegExp(r'"flutter": "[^"]+"'), '"flutter": ">=9.0.0 <10.0.0"'));
    await s.publish('core', _coreNext);
    final check = await s.update(['--check', '--json']);
    expect(check.exitCode, 0, reason: '${check.stdout}${check.stderr}');
    expect((jsonDecode('${check.stdout}') as Map<String, Object?>)['needsFlutter'], isEmpty);
  });

  test('devrait refuser update, diff et verify en 3 avant pub, et laisser diff --local marcher, quand le Flutter du projet est trop ancien', () async {
    final s = await _base.fork();
    final old = {'FLIIN_FLUTTER_ROOT': fakeFlutterRoot('3.41.2')};
    final snapshot = s.treeNow();
    for (final args in [['update'], ['update', '--check'], ['diff'], ['verify', 'button']]) {
      final run = await s.cli(args, environment: old);
      expect(run.exitCode, 3, reason: '$args ${run.stdout}${run.stderr}');
      expect('${run.stderr}', contains('Flutter 3.41.2: fliin requires 3.47.0 or later. FLIIN_FLUTTER_ROOT points to ${old['FLIIN_FLUTTER_ROOT']}. Point it to a compatible Flutter, or unset it to use the one on the PATH.'), reason: '$args');
      expect('${run.stderr}', isNot(contains('ce faux SDK')), reason: 'aucune autre commande du SDK');
    }
    expect(s.treeNow(), snapshot);
    final local = await s.cli(['diff', '--local'], environment: old);
    expect(local.exitCode, 0, reason: '${local.stderr}');
    expect('${local.stdout}'.trim(), 'No local changes.');
  });
}

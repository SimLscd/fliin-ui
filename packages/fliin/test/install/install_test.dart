@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/install/lockfile_io.dart';
import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/cli.dart';
import '../support/fake_registry.dart';
import '../support/source_versions.dart';
import '../support/temp_project.dart';

const button = 'lib/ui/fliin/components/button/fl_button.dart';
const scope = 'lib/ui/fliin/core/theme/fl_scope.dart';

String read(Directory dir, String path) =>
    File(p.join(dir.path, path)).readAsStringSync();

void main() {
  late Directory fresh;

  setUpAll(() async => fresh = await createFlutterProject('fresh_app'));
  tearDownAll(deleteCreatedProjects);

  group('init', () {
    test('devrait écrire fliin.yaml, core/, le lockfile et .gitignore quand le projet est vierge, même cloné sans .dart_tool', () async {
      Directory(p.join(fresh.path, '.dart_tool')).deleteSync(recursive: true);
      final run = await fliin(fresh, ['init', '--json']);
      expect(run.code, 0, reason: run.err);

      expect(readFliinConfig(fresh)!.render.package, 'fresh_app');
      final lock = readLockfile(fresh)!;
      expect(lock.dartStyle, dartStyleVersion);
      final core = lock.items[ItemRef('core')]!;
      expect(core.files, hasLength(27), reason: 'core/ et lib/ui/fliin/LICENSE');
      for (final MapEntry(key: path, value: file) in core.files.entries) {
        expect(
          File(p.join(fresh.path, path)).existsSync(),
          isTrue,
          reason: path,
        );
        expect(file.installed, file.base, reason: path);
      }
      expect(
        core.files[scope]!.raw,
        isNot(core.files[scope]!.base),
        reason: 'dart_style reformate fl_scope.dart (règle 3)',
      );
      final json = core.files['lib/ui/fliin/core/tokens/fliin.tokens.json']!;
      expect(json.raw, json.base, reason: 'un .json ne passe pas par dart_style');
      expect(
        read(fresh, 'lib/ui/fliin/core/fliin.dart'),
        contains(
          "export 'package:fresh_app/ui/fliin/core/theme/fl_scope.dart';",
        ),
      );
      expect(
        read(fresh, '.gitignore'),
        allOf(
          contains('test/.fliin/\n'),
          contains('build/fliin/\n'),
          contains('.fliin/local.json\n'),
        ),
      );
      expect(jsonOf(run)['snippet'], contains('FlScope('));
      expect(
        Directory(p.join(fresh.path, 'lib/ui/fliin'))
            .listSync()
            .map((e) => p.basename(e.path)),
        unorderedEquals(['core', 'LICENSE']),
      );
    });

    test('devrait appliquer --preset aux jetons installés, et refuser en 64 un code invalide avant toute écriture', () async {
      final app = await createFlutterProject('preset_app');
      final refused = await fliin(app, ['init', '--preset', 'c00', '--allow-dirty']);
      expect(refused.code, 64);
      expect(refused.err, contains('14 characters'));
      expect(readFliinConfig(app), isNull);

      const preset = Preset(
        primary: PresetPrimary.violet,
        heading: PresetFamily.lora,
        radius: PresetRadius.large,
      );
      final run = await fliin(app, ['init', '--preset', preset.encode(), '--json', '--allow-dirty']);
      expect(run.code, 0, reason: run.err);
      final out = jsonOf(run)['preset']! as Map<String, Object?>;
      expect(out['code'], preset.encode());
      expect(readFliinConfig(app)!.preset, preset);
      expect(out['written'], [
        'lib/ui/fliin/core/tokens/fliin.tokens.json',
        'lib/ui/fliin/core/tokens/tokens.g.dart',
      ]);
      expect(read(app, 'lib/ui/fliin/core/tokens/tokens.g.dart'), contains("headingFamily: 'Lora'"));
      expect((await fliin(app, ['tokens', '--check'])).code, 0);
      expect((await fliin(app, ['theme', '--preset', preset.encode(), '--json'])).code, 0);
      expect(jsonOf(await fliin(app, ['theme', '--preset', preset.encode(), '--json']))['patch'], isEmpty);
    });

    test('devrait finir l’initialisation puis sortir en 1 en disant de relancer theme --preset quand le préréglage ne s’applique pas (B3)', () async {
      final app = await createFlutterProject('preset_broken_app');
      final run = await fliin(
        app,
        ['init', '--preset', 'c0m1Vr90000000', '--allow-dirty'],
        registry: FakeRegistry(broken: {'core/tokens/fliin.tokens.json'}),
      );
      expect(run.code, 1, reason: run.out);
      expect(run.err, contains('Run fliin theme --preset again'));
      expect(read(app, '.gitignore'), contains('test/.fliin/\n'));
      expect(readFliinConfig(app)!.preset, isNull);
    });

    test('devrait refuser (code 3) quand il est relancé', () async {
      final run = await fliin(fresh, ['init']);
      expect(run.code, 3);
      expect(run.err, contains('fliin.yaml already exists'));
    });

    test(
      'devrait refuser (code 3) quand git est sale, sauf avec --allow-dirty',
      () async {
        final dirty = await createFlutterProject('dirty_app');
        await git(dirty, ['init', '-q']);
        expect((await fliin(dirty, ['init'])).code, 3);
        expect(File(p.join(dirty.path, 'fliin.yaml')).existsSync(), isFalse);
        expect((await fliin(dirty, ['init', '--allow-dirty'])).code, 0);
      },
    );

    test('devrait refuser (code 1) sans rien écrire quand root contient un fichier qui n’est pas celui que core écrirait, pas quand il est vide', () async {
      final rooted = await createFlutterProject('rooted_app');
      final mine = File(p.join(rooted.path, 'lib/ui/fliin/mine.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('class Mine {}\n');
      final run = await fliin(rooted, ['init']);
      expect(run.code, 1);
      expect(run.err, contains('lib/ui/fliin/mine.dart (orphan)'));
      expect(run.err, contains('--root'));
      expect(File(p.join(rooted.path, 'fliin.yaml')).existsSync(), isFalse);
      mine.deleteSync();
      expect((await fliin(rooted, ['init'])).code, 0);
    });

    test('devrait terminer un init interrompu pendant le déplacement quand root ne contient que des fichiers identiques au rendu (tour 3, R1 ; ADR 0002 §5)', () async {
      final halted = await createFlutterProject('halted_init_app');
      expect((await fliin(halted, ['init'])).code, 0);
      final lock = readLockfile(halted)!;
      for (final name in ['fliin.lock.json', 'fliin.yaml', scope]) {
        File(p.join(halted.path, name)).deleteSync();
      }
      Directory(p.join(halted.path, 'lib/ui/fliin/.fliin-transit/core'))
          .createSync(recursive: true);
      final run = await fliin(halted, ['init', '--json']);
      expect(run.code, 0, reason: run.err);
      expect(File(p.join(halted.path, scope)).existsSync(), isTrue);
      expect(readLockfile(halted)!.toJson(), lock.toJson());
      expect(readFliinConfig(halted), isNotNull);
      expect(jsonOf(run)['installed'], hasLength(27));
    });

    test(
      'devrait écrire les configs MCP et AGENTS.md quand --agent est donné',
      () async {
        final agents = await createFlutterProject('agents_app');
        File(p.join(agents.path, 'AGENTS.md')).writeAsStringSync('# Mon app\n');
        final run = await fliin(agents, [
          'init',
          '--agent',
          'claude,gemini,android-studio',
          '--json',
        ]);
        expect(run.code, 0, reason: run.err);
        expect(
          read(agents, '.mcp.json'),
          allOf(contains('"fliin"'), contains('"mcp"')),
        );
        expect(read(agents, '.gemini/settings.json'), contains('"mcpServers"'));
        expect(
          read(agents, 'AGENTS.md'),
          allOf(
            startsWith('# Mon app\n'),
            contains('<!-- fliin:start -->'),
            contains('fliin verify'),
            contains('request_selection'),
          ),
        );
        final json = jsonOf(run);
        final block = json['androidStudio']! as Map<String, Object?>;
        expect('${block['httpUrl']}', startsWith('http://127.0.0.1:'));
        expect(block['tokenFile'], '.fliin/local.json');
        expect(read(agents, 'fliin.yaml'), isNot(contains('token')));
        final local = File(p.join(agents.path, '.fliin/local.json'));
        final token = ((jsonDecode(local.readAsStringSync())
                as Map<String, Object?>)['androidStudio']!
            as Map<String, Object?>)['token']! as String;
        expect(token, hasLength(43));
        expect(run.out, isNot(contains(token)), reason: 'synthèse #16');
        expect(local.statSync().mode & 0x1ff, 0x180, reason: 'synthèse #16');
        expect(
          readFliinConfig(agents)!.agents,
          contains(isA<AndroidStudioAgent>()),
        );
      },
    );
    test(
      'devrait brancher les agents dont le projet porte la trace quand --agent manque, et n’en écrire aucun avec --agent none',
      () async {
        final detected = await createFlutterProject('detected_agents_app');
        File(p.join(detected.path, 'CLAUDE.md')).writeAsStringSync('# App\n');
        Directory(p.join(detected.path, '.codex')).createSync();
        const jsonc = '// Copilot\n{"servers": {}}\n';
        File(p.join(detected.path, '.vscode/mcp.json'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonc);
        final run = await fliin(detected, ['init', '--json', '--allow-dirty']);
        expect(run.code, 0, reason: run.err);
        expect(jsonOf(run)['agents'], {
          'configured': ['claude', 'codex'],
          'detected': true,
          'skipped': [
            {
              'agent': 'vscode',
              'path': '.vscode/mcp.json',
              'reason': isA<String>(),
            },
          ],
        });
        expect(read(detected, '.vscode/mcp.json'), jsonc);
        expect(read(detected, 'CLAUDE.md'), '# App\n\n@AGENTS.md\n');
        expect(read(detected, '.codex/config.toml'), contains('[mcp_servers.fliin]'));
        expect(read(detected, 'AGENTS.md'), contains('fliin verify'));
        expect(readFliinConfig(detected)!.agents, [
          isA<ClaudeCodeAgent>(),
          isA<CodexAgent>(),
        ]);

        final none = await createFlutterProject('no_agents_app');
        File(p.join(none.path, 'CLAUDE.md')).writeAsStringSync('# App\n');
        final quiet = await fliin(none, ['init', '--agent', 'none', '--json', '--allow-dirty']);
        expect(quiet.code, 0, reason: quiet.err);
        expect(File(p.join(none.path, 'AGENTS.md')).existsSync(), isFalse);
        expect(read(none, 'CLAUDE.md'), '# App\n');
        expect(readFliinConfig(none)!.agents, isEmpty);
      },
    );
  });

  group('fichiers mal formés', () {
    test('devrait refuser (code 1) sans rien écrire quand une config d’agent n’est pas du JSON, et repartir une fois corrigée (synthèse #8)', () async {
      final broken = await createFlutterProject('broken_agent_app');
      final cursor = File(p.join(broken.path, '.cursor/mcp.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{ broken\n');
      final run = await fliin(broken, ['init', '--agent', 'claude,cursor']);
      expect(run.code, 1);
      expect(run.err, contains('.cursor/mcp.json'));
      expect(run.err, isNot(contains('Unhandled')));
      for (final path in ['lib/ui', 'fliin.lock.json', 'fliin.yaml', '.mcp.json']) {
        expect(
          FileSystemEntity.typeSync(p.join(broken.path, path)),
          FileSystemEntityType.notFound,
          reason: path,
        );
      }
      cursor.writeAsStringSync('{"mcpServers": {}}\n');
      final fixed = await fliin(broken, ['init', '--agent', 'claude,cursor']);
      expect(fixed.code, 0, reason: fixed.err);
      expect(read(broken, '.cursor/mcp.json'), contains('"fliin"'));
    });

    test('devrait sortir 1 avec un JSON d’erreur situé quand le lockfile ou fliin.yaml est mal formé (synthèse #8)', () async {
      final lock = File(p.join(fresh.path, 'fliin.lock.json'));
      final yaml = File(p.join(fresh.path, 'fliin.yaml'));
      final (lockText, yamlText) = (
        lock.readAsStringSync(),
        yaml.readAsStringSync(),
      );
      try {
        lock.writeAsStringSync('{"lockfileVersion": 1,\n');
        final status = await fliin(fresh, ['status', '--json']);
        expect(status.code, 1);
        final error = jsonOf(status)['error']! as Map<String, Object?>;
        expect(error['message'], contains('fliin.lock.json'));
        lock.writeAsStringSync(lockText);

        yaml.writeAsStringSync('root: [\n');
        final add = await fliin(fresh, ['add', 'button', '--json']);
        expect(add.code, 1);
        expect(
          (jsonOf(add)['error']! as Map<String, Object?>)['message'],
          contains('fliin.yaml'),
        );
      } finally {
        lock.writeAsStringSync(lockText);
        yaml.writeAsStringSync(yamlText);
      }
    });
  });

  group('add', () {
    test('devrait installer fl_button.dart avec les imports réécrits et le préfixe Fl quand on ajoute button', () async {
      final run = await fliin(fresh, ['add', 'button', '--json']);
      expect(run.code, 0, reason: run.err);
      final text = read(fresh, button);
      expect(
        text,
        contains("import 'package:fresh_app/ui/fliin/core/fliin.dart';"),
      );
      expect(text, contains('class FlButton extends StatelessWidget'));
      expect(text, isNot(contains('package:fliin_ui/')));
      final lock = readLockfile(fresh)!;
      expect(lock.items[ItemRef('button')]!.registryDependencies, [
        ItemRef.parse('core@${sourceVersion('core')}'),
        ItemRef.parse('spinner@${sourceVersion('spinner')}'),
      ]);
      expect(lock.items[ItemRef('button')]!.files.keys, [button]);
      final installed = (jsonOf(run)['installed']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(installed.map((i) => i['ref']), [
        'spinner@${sourceVersion('spinner')}',
        'button@${sourceVersion('button')}',
      ]);
      expect(jsonOf(run)['alreadyInstalled'], ['core@${sourceVersion('core')}']);
    });

    test(
      'devrait ne rien réinstaller quand on ajoute un élément déjà installé',
      () async {
        final run = await fliin(fresh, ['add', 'button', '--json']);
        expect(run.code, 0);
        expect(jsonOf(run)['installed'], isEmpty);
      },
    );

    test('devrait renommer en AcButton et AcScope sans toucher Flutter quand le préfixe est Ac', () async {
      final ac = await createFlutterProject('ac_app');
      expect((await fliin(ac, ['init', '--prefix', 'Ac'])).code, 0);
      expect((await fliin(ac, ['add', 'button'])).code, 0);
      final text = read(ac, button);
      expect(
        text,
        allOf(
          contains('class AcButton'),
          contains('AcScope.of(context)'),
          contains('AcButtonVariant'),
        ),
      );
      expect(
        text,
        allOf(
          contains("import 'package:flutter/widgets.dart';"),
          contains('Flexible('),
        ),
      );
      expect(text, isNot(matches(RegExp(r'\bFl[A-Z]'))));
      expect(
        read(ac, scope),
        contains('class AcScope extends StatefulWidget'),
      );
    });

    test(
      'devrait donner le même base dans deux projets de même config (règle 3)',
      () async {
        final locks = <Lockfile>[];
        for (var i = 0; i < 2; i++) {
          final twin = await createFlutterProject('twin_app');
          expect((await fliin(twin, ['init'])).code, 0);
          expect((await fliin(twin, ['add', 'button'])).code, 0);
          locks.add(readLockfile(twin)!);
        }
        for (final ref in [ItemRef('core'), ItemRef('button')]) {
          final a = locks[0].items[ref]!.files;
          final b = locks[1].items[ref]!.files;
          expect(a.keys, b.keys);
          for (final path in a.keys) {
            expect(a[path]!.base, b[path]!.base, reason: path);
          }
        }
      },
    );

    test(
      'ne devrait rien écrire quand un blob manque au milieu du plan (règle 4)',
      () async {
        final atomic = await createFlutterProject('atomic_app');
        final run = await fliin(
          atomic,
          ['init'],
          registry: FakeRegistry(
            missing: {FakeRegistry.shaOf('core/theme/fl_scope.dart')},
          ),
        );
        expect(run.code, 1);
        expect(run.err, contains('does not serve blobs/'));
        expect(Directory(p.join(atomic.path, 'lib/ui')).existsSync(), isFalse);
        expect(
          File(p.join(atomic.path, 'fliin.lock.json')).existsSync(),
          isFalse,
        );
        expect(File(p.join(atomic.path, 'fliin.yaml')).existsSync(), isFalse);
        expect((await fliin(atomic, ['init'])).code, 0);
      },
    );

    test('devrait sortir 5 sans rien écrire quand le registre sert un blob dont l’empreinte n’est pas celle annoncée, même sans le client (règle 1, contrôle de l’installeur)', () async {
      final tampered = await createFlutterProject('tampered_app');
      final run = await fliin(
        tampered,
        ['init'],
        registry: FakeRegistry(tampered: {'core/theme/fl_scope.dart'}),
      );
      expect(run.code, 5, reason: run.err);
      expect(run.err, contains('Integrity check failed'));
      for (final path in ['lib/ui', 'fliin.lock.json', 'fliin.yaml']) {
        expect(
          FileSystemEntity.typeSync(p.join(tampered.path, path)),
          FileSystemEntityType.notFound,
          reason: path,
        );
      }
    });

    test('ne devrait rien écrire quand l’analyse du transit échoue, ni supprimer un dossier vide de l’utilisateur (synthèse #13, règle 4 ; tour 3, R13)', () async {
      final regressed = await createFlutterProject('regressed_app');
      final broken = FakeRegistry(broken: {'core/theme/fl_scope.dart'});
      final run = await fliin(regressed, ['init'], registry: broken);
      expect(run.code, 1);
      expect(run.err, contains('Nothing was written'));
      expect(run.err, contains('lib/ui/fliin/core/theme/fl_scope.dart'));
      for (final path in ['lib/ui', 'fliin.lock.json', 'fliin.yaml']) {
        expect(
          FileSystemEntity.typeSync(p.join(regressed.path, path)),
          FileSystemEntityType.notFound,
          reason: path,
        );
      }

      final ui = Directory(p.join(regressed.path, 'lib/ui'))..createSync();
      expect((await fliin(regressed, ['init'], registry: broken)).code, 1);
      expect(ui.existsSync(), isTrue, reason: 'lib/ui est à l’utilisateur');
      expect(Directory(p.join(ui.path, 'fliin')).existsSync(), isFalse);
      expect((await fliin(regressed, ['init'])).code, 0);
    });

    test('devrait sortir 4 sans rien écrire quand le manifeste exige une dépendance pub absente, puis l’ajouter avec --accept-deps', () async {
      final deps = await createFlutterProject('deps_app');
      final registry = FakeRegistry(
        extraDependencies: {
          'button': {'intl': '^0.20.0'},
        },
      );
      expect((await fliin(deps, ['init'], registry: registry)).code, 0);
      final run = await fliin(deps, [
        'add',
        'button',
        '--json',
      ], registry: registry);
      expect(run.code, 4);
      expect(jsonOf(run)['needsConfirmation'], [
        {'package': 'intl', 'constraint': '^0.20.0', 'requiredBy': 'button'},
      ]);
      expect(File(p.join(deps.path, button)).existsSync(), isFalse);
      expect(readLockfile(deps)!.items.keys, [ItemRef('core')]);

      final accepted = await fliin(deps, [
        'add',
        'button',
        '--accept-deps',
      ], registry: registry);
      expect(accepted.code, 0, reason: accepted.err);
      expect(read(deps, 'pubspec.yaml'), contains('intl: ^0.20.0'));
      expect(File(p.join(deps.path, button)).existsSync(), isTrue);
    });

    test('devrait refuser (code 1) sans rien écrire quand un fichier de l’utilisateur est à la place d’une cible, puis quand un fichier installé est modifié et que le registre ne publie plus que la mineure suivante (synthèse #1, règle 5)', () async {
      final guarded = await createFlutterProject('guarded_app');
      expect((await fliin(guarded, ['init'])).code, 0);
      final mine = File(p.join(guarded.path, button))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('// mon travail, non commité\n');
      final orphan = await fliin(guarded, ['add', 'button', '--json']);
      expect(orphan.code, 1);
      expect(orphan.err, contains('$button (orphan)'));
      expect(jsonOf(orphan)['inTheWay'], [
        {'path': button, 'state': 'orphan'},
      ]);
      expect(mine.readAsStringSync(), '// mon travail, non commité\n');
      expect(readLockfile(guarded)!.items.keys, [ItemRef('core')]);

      mine.deleteSync();
      expect((await fliin(guarded, ['add', 'button'])).code, 0);
      mine.writeAsStringSync('\n// MY LOCAL WORK\n', mode: FileMode.append);
      final bumped = FakeRegistry(versions: {'button': nextMinor(sourceVersion('button'))});
      final modified = await fliin(guarded, [
        'add',
        'button',
      ], registry: bumped);
      expect(modified.code, 1);
      expect(modified.err, contains('$button (modified)'));
      expect(mine.readAsStringSync(), contains('MY LOCAL WORK'));
      expect(readLockfile(guarded)!.items[ItemRef('button')]!.version.toString(), sourceVersion('button'));

      mine.writeAsStringSync(mine.readAsStringSync().replaceFirst('\n// MY LOCAL WORK\n', ''));
      final upgraded = await fliin(guarded, ['add', 'button'], registry: bumped);
      expect(upgraded.code, 0, reason: upgraded.err);
      expect(readLockfile(guarded)!.items[ItemRef('button')]!.version.toString(), nextMinor(sourceVersion('button')));
    });

    test('devrait terminer une installation ou une montée de version interrompue pendant le déplacement quand les cibles sont déjà identiques au rendu et le lockfile en retard (tour 3, R2 ; ADR 0002 §5)', () async {
      final resumed = await createFlutterProject('resumed_app');
      expect((await fliin(resumed, ['init'])).code, 0);
      final lock = File(p.join(resumed.path, 'fliin.lock.json'));
      final coreOnly = lock.readAsStringSync();
      expect((await fliin(resumed, ['add', 'button'])).code, 0);
      final withButton = lock.readAsStringSync();

      lock.writeAsStringSync(coreOnly);
      final installed = await fliin(resumed, ['add', 'button', '--json']);
      expect(installed.code, 0, reason: installed.err);
      expect(jsonOf(installed)['installed'], hasLength(2), reason: 'button et spinner');
      expect(lock.readAsStringSync(), withButton);

      final bumped = FakeRegistry(versions: {'button': nextMinor(sourceVersion('button'))});
      expect((await fliin(resumed, ['add', 'button'], registry: bumped)).code, 0);
      final upgraded = read(resumed, button);
      lock.writeAsStringSync(withButton);
      final status = await fliin(resumed, ['status', '--json']);
      final states = {
        for (final f
            in (jsonOf(status)['files']! as List<Object?>)
                .cast<Map<String, Object?>>())
          f['path']: f['state'],
      };
      expect(states[button], 'modified');

      final finished = await fliin(resumed, ['add', 'button', '--json'], registry: bumped);
      expect(finished.code, 0, reason: finished.err);
      expect(jsonOf(finished)['installed'], hasLength(1));
      expect(read(resumed, button), upgraded);
      expect(readLockfile(resumed)!.items[ItemRef('button')]!.version.toString(), nextMinor(sourceVersion('button')));
    });

    test('ne devrait pas lancer pub add quand un blob manque, et remettre pubspec.yaml, pubspec.lock absent et package_config.json tels qu’avant quand l’analyse échoue après --accept-deps (synthèse #4, règle 4 ; tour 3, R7)', () async {
      final kept = await createFlutterProject('kept_app');
      expect((await fliin(kept, ['init'])).code, 0);
      final pubspec = File(p.join(kept.path, 'pubspec.yaml'));
      final lock = File(p.join(kept.path, 'pubspec.lock'));
      final packageConfig = File(
        p.join(kept.path, '.dart_tool/package_config.json'),
      );
      lock.deleteSync();
      final before = (pubspec.readAsStringSync(), packageConfig.readAsStringSync());
      expect(before.$1, isNot(contains('intl')));

      final unreachable = await fliin(
        kept,
        ['add', 'button', '--accept-deps'],
        registry: FakeRegistry(
          extraDependencies: {
            'button': {'intl': '^0.20.0'},
          },
          missing: {FakeRegistry.shaOf('components/button/fl_button.dart')},
        ),
      );
      expect(unreachable.code, 1);
      expect((pubspec.readAsStringSync(), packageConfig.readAsStringSync()), before);
      expect(lock.existsSync(), isFalse);

      final regressed = await fliin(
        kept,
        ['add', 'button', '--accept-deps'],
        registry: FakeRegistry(
          extraDependencies: {
            'button': {'intl': '^0.20.0'},
          },
          broken: {'components/button/fl_button.dart'},
        ),
      );
      expect(regressed.code, 1);
      expect(regressed.err, contains('Nothing was written'));
      expect((pubspec.readAsStringSync(), packageConfig.readAsStringSync()), before);
      expect(lock.existsSync(), isFalse, reason: 'absent avant pub add');
      expect(File(p.join(kept.path, button)).existsSync(), isFalse);
      expect(readLockfile(kept)!.items.keys, [ItemRef('core')]);
    });

    test('devrait refuser (code 3) add et verify quand fliin.yaml ne porte plus la config du lockfile (synthèse #12, règle 3 ; tour 3, R8)', () async {
      final drifted = await createFlutterProject('drifted_app');
      expect((await fliin(drifted, ['init'])).code, 0);
      final yaml = File(p.join(drifted.path, 'fliin.yaml'));
      final written = yaml.readAsStringSync();
      yaml.writeAsStringSync(written.replaceFirst('prefix: Fl', 'prefix: Ac'));
      final run = await fliin(drifted, ['add', 'button', '--json']);
      expect(run.code, 3);
      expect(run.err, contains('Changing these is not supported'));
      expect(run.err, contains('prefix Fl'));
      expect(File(p.join(drifted.path, button)).existsSync(), isFalse);
      expect(readLockfile(drifted)!.config.prefix, 'Fl');
      final verify = await fliin(drifted, ['verify', 'core']);
      expect(verify.code, 3);
      expect(verify.err, contains('Changing these is not supported'));
      yaml.writeAsStringSync(written);
      expect((await fliin(drifted, ['add', 'button'])).code, 0);
    });

    test('devrait sortir 1 quand l’élément est inconnu du registre', () async {
      final run = await fliin(fresh, ['add', 'carousel']);
      expect(run.code, 1);
      expect(run.err, contains('carousel is not in the registry'));
    });
  });

  group('transit', () {
    test('devrait ignorer un reste de transit dans status, le supprimer dès l’entrée du add suivant même sans rien à installer, et laisser init repartir (synthèse #5)', () async {
      const transit = 'lib/ui/fliin/.fliin-transit';
      final halted = await createFlutterProject('halted_app');
      final stale = File(p.join(halted.path, transit, 'core/stale.dart'));
      stale
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('class Stale {}\n');
      final run = await fliin(halted, ['init']);
      expect(run.code, 0, reason: run.err);
      expect(Directory(p.join(halted.path, transit)).existsSync(), isFalse);

      stale
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('class Stale {}\n');
      final status = await fliin(halted, ['status', '--json']);
      expect(status.code, 0, reason: status.err);
      expect(jsonOf(status)['orphans'], isEmpty);
      final nothing = await fliin(halted, ['add', 'core', '--json']);
      expect(nothing.code, 0, reason: nothing.err);
      expect(jsonOf(nothing)['installed'], isEmpty, reason: 'rien à installer');
      expect(Directory(p.join(halted.path, transit)).existsSync(), isFalse);
    });
  });

  group('status', () {
    test(
      'devrait dire intact pour chaque fichier quand rien n’a bougé après add',
      () async {
        final run = await fliin(fresh, ['status', '--json']);
        expect(run.code, 0);
        final files = (jsonOf(run)['files']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(files, hasLength(29));
        expect(files.map((f) => f['state']), everyElement('intact'));
        expect(jsonOf(run)['orphans'], isEmpty);
      },
    );

    test('devrait dire modified, deleted et orphan quand on édite, supprime et ajoute sous root', () async {
      final file = File(p.join(fresh.path, button));
      file.writeAsStringSync('${file.readAsStringSync()}\n// local\n');
      File(p.join(fresh.path, 'lib/ui/fliin/core/fliin.dart')).deleteSync();
      File(p.join(fresh.path, 'lib/ui/fliin/mine.dart'))
          .writeAsStringSync('class Mine {}\n');
      final run = await fliin(fresh, ['status', '--json']);
      final files = {
        for (final f
            in (jsonOf(run)['files']! as List<Object?>)
                .cast<Map<String, Object?>>())
          f['path']: f['state'],
      };
      expect(files[button], 'modified');
      expect(files['lib/ui/fliin/core/fliin.dart'], 'deleted');
      expect(files[scope], 'intact');
      expect(jsonOf(run)['orphans'], ['lib/ui/fliin/mine.dart']);
    });
  });
}

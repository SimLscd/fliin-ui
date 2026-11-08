@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin/fliin.dart';
import 'package:fliin/src/install/lockfile_io.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/cli.dart';
import '../support/fake_registry.dart';
import '../support/source_versions.dart';
import '../support/temp_project.dart';

const button = 'lib/ui/fliin/components/button/fl_button.dart';
const closeButton = 'lib/ui/fliin/components/close_button/fl_close_button.dart';
const spinner = 'lib/ui/fliin/components/spinner/fl_spinner.dart';

File fileOf(Directory dir, String path) => File(p.join(dir.path, path));

final class UnreachableRegistry implements Registry {
  @override
  bool get servesPro => true;

  @override
  Future<IndexPointer> fetchPointer() async =>
      throw const RegistryUnreachable('connection refused');

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      throw UnimplementedError();

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) => throw UnimplementedError();
}

final class FailingRegistry implements Registry {
  @override
  bool get servesPro => true;

  const FailingRegistry(this.failure);

  final RegistryFailure failure;

  @override
  Future<IndexPointer> fetchPointer() async => throw failure;

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) =>
      throw UnimplementedError();

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) => throw UnimplementedError();
}

const tokens = 'lib/ui/fliin/core/tokens/tokens.g.dart';
const density = 'lib/ui/fliin/core/theme/fl_density.dart';

/// Marque [path] en conflit dans le lockfile, comme après un `update` qui a
/// écrit `<path>.fliin-new`, et écrit ce `.fliin-new`.
void markConflicted(Directory dir, String item, String path) {
  final lockFile = File(p.join(dir.path, lockfileName));
  final json = jsonDecode(lockFile.readAsStringSync()) as Map<String, Object?>;
  final items = json['items']! as Map<String, Object?>;
  final entry =
      (items[item]! as Map<String, Object?>)['files']! as Map<String, Object?>;
  final file = entry[path]! as Map<String, Object?>;
  file['conflicted'] = {
    'targetVersion': '9.9.9',
    'sidecarPath': '$path.fliin-new',
    'raw': file['raw'],
    'base': file['base'],
  };
  lockFile.writeAsStringSync(jsonEncode(json));
  fileOf(dir, '$path.fliin-new').writeAsStringSync('// amont\n');
}

void main() {
  late Directory base;

  setUpAll(() async {
    base = await createFlutterProject('lifecycle_app');
    expect((await fliin(base, ['init'])).code, 0);
    final add = await fliin(base, ['add', 'close-button']);
    expect(add.code, 0, reason: add.err);
  });
  tearDownAll(deleteCreatedProjects);

  /// Une copie de l'app où `core`, `icons`, `spinner`, `button` et `close-button`
  /// sont installés.
  Future<Directory> app() async {
    final parent = Directory.systemTemp.createTempSync('fliin-lifecycle-');
    addTearDownDirectory(parent);
    final result = await Process.run('cp', ['-R', base.path, parent.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return Directory(p.join(parent.path, p.basename(base.path)));
  }

  group('remove', () {
    test('devrait supprimer les fichiers, leur dossier et l’entrée du lockfile, et signaler les dépendances orphelines sans les retirer, quand rien n’en dépend', () async {
      final dir = await app();
      final run = await fliin(dir, ['remove', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, closeButton).parent.existsSync(), isFalse);
      final lock = readLockfile(dir)!;
      expect(lock.items.keys, isNot(contains(ItemRef('close-button'))));
      expect(lock.items.keys, contains(ItemRef('button')));
      expect(fileOf(dir, button).existsSync(), isTrue);
      expect(
        run.out,
        contains(
          'No installed item requires icons, button, spinner anymore. If you '
          'did not ask for them yourself, run fliin remove icons button spinner',
        ),
      );
    });

    test('devrait refuser (code 7) sans rien supprimer, en nommant les dépendants et la commande qui les retire ensemble, quand un élément installé en dépend', () async {
      final dir = await app();
      final run = await fliin(dir, ['remove', 'spinner', '--json']);
      expect(run.code, 7);
      expect(run.err, contains('spinner is required by button.'));
      expect(run.err, contains('fliin remove spinner button close-button'));
      expect(fileOf(dir, spinner).existsSync(), isTrue);
      expect(readLockfile(dir)!.items.keys, contains(ItemRef('spinner')));
      final error = jsonOf(run)['error']! as Map<String, Object?>;
      expect(error['dependents'], {
        'spinner': ['button'],
      });
    });

    test('devrait retirer ensemble un élément et ses dépendants quand ils sont demandés ensemble', () async {
      final dir = await app();
      final run = await fliin(dir, ['remove', 'button', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, button).existsSync(), isFalse);
      expect(fileOf(dir, closeButton).existsSync(), isFalse);
    });

    test('devrait refuser en nommant le fichier modifié, puis le supprimer avec --force', () async {
      final dir = await app();
      fileOf(
        dir,
        closeButton,
      ).writeAsStringSync('// local\n', mode: FileMode.append);
      final refused = await fliin(dir, ['remove', 'close-button']);
      expect(refused.code, 1);
      expect(refused.err, contains('modified   $closeButton'));
      expect(fileOf(dir, closeButton).existsSync(), isTrue);
      expect(readLockfile(dir)!.items.keys, contains(ItemRef('close-button')));

      final forced = await fliin(dir, ['remove', 'close-button', '--force']);
      expect(forced.code, 0, reason: forced.err);
      expect(fileOf(dir, closeButton).existsSync(), isFalse);
    });

    test('devrait refuser un fichier en conflit supprimé localement, puis le retirer avec --force en nommant son .fliin-new', () async {
      final dir = await app();
      markConflicted(dir, 'close-button', closeButton);
      fileOf(dir, closeButton).deleteSync();
      final refused = await fliin(dir, ['remove', 'close-button']);
      expect(refused.code, 1);
      expect(refused.err, contains('conflicted $closeButton'));
      expect(fileOf(dir, '$closeButton.fliin-new').existsSync(), isTrue);

      final run = await fliin(dir, ['remove', '--force', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(
        run.out,
        contains('  $closeButton.fliin-new (pending upstream version)'),
      );
      expect(fileOf(dir, '$closeButton.fliin-new').existsSync(), isFalse);
    });

    test('devrait refuser sans rien supprimer quand une mise à jour interrompue attend', () async {
      final dir = await app();
      fileOf(dir, '.fliin/update.journal.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{}');
      final run = await fliin(dir, ['remove', 'close-button']);
      expect(run.code, 1);
      expect(run.err, contains('Run fliin update to finish it'));
      expect(fileOf(dir, closeButton).existsSync(), isTrue);
      expect(readLockfile(dir)!.items.keys, contains(ItemRef('close-button')));
    });

    test('ne devrait rien écrire quand --dry-run est donné', () async {
      final dir = await app();
      final before = fileOf(dir, lockfileName).readAsStringSync();
      final run = await fliin(dir, ['remove', 'close-button', '--dry-run']);
      expect(run.code, 0, reason: run.err);
      expect(run.out, contains(closeButton));
      expect(run.out, contains('Dry run: nothing was written.'));
      expect(fileOf(dir, closeButton).existsSync(), isTrue);
      expect(fileOf(dir, lockfileName).readAsStringSync(), before);
    });

    test(
      'devrait suggérer un élément installé quand le nom a une faute de frappe',
      () async {
        final run = await fliin(base, ['remove', 'buton']);
        expect(run.code, 1);
        expect(
          run.err,
          contains('buton is not installed. Did you mean button?'),
        );
      },
    );

    test(
      'devrait finir le retrait quand des fichiers sont déjà supprimés',
      () async {
        final dir = await app();
        fileOf(dir, closeButton).deleteSync();
        final run = await fliin(dir, ['remove', 'close-button']);
        expect(run.code, 0, reason: run.err);
        expect(run.out, contains('$closeButton (deleted)'));
        expect(
          readLockfile(dir)!.items.keys,
          isNot(contains(ItemRef('close-button'))),
        );
      },
    );
  });

  group('add', () {
    test('devrait restaurer avec --force les fichiers supprimés, et garder en le disant un fichier modifié', () async {
      final dir = await app();
      final lock = readLockfile(dir)!;
      fileOf(dir, closeButton).parent.deleteSync(recursive: true);
      fileOf(
        dir,
        button,
      ).writeAsStringSync('// local\n', mode: FileMode.append);
      final modified = fileOf(dir, button).readAsStringSync();

      final hint = await fliin(dir, ['add', 'close-button']);
      expect(hint.code, 0, reason: hint.err);
      expect(hint.out, contains('Run fliin add --force close-button to restore'));
      expect(fileOf(dir, closeButton).existsSync(), isFalse);

      final run = await fliin(dir, [
        'add',
        '--force',
        'close-button',
        '--json',
      ]);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, closeButton).existsSync(), isTrue);
      expect(fileOf(dir, button).readAsStringSync(), modified);
      expect(jsonOf(run)['kept'], [
        {'path': button, 'item': 'button', 'state': 'modified'},
      ]);
      expect(readLockfile(dir)!.toJson(), lock.toJson());

      final text = await fliin(dir, ['add', '--force', 'close-button']);
      expect(
        text.out,
        contains('1 modified file in dependencies kept as it is'),
      );
      final named = await fliin(dir, ['add', '--force', 'button']);
      expect(
        named.out,
        contains(
          'kept, modified: $button (button). To get the installed version '
          'back, delete it, then run fliin add --force button.',
        ),
      );
    });

    test('devrait restaurer le fichier supprimé d’un élément et garder octet pour octet son fichier modifié', () async {
      final dir = await app();
      fileOf(dir, density).deleteSync();
      fileOf(
        dir,
        tokens,
      ).writeAsStringSync('// thème\n', mode: FileMode.append);
      final themed = fileOf(dir, tokens).readAsBytesSync();
      final run = await fliin(dir, ['add', '--force', 'core', '--json']);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, density).existsSync(), isTrue);
      expect(fileOf(dir, tokens).readAsBytesSync(), themed);
      expect(jsonOf(run)['kept'], [
        {'path': tokens, 'item': 'core', 'state': 'modified'},
      ]);
    });

    test('devrait restaurer une dépendance supprimée quand on force l’élément qui la requiert', () async {
      final dir = await app();
      fileOf(dir, spinner).deleteSync();
      final run = await fliin(dir, ['add', '--force', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, spinner).existsSync(), isTrue);
    });

    test('ne devrait proposer aucune commande pour un fichier modifié d’une dépendance, et le compter, quand le thème a réécrit core', () async {
      final dir = await app();
      fileOf(dir, closeButton).deleteSync();
      fileOf(
        dir,
        tokens,
      ).writeAsStringSync('// thème\n', mode: FileMode.append);
      final run = await fliin(dir, ['add', '--force', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(run.out, isNot(contains('remove')));
      expect(
        run.out,
        contains('1 modified file in dependencies kept as it is'),
      );
    });

    test('devrait garder un fichier en conflit supprimé localement, et son marqueur de conflit', () async {
      final dir = await app();
      markConflicted(dir, 'close-button', closeButton);
      fileOf(dir, closeButton).deleteSync();
      final run = await fliin(dir, ['add', '--force', 'close-button']);
      expect(run.code, 0, reason: run.err);
      expect(fileOf(dir, closeButton).existsSync(), isFalse);
      expect(run.out, contains('kept, in conflict: $closeButton'));
      expect(
        readLockfile(dir)!
            .items[ItemRef('close-button')]!
            .files[closeButton]!
            .conflicted,
        isNotNull,
      );
    });

    test(
      'devrait résumer les dépendances déjà installées en une ligne',
      () async {
        final run = await fliin(await app(), ['add', 'link-button']);
        expect(run.code, 0, reason: run.err);
        expect(run.out, contains('3 dependencies already installed'));
        expect(run.out, isNot(contains('spinner')));
      },
    );

    test(
      'devrait suggérer le nom proche quand l’élément est inconnu',
      () async {
        final run = await fliin(base, ['add', 'buton']);
        expect(run.code, 1);
        expect(
          run.err,
          contains(
            'buton is not in the registry. Did you mean button?',
          ),
        );
      },
    );
  });

  group('view', () {
    test('devrait décrire un élément installé : versions, fichiers et leur état, imports, dépendances, changelog', () async {
      final run = await fliin(base, ['view', 'button', '--json']);
      expect(run.code, 0, reason: run.err);
      final json = jsonOf(run);
      expect(json['installed'], sourceVersion('button'));
      expect(json['available'], sourceVersion('button'));
      expect(json['files'], [
        {'path': button, 'state': 'intact'},
      ]);
      expect(json['imports'], [
        "import 'package:lifecycle_app/ui/fliin/components/button/fl_button.dart';",
      ]);
      expect(json['registryDependencies'], contains(startsWith('spinner@')));
      expect(json['changelog'], [
        containsPair('version', sourceVersion('button')),
      ]);
      expect(json['api'], contains(startsWith('FlButton.new: ')));
      final info = await fliin(base, ['info', 'button']);
      expect(info.code, 0, reason: info.err);
      expect(info.out, contains('installed: ${sourceVersion('button')}'));
      expect(info.out, contains('API:\n'));
    });

    test('devrait montrer pour un écran non installé les extraits que add affiche ensuite', skip: withoutPro, () async {
      final dir = await app();
      final view = await fliin(dir, ['view', 'forgot-password', '--json']);
      expect(view.code, 0, reason: view.err);
      expect(jsonOf(view)['installed'], isNull);
      expect(jsonOf(view)['api'], contains(startsWith('ForgotPassword')));
      final snippets = jsonOf(view)['snippets']! as Map<String, Object?>;
      expect(snippets['state'], contains('package:lifecycle_app/'));

      final add = await fliin(dir, ['add', 'forgot-password', '--json']);
      expect(add.code, 0, reason: add.err);
      final installed = (jsonOf(add)['installed']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((i) => '${i['ref']}'.startsWith('forgot-password@'));
      expect(installed['snippets'], snippets);
      expect(jsonOf(add)['next'], ['fliin verify forgot-password --json']);
      expect(add.out, isNot(contains('Next:')), reason: '--json seul');
      final text = await fliin(dir, ['view', 'forgot-password']);
      expect(text.out, contains('Route (navigator):'));
      expect(text.out, contains('State (none):'));
    });

    test('devrait décrire depuis le lockfile un élément installé quand le registre ne répond pas', () async {
      final run = await fliin(base, [
        'view',
        'button',
        '--json',
      ], registry: UnreachableRegistry());
      expect(run.code, 0, reason: run.err);
      final json = jsonOf(run);
      expect(json['installed'], sourceVersion('button'));
      expect(json['files'], [
        {'path': button, 'state': 'intact'},
      ]);
      expect(json['unavailable'], contains('connection refused'));
    });

    test(
      'devrait suggérer le nom proche quand l’élément est inconnu',
      () async {
        final run = await fliin(base, ['view', 'buton']);
        expect(run.code, 1);
        expect(run.err, contains('Did you mean button?'));
      },
    );
  });

  group('list', () {
    test('devrait lister les éléments installés et leur version, avec les fichiers modifiés ou supprimés et les mises à jour', () async {
      final dir = await app();
      fileOf(dir, closeButton).deleteSync();
      fileOf(
        dir,
        button,
      ).writeAsStringSync('// local\n', mode: FileMode.append);
      final newer = nextPatch(sourceVersion('spinner'));
      final run = await fliin(dir, [
        'list',
      ], registry: FakeRegistry(versions: {'spinner': newer}));
      expect(run.code, 0, reason: run.err);
      final lines = run.out.trim().split('\n');
      expect(lines, hasLength(5));
      expect(
        lines,
        contains(
          matches(
            RegExp(
              '^button +${RegExp.escape(sourceVersion('button'))}  1 modified\$',
            ),
          ),
        ),
      );
      expect(
        lines,
        contains(matches(RegExp('^close-button +[0-9.]+  1 deleted\$'))),
      );
      expect(
        lines,
        contains(
          matches(RegExp('^spinner +[0-9.]+  → ${RegExp.escape(newer)}\$')),
        ),
      );
      expect(lines, contains(matches(RegExp(r'^core +[0-9.]+$'))));
    });

    test('devrait lister quand même quand le registre sert un pointeur refusé ou manquant', () async {
      for (final failure in [
        const PointerRejectedFailure(PointerRejection.expired),
        const MissingArtifact('latest.json'),
      ]) {
        final run = await fliin(base, [
          'list',
          '--json',
        ], registry: FailingRegistry(failure));
        expect(run.code, 0, reason: '$failure : ${run.err}');
        expect(jsonOf(run)['registryReachable'], isFalse);
        expect(jsonOf(run)['items'], hasLength(5));
      }
    });

    test('devrait lister sans les mises à jour, et le dire, quand le registre ne répond pas', () async {
      final run = await fliin(base, [
        'list',
        '--json',
      ], registry: UnreachableRegistry());
      expect(run.code, 0, reason: run.err);
      final json = jsonOf(run);
      expect(json['registryReachable'], isFalse);
      expect(json['items'], hasLength(5));
      final text = await fliin(base, ['list'], registry: UnreachableRegistry());
      expect(
        text.out,
        contains(
          'Registry unreachable: connection refused. Updates were not checked.',
        ),
      );
    });
  });

  group('status', () {
    test('devrait résumer chaque élément en une ligne, avec conflit en attente et mise à jour interrompue, et --files redonner chaque fichier', () async {
      final dir = await app();
      fileOf(dir, button).writeAsStringSync('${fileOf(dir, button).readAsStringSync()}\n// local\n');
      fileOf(dir, density).deleteSync();
      markConflicted(dir, 'spinner', spinner);
      fileOf(dir, '.fliin/update.journal.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{"targets": {"close-button": "9.9.9"}, "written": {}}');

      final run = await fliin(dir, ['status']);
      expect(run.code, 0, reason: run.err);
      final lines = run.out.trimRight().split('\n');
      final width = 'close-button'.length;
      expect(lines, [
        '${'button'.padRight(width)} ${sourceVersion('button')}  1 modified',
        '${'close-button'.padRight(width)} ${sourceVersion('close-button')}  interrupted update to 9.9.9. Run fliin update to finish it.',
        '${'core'.padRight(width)} ${sourceVersion('core')}  1 deleted',
        '${'icons'.padRight(width)} ${sourceVersion('icons')}  intact',
        '${'spinner'.padRight(width)} ${sourceVersion('spinner')}  1 conflicted  pending conflict: $spinner.fliin-new',
        'Details per file: fliin status --files',
        'Fliin Pro: no license key. Run fliin login to add one.',
      ]);

      final files = await fliin(dir, ['status', '--files']);
      expect(files.out, contains('modified   $button  (button)'));
      expect(files.out, contains('deleted    $density  (core)'));
      expect(files.out, contains('intact     $closeButton  (close-button)'));

      final json = jsonOf(await fliin(dir, ['status', '--json']));
      expect(json.keys, containsAll(['files', 'orphans', 'resolved', 'items']));
      final items = {
        for (final item in (json['items']! as List).cast<Map<String, Object?>>()) item['ref']: item,
      };
      expect(items['spinner'], {
        'ref': 'spinner',
        'version': sourceVersion('spinner'),
        'files': {'conflicted': 1},
        'pendingConflicts': ['$spinner.fliin-new'],
        'interruptedUpdate': null,
      });
      expect(items['close-button']!['interruptedUpdate'], '9.9.9');
      expect(items['icons']!['files'], isEmpty);
    });
  });
}

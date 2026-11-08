import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/lint.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

export '../support/source_versions.dart';

/// `flutter/registry` du dépôt, vu depuis `packages/fliin`.
final sourceRoot = p.normalize(p.absolute('../../flutter/registry'));

Directory tempDir() {
  final dir = Directory.systemTemp.createTempSync('fliin_test_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Le CLI compilé une fois par état des sources : `dart run bin/fliin.dart`
/// recompilerait tout le CLI à chaque appel, soit plusieurs secondes par test.
/// Rangé sous `.dart_tool/` par empreinte des sources : un dossier temporaire
/// par fichier de test n'était jamais effacé (42 Mo chacun).
Future<String>? _compiledCli;

Future<String> compiledCli() => _compiledCli ??= () async {
  final cache = Directory(p.absolute('.dart_tool', 'fliin_test_cli'))
    ..createSync(recursive: true);
  final dill = p.join(cache.path, '${_sourcesDigest()}.dill');
  if (File(dill).existsSync()) return dill;
  // Un nom propre à cet isolat : les fichiers de test tournent en parallèle
  // dans le même processus, donc avec le même pid.
  final scratch = cache.createTempSync('compile_');
  final partial = p.join(scratch.path, 'fliin.dill');
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'kernel',
    p.absolute('bin/fliin.dart'),
    '-o',
    partial,
  ]);
  if (result.exitCode != 0) {
    throw StateError('compilation du CLI : ${result.stderr}');
  }
  File(partial).renameSync(dill);
  scratch.deleteSync(recursive: true);
  final stale = DateTime.now().subtract(const Duration(hours: 1));
  for (final old in cache.listSync()) {
    if (old.path != dill && old.statSync().modified.isBefore(stale)) {
      old.deleteSync(recursive: true);
    }
  }
  return dill;
}();

/// Les sources Dart du CLI et du schéma, et la version du SDK qui compile.
String _sourcesDigest() {
  final files = [
    for (final dir in ['bin', 'lib', '../fliin_schema/lib'])
      ...Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ]..sort((a, b) => a.path.compareTo(b.path));
  final digest = sha256.convert([
    ...utf8.encode(Platform.version),
    for (final file in files) ...[
      ...utf8.encode(file.path),
      ...file.readAsBytesSync(),
    ],
  ]);
  return '$digest';
}

/// Lance le vrai CLI. Le HOME temporaire, neuf à chaque appel sauf si
/// [home] est donné, garde le cache hors de celui de l'utilisateur ;
/// [environment] s'y ajoute.
Future<ProcessResult> fliin(
  List<String> args, {
  String? workingDirectory,
  String? home,
  Map<String, String> environment = const {},
}) async => Process.run(
  Platform.resolvedExecutable,
  [await compiledCli(), ...args],
  workingDirectory: workingDirectory,
  environment: {'HOME': home ?? tempDir().path, ...environment},
);

/// Un SDK Flutter dont `flutter --version --machine` dit [version], et qui
/// échoue à toute autre commande : à passer par `FLIIN_FLUTTER_ROOT`.
String fakeFlutterRoot(String version) {
  final root = tempDir();
  final script = File(p.join(root.path, 'bin', 'flutter'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '#!/bin/sh\n'
      'if [ "\$1" = --version ]; then echo \'{"frameworkVersion": "$version"}\'; exit 0; fi\n'
      'echo "flutter \$1 : ce faux SDK ne sait que --version" >&2; exit 70\n',
    );
  Process.runSync('chmod', ['+x', script.path]);
  return root.path;
}

Future<SigningKey> testKey([int fill = 7]) =>
    SigningKey.fromSeed(List.filled(32, fill));

/// Une copie de `items/`, `lib/` et des goldens de référence de la source,
/// et de son `external_items.txt` s'il y en a un (l'export public), qu'un
/// test peut modifier.
String copiedSource() {
  final root = tempDir().path;
  for (final dir in ['items', 'lib', SourceRegistry.referenceGoldens]) {
    if (Directory(p.join(sourceRoot, dir)).existsSync()) {
      copyTree(
        Directory(p.join(sourceRoot, dir)),
        Directory(p.join(root, dir)),
      );
    }
  }
  final external = File(p.join(sourceRoot, externalItemsFile));
  if (external.existsSync()) {
    external.copySync(p.join(root, externalItemsFile));
  }
  return root;
}

/// Passe [item] à [version] dans la source copiée [root], avec un contenu
/// différent de celui déjà publié.
void bumpSource(String root, String item, String version, String file) {
  final manifest = File(p.join(root, 'items', '$item.json'));
  manifest.writeAsStringSync(
    manifest.readAsStringSync().replaceFirst(
      RegExp(r'"version": "[^"]+"'),
      '"version": "$version"',
    ),
  );
  File(p.join(root, 'lib', file))
      .writeAsStringSync('\n// $version\n', mode: FileMode.append);
}

/// Chemin relatif vers octets, pour comparer deux arbres.
Map<String, List<int>> tree(String root) => {
  for (final file in Directory(
    root,
  ).listSync(recursive: true).whereType<File>())
    p.relative(file.path, from: root): file.readAsBytesSync(),
};

/// Copie l'arbre [from] dans [to], qui n'existe pas encore. Sous macOS,
/// `cp -c` clone les fichiers (APFS) : la copie est indépendante mais
/// n'écrit aucun octet, ce qui compte pour une source de plus de 100 Mo
/// copiée à chaque test.
void copyTree(Directory from, Directory to) {
  if (Platform.isMacOS) {
    to.parent.createSync(recursive: true);
    final result = Process.runSync('cp', ['-cR', from.path, to.path]);
    if (result.exitCode != 0) throw StateError('cp : ${result.stderr}');
    return;
  }
  _copy(from, to);
}

void _copy(Directory from, Directory to) {
  for (final entity in from.listSync(recursive: true)) {
    if (entity is File) {
      final target = File(
        p.join(to.path, p.relative(entity.path, from: from.path)),
      );
      target.parent.createSync(recursive: true);
      entity.copySync(target.path);
    }
  }
}

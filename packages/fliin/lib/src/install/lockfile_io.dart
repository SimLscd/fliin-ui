import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../project/environment_failure.dart';
import '../project/invalid_project_file.dart';
import '../project/pubspec.dart';

const lockfileName = 'fliin.lock.json';

/// Lève une [EnvironmentFailure] si `fliin.yaml` ne porte plus la config qui
/// a produit les `base` du lockfile (règle 3) : la reconfiguration d'un
/// projet n'est pas encore prise en charge, et rendre avec l'autre config
/// donnerait des imports et un préfixe qui ne compilent pas.
void requireSameConfig(Lockfile lockfile, RenderConfig render) {
  if (lockfile.config.configHash == render.configHash) return;
  throw EnvironmentFailure(
    'fliin.yaml changed since the install. The lockfile was written with '
    'root ${lockfile.config.root}, prefix ${lockfile.config.prefix}, '
    'package ${lockfile.config.package}. Changing these is not supported '
    'yet. Put these values back.',
  );
}

/// Lève une [InvalidProjectFile] si le fichier n'est pas du JSON ou pas un
/// lockfile.
Lockfile? readLockfile(Directory dir) {
  final file = File(p.join(dir.path, lockfileName));
  if (!file.existsSync()) return null;
  try {
    return Lockfile.fromJson(readJson(file));
  } on ManifestError catch (e) {
    throw InvalidProjectFile(file.path, '$e');
  }
}

/// Écrit à côté puis renomme : un lockfile n'est jamais lu à moitié écrit.
void writeLockfile(Directory dir, Lockfile lockfile) {
  final target = p.join(dir.path, lockfileName);
  File('$target.tmp')
    ..writeAsStringSync(lockfileText(lockfile))
    ..renameSync(target);
}

/// Le texte de `fliin.lock.json` pour [lockfile].
String lockfileText(Lockfile lockfile) =>
    '${const JsonEncoder.withIndent('  ').convert(lockfile.toJson())}\n';

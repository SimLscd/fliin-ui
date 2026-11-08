import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'environment_failure.dart';
import 'invalid_project_file.dart';

typedef Pubspec = ({String name, Set<String> dependencies});

Pubspec readPubspec(Directory dir) {
  final file = File(p.join(dir.path, 'pubspec.yaml'));
  if (!file.existsSync()) {
    throw EnvironmentFailure(
      '${file.path} not found. This is not a Flutter project.',
    );
  }
  return switch (readYaml(file)) {
    {
      'name': final String name,
      'dependencies': final Map<String, Object?> deps,
    } =>
      (name: name, dependencies: deps.keys.toSet()),
    {'name': final String name} => (name: name, dependencies: const {}),
    _ => throw EnvironmentFailure('${file.path}: the name field is missing.'),
  };
}

/// Les paquets que `pubspec.lock` épingle ; vide tant que `pub get` n'a pas
/// tourné.
Set<String> lockedPackages(Directory dir) {
  final file = File(p.join(dir.path, 'pubspec.lock'));
  if (!file.existsSync()) return const {};
  return switch (readYaml(file)) {
    {'packages': final Map<String, Object?> packages} => packages.keys.toSet(),
    _ => const {},
  };
}

/// Le YAML décodé puis repassé par JSON : des `Map<String, Object?>` et des
/// `List<Object?>` ordinaires, sans les types du paquet yaml. Lève une
/// [InvalidProjectFile] si le fichier n'est pas du YAML.
Object? readYaml(File file) {
  try {
    return jsonDecode(jsonEncode(loadYaml(file.readAsStringSync())));
  } on YamlException catch (e) {
    throw InvalidProjectFile(file.path, e.message);
  }
}

/// Le JSON décodé, ou une [InvalidProjectFile] si le fichier n'en est pas.
Object? readJson(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    throw InvalidProjectFile(file.path, e.message);
  }
}

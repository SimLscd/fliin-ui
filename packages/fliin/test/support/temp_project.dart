import 'dart:io';

import 'package:fliin/src/project/flutter_sdk.dart';
import 'package:path/path.dart' as p;

/// Un projet Flutter vierge créé par le SDK épinglé dans un dossier temporaire.
Future<Directory> createFlutterProject(String name) async {
  final sdk = await FlutterSdk.locate(Platform.environment);
  final parent = Directory.systemTemp.createTempSync('fliin-$name-');
  addTearDownDirectory(parent);
  final result = await Process.run(sdk.flutter, [
    'create',
    '--empty',
    '--platforms=android',
    '--project-name',
    name,
    'app',
  ], workingDirectory: parent.path);
  if (result.exitCode != 0) {
    throw StateError('flutter create a échoué : ${result.stderr}');
  }
  return Directory(p.join(parent.path, 'app'));
}

final _created = <Directory>[];

void addTearDownDirectory(Directory dir) => _created.add(dir);

/// À appeler dans `tearDownAll` : supprime les projets créés.
void deleteCreatedProjects() {
  for (final dir in _created) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  _created.clear();
}

Future<void> git(Directory dir, List<String> args) async {
  final result = await Process.run('git', [
    '-c',
    'user.name=fliin',
    '-c',
    'user.email=fliin@example.com',
    ...args,
  ], workingDirectory: dir.path);
  if (result.exitCode != 0) throw StateError('git $args : ${result.stderr}');
}

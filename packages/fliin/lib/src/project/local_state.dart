import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'environment_failure.dart';
import 'pubspec.dart';

/// Ce qui ne se versionne pas : le jeton porteur du MCP HTTP d'Android Studio.
/// Le port, lui, est dans `fliin.yaml` (`agents.androidStudio.port`).
final class LocalState {
  const LocalState({this.androidStudioToken});

  static const path = '.fliin/local.json';

  /// L'état de [dir], vide si le fichier n'existe pas.
  static LocalState read(Directory dir) {
    final file = File(p.join(dir.path, path));
    if (!file.existsSync()) return const LocalState();
    return switch (readJson(file)) {
      {'androidStudio': {'token': final String token}} => LocalState(
        androidStudioToken: token,
      ),
      _ => const LocalState(),
    };
  }

  final String? androidStudioToken;

  /// Crée le fichier en 0600 avant d'y écrire : le jeton est la seule
  /// barrière du serveur HTTP local, et la machine peut avoir d'autres
  /// utilisateurs.
  void write(Directory dir) {
    final file = File(p.join(dir.path, path))..createSync(recursive: true);
    if (!Platform.isWindows) {
      final chmod = Process.runSync('chmod', ['600', file.path]);
      if (chmod.exitCode != 0) {
        throw EnvironmentFailure(
          '${file.path}: chmod 600 failed: ${chmod.stderr}',
        );
      }
    }
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        if (androidStudioToken case final token?) 'androidStudio': {'token': token},
      })}\n',
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'environment_failure.dart';

/// Le SDK Flutter qui exécute le projet : `FLIIN_FLUTTER_ROOT`, sinon le
/// `flutter` du PATH, remonté de deux niveaux depuis l'exécutable résolu.
final class FlutterSdk {
  const FlutterSdk(this.root, {this.pinned = false});

  final Directory root;

  /// Vrai quand `FLIIN_FLUTTER_ROOT` le désigne : le PATH n'est pas lu.
  final bool pinned;

  String get flutter => p.join(root.path, 'bin', 'flutter');

  String get dart => p.join(root.path, 'bin', 'dart');

  static Future<FlutterSdk> locate(Map<String, String> environment) async {
    final pinned = environment['FLIIN_FLUTTER_ROOT'];
    if (pinned != null) return _at(Directory(pinned), pinned: true);
    final which = await Process.run('which', ['flutter']);
    if (which.exitCode != 0) {
      throw const EnvironmentFailure(
        'flutter not found. Put it on the PATH or set FLIIN_FLUTTER_ROOT.',
      );
    }
    final executable = File((which.stdout as String).trim())
        .resolveSymbolicLinksSync();
    return _at(Directory(p.dirname(p.dirname(executable))));
  }

  static FlutterSdk _at(Directory root, {bool pinned = false}) {
    final sdk = FlutterSdk(root, pinned: pinned);
    if (!File(sdk.flutter).existsSync()) {
      throw EnvironmentFailure('${sdk.flutter} not found.');
    }
    return sdk;
  }

  Future<Version> version() async {
    final result = await Process.run(flutter, ['--version', '--machine']);
    if (result.exitCode != 0) {
      throw EnvironmentFailure('flutter --version failed: ${result.stderr}');
    }
    return switch (_firstJsonObject(result.stdout as String)) {
      {'frameworkVersion': final String version} => Version.parse(version),
      _ => throw const EnvironmentFailure(
        'flutter --version --machine gives no frameworkVersion.',
      ),
    };
  }
}

/// Au premier lancement sous un HOME neuf, Flutter imprime l'avis Google
/// Analytics sur stdout après le JSON, et `--suppress-analytics` ne l'empêche
/// pas : on ne lit que le premier objet JSON.
Object? _firstJsonObject(String stdout) {
  final start = stdout.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  for (var i = start; i < stdout.length; i++) {
    final char = stdout[i];
    if (inString) {
      if (char == r'\') {
        i++;
      } else if (char == '"') {
        inString = false;
      }
    } else if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}' && --depth == 0) {
      return jsonDecode(stdout.substring(start, i + 1));
    }
  }
  return null;
}

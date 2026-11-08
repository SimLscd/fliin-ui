import 'dart:io';

import 'package:fliin/src/project/environment_failure.dart';
import 'package:fliin/src/project/flutter_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

FlutterSdk fakeSdk(String stdout) {
  final root = Directory.systemTemp.createTempSync('fliin-fake-flutter-');
  addTearDown(() => root.deleteSync(recursive: true));
  final script = File(p.join(root.path, 'bin', 'flutter'))
    ..createSync(recursive: true)
    ..writeAsStringSync("#!/bin/sh\ncat <<'EOF'\n$stdout\nEOF\n");
  Process.runSync('chmod', ['+x', script.path]);
  return FlutterSdk(root);
}

void main() {
  test('devrait lire la version quand Flutter imprime l’avis Analytics après le JSON', () async {
    final sdk = fakeSdk('''
{
  "frameworkVersion": "3.47.7",
  "channel": "stable \\"user-branch\\" {x}"
}

  ╔════════════════════════════════════════════╗
  ║ The Flutter tool uses Google Analytics {}  ║
  ╚════════════════════════════════════════════╝''');

    expect(await sdk.version(), Version.parse('3.47.7'));
  });

  test(
    'devrait échouer proprement quand la sortie ne contient aucun objet JSON',
    () async {
      final sdk = fakeSdk('Welcome to Flutter!');

      await expectLater(sdk.version(), throwsA(isA<EnvironmentFailure>()));
    },
  );
}

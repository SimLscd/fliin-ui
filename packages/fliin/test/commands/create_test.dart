@Tags(['slow'])
library;

import 'dart:io';

import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin/src/project/flutter_sdk.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/cli.dart';
import '../support/temp_project.dart';

void main() {
  tearDownAll(deleteCreatedProjects);

  late Directory parent;
  setUp(() {
    parent = Directory.systemTemp.createTempSync('fliin-create-');
    addTearDownDirectory(parent);
  });

  test('devrait créer une app où Fliin est initialisé, le scope posé dans main.dart et le MCP branché, et qui passe flutter analyze', () async {
    final run = await fliin(parent, [
      'create',
      'My-App',
      '--platforms=android',
      '--prefix=Ac',
      '--agent',
      'claude',
      '--json',
    ]);
    expect(run.code, 0, reason: run.err);
    final json = jsonOf(run);
    expect(json['package'], 'my_app');
    expect(json['written'], ['lib/main.dart']);
    expect(json['next'], contains('cd My-App'));
    final app = Directory(p.join(parent.path, 'My-App'));
    final main = File(p.join(app.path, 'lib/main.dart')).readAsStringSync();
    expect(main, contains("import 'package:my_app/ui/fliin/core/fliin.dart';"));
    expect(main, contains('AcScope(child: child ?? const SizedBox.shrink())'));
    expect(readFliinConfig(app)!.agents, [isA<ClaudeCodeAgent>()]);
    expect(File(p.join(app.path, '.mcp.json')).existsSync(), isTrue);
    expect(
      File(p.join(app.path, 'AGENTS.md')).readAsStringSync(),
      contains('AcScope.of(context)'),
    );

    final sdk = await FlutterSdk.locate(Platform.environment);
    final analyze = await Process.run(sdk.flutter, [
      'analyze',
      '--no-pub',
      'lib/main.dart',
    ], workingDirectory: app.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
  });

  test('devrait ne rien laisser quand fliin init refuse une option', () async {
    final run = await fliin(parent, [
      'create',
      'app',
      '--platforms=android',
      '--agent',
      'none',
      '--agent',
      'claude',
    ]);
    expect(run.code, 64);
    expect(run.err, contains('Nothing was created'));
    expect(Directory(p.join(parent.path, 'app')).existsSync(), isFalse);
  });

  test('devrait vider un dossier vide qu’il a rempli quand fliin init refuse une option', () async {
    final app = Directory(p.join(parent.path, 'empty'))..createSync();
    final run = await fliin(parent, [
      'create',
      'empty',
      '--platforms=android',
      '--prefix=lower',
    ]);
    expect(run.code, 64);
    expect(app.listSync(), isEmpty);
  });

  test('devrait ne pas annoncer AGENTS.md quand --agent none', () async {
    final run = await fliin(parent, [
      'create',
      'quiet',
      '--platforms=android',
      '--agent',
      'none',
    ]);
    expect(run.code, 0, reason: run.err);
    expect(run.out, isNot(contains('AGENTS.md')));
    expect(
      File(p.join(parent.path, 'quiet', 'AGENTS.md')).existsSync(),
      isFalse,
    );
  });

  test(
    'devrait refuser en 1 sans rien créer quand le dossier n’est pas vide',
    () async {
      File(p.join(parent.path, 'taken', 'a.txt'))
        ..parent.createSync()
        ..writeAsStringSync('');
      final run = await fliin(parent, ['create', 'taken']);
      expect(run.code, 1);
      expect(run.err, contains('is not empty'));
      expect(Directory(p.join(parent.path, 'taken')).listSync(), hasLength(1));
    },
  );
}

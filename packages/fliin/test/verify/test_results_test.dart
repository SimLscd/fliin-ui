import 'dart:convert';

import 'package:fliin/src/verify/test_results.dart';
import 'package:test/test.dart';

String _events(List<Map<String, Object?>> events) =>
    events.map(jsonEncode).join('\n');

Map<String, Object?> _suite(int id, String path) => {
  'type': 'suite',
  'suite': {'id': id, 'platform': 'vm', 'path': path},
};

Map<String, Object?> _start(int id, int suite, String name) => {
  'type': 'testStart',
  'test': {'id': id, 'name': name, 'suiteID': suite},
};

Map<String, Object?> _done(int id, String result) => {
  'type': 'testDone',
  'testID': id,
  'result': result,
  'hidden': false,
};

/// Ce que `flutter test --file-reporter json:…` écrit pour deux fichiers dont
/// le second ne compile pas (relevé sous Flutter 3.47.7, abrégé).
final _sharedRun = _events([
  {'type': 'start', 'protocolVersion': '0.1.1'},
  _suite(0, '/app/test/.fliin/text_verify_test.dart'),
  _start(1, 0, 'loading /app/test/.fliin/text_verify_test.dart'),
  _suite(2, '/app/test/.fliin/separator_verify_test.dart'),
  _start(3, 2, 'loading /app/test/.fliin/separator_verify_test.dart'),
  {'type': 'allSuites', 'count': 2},
  _done(1, 'success'),
  _start(4, 0, 'text'),
  {'type': 'print', 'testID': 4, 'messageType': 'print', 'message': 'rendu'},
  _done(4, 'success'),
  {
    'type': 'error',
    'testID': 3,
    'error':
        'Failed to load "/app/test/.fliin/separator_verify_test.dart":\n'
        "Compilation failed: Error: Method not found: 'Inexistant'.",
    'stackTrace': '',
    'isFailure': false,
  },
  _done(3, 'error'),
  {'type': 'done', 'success': false},
]);

void main() {
  test('devrait mettre en échec le seul fichier qui ne compile pas, avec son erreur, quand deux fichiers partagent un flutter test', () {
    final suites = suiteResults(_sharedRun);
    expect(suites.keys, {
      'text_verify_test.dart',
      'separator_verify_test.dart',
    });
    final separator = suites['separator_verify_test.dart']!;
    expect(separator.failed, isTrue);
    expect(separator.output, contains("Method not found: 'Inexistant'"));
    final text = suites['text_verify_test.dart']!;
    expect(text.failed, isFalse);
    expect(text.output.trim(), 'rendu');
  });

  test('devrait mettre en échec un fichier dont un test échoue sans événement error quand testDone le dit', () {
    final suites = suiteResults(
      _events([
        _suite(0, '/app/test/.fliin/a_verify_test.dart'),
        _start(1, 0, 'a'),
        _done(1, 'failure'),
      ]),
    );
    expect(suites['a_verify_test.dart']!.failed, isTrue);
  });

  test('devrait ignorer une ligne illisible quand le rapport est tronqué', () {
    final suites = suiteResults(
      '${_events([_suite(0, '/app/test/.fliin/a_verify_test.dart')])}\n{"type": "te',
    );
    expect(suites['a_verify_test.dart'], (failed: false, output: ''));
  });
  group('splitTestRun', () {
    const a = 'test/.fliin/text_verify_test.dart';
    const e = 'test/.fliin/separator_verify_test.dart';
    // Les sorties d'un flutter test dont le tester du second fichier tombe
    // (exit(3) dans le test ; relevé sous Flutter 3.47.7, chemins abrégés) :
    // la cause n'est que sur stderr, sans en-tête qui nomme le fichier.
    const stdout = '''
00:00 +0: loading /app/test/.fliin/text_verify_test.dart
00:00 +0: /app/test/.fliin/text_verify_test.dart: text
rendu text
00:00 +1: loading /app/test/.fliin/separator_verify_test.dart
00:00 +1: /app/test/.fliin/separator_verify_test.dart: separator
rendu separator
00:00 +1: /app/test/.fliin/separator_verify_test.dart: separator - did not complete [E]
00:00 +1: Some tests failed.
''';
    const stderr = '''
unhandled error during finalization of test:
/app/test/.fliin/separator_verify_test.dart
TestDeviceException(Shell subprocess crashed with unexpected exit code 3.)
''';
    final crashed = _events([
      _suite(0, '/app/$a'),
      _start(1, 0, 'text'),
      {'type': 'print', 'testID': 1, 'message': 'rendu text'},
      _done(1, 'success'),
      _suite(2, '/app/$e'),
      _start(3, 2, 'separator'),
      {'type': 'print', 'testID': 3, 'message': 'rendu separator'},
      _done(3, 'error'),
    ]);

    test('devrait garder la cause d’un flutter_tester tombé, que seule la console porte, sur le seul fichier en échec', () {
      final runs = splitTestRun(
        paths: [a, e],
        exitCode: 1,
        stdout: stdout,
        stderr: stderr,
        suites: suiteResults(crashed),
      );
      expect(runs[e]!.exitCode, 1);
      expect(runs[e]!.output, contains('Shell subprocess crashed'));
      expect(runs[e]!.output, contains('did not complete'));
      expect(runs[e]!.output, isNot(contains('rendu text')));
      expect(runs[a]!.exitCode, 0);
      expect(runs[a]!.output, isNot(contains('Shell subprocess crashed')));
    });

    test('devrait joindre la console entière à un fichier en échec quand aucun bloc de la console ne le nomme', () {
      final runs = splitTestRun(
        paths: [a, e],
        exitCode: 1,
        stdout: 'le compilateur est tombé\n',
        stderr: '',
        suites: suiteResults(crashed),
      );
      expect(runs[e]!.output, contains('le compilateur est tombé'));
      expect(runs[a]!.withoutReport, contains('le compilateur est tombé'));
    });

    test('devrait donner à chaque fichier le code et la console du processus quand le rapport JSON manque', () {
      final runs = splitTestRun(
        paths: [a, e],
        exitCode: 69,
        stdout: 'flutter test est tombé\n',
        stderr: '',
        suites: null,
      );
      for (final run in runs.values) {
        expect(run, (
          exitCode: 69,
          output: 'flutter test est tombé\n',
          withoutReport: '',
        ));
      }
    });

    test('devrait donner le code du processus à un fichier dont les événements sont coupés quand aucun fichier n’est situé en échec', () {
      final runs = splitTestRun(
        paths: [a],
        exitCode: 1,
        stdout: '',
        stderr: '',
        suites: suiteResults(_events([_suite(0, '/app/$a')])),
      );
      expect(runs[a]!.exitCode, 1);
    });
  });
}

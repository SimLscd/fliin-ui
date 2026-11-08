import 'dart:convert';

import 'package:path/path.dart' as p;

/// Ce qu'un fichier de test a donné dans un `flutter test` partagé : un échec
/// (chargement, compilation ou test) et ce qu'il a écrit.
typedef SuiteResult = ({bool failed, String output});

/// Lit le rapport `json` de `flutter test --file-reporter` et le découpe par
/// fichier de test, clé : son nom de fichier. Une ligne illisible est ignorée :
/// un fichier absent du résultat retombe sur la sortie globale.
Map<String, SuiteResult> suiteResults(String lines) {
  final suiteNames = <int, String>{};
  final testSuites = <int, int>{};
  final failed = <int>{};
  final outputs = <int, StringBuffer>{};
  void write(int test, String text) {
    if (testSuites[test] case final suite?) {
      outputs.putIfAbsent(suite, StringBuffer.new).writeln(text);
    }
  }

  for (final line in const LineSplitter().convert(lines)) {
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      continue;
    }
    switch (event) {
      case {
        'type': 'suite',
        'suite': {'id': final int id, 'path': final String path},
      }:
        suiteNames[id] = p.basename(path);
      case {
        'type': 'testStart',
        'test': {'id': final int id, 'suiteID': final int suite},
      }:
        testSuites[id] = suite;
      case {
        'type': 'print',
        'testID': final int test,
        'message': final String message,
      }:
        write(test, message);
      case {
        'type': 'error',
        'testID': final int test,
        'error': final String error,
        'stackTrace': final String stackTrace,
      }:
        write(test, '$error\n$stackTrace'.trimRight());
        if (testSuites[test] case final suite?) failed.add(suite);
      case {
            'type': 'testDone',
            'testID': final int test,
            'result': final String result,
          }
          when result != 'success':
        if (testSuites[test] case final suite?) failed.add(suite);
    }
  }
  return {
    for (final MapEntry(key: id, value: name) in suiteNames.entries)
      name: (failed: failed.contains(id), output: '${outputs[id] ?? ''}'),
  };
}

/// Ce qu'un fichier de test a donné : son code, sa sortie, et la sortie à y
/// joindre s'il n'a pas produit de rapport.
typedef TestRun = ({int exitCode, String output, String withoutReport});

/// Le résultat d'un `flutter test` partagé, par fichier de [paths] : le code
/// du processus [exitCode] et ses sorties [stdout] et [stderr], découpés par
/// [suites] (null sans rapport JSON). Un fichier qui échoue a un code non
/// nul, les autres 0 ; un échec que le rapport ne situe dans aucun fichier
/// vaut pour tous. Un fichier en échec reçoit, en plus de ses événements, les
/// blocs de [stdout] qui le nomment (tout [stdout] si aucun ne le nomme) et
/// tout [stderr], où un `flutter_tester` qui tombe laisse sa cause sans dire
/// de quel fichier il vient. Un fichier sain qui finit sans rapport reçoit
/// de même.
Map<String, TestRun> splitTestRun({
  required List<String> paths,
  required int exitCode,
  required String stdout,
  required String stderr,
  required Map<String, SuiteResult>? suites,
}) {
  final located = suites?.values.any((suite) => suite.failed) ?? false;
  return {
    for (final path in paths)
      path: () {
        final blocks = consoleBlocks(stdout, p.basename(path));
        final cause = '${blocks.isEmpty ? stdout : blocks}$stderr';
        return switch (suites?[p.basename(path)]) {
          null => (
            exitCode: exitCode,
            output: '$stdout$stderr',
            withoutReport: '',
          ),
          (failed: true, :final output) => (
            exitCode: exitCode == 0 ? 1 : exitCode,
            output: '$output$cause',
            withoutReport: '',
          ),
          (failed: false, :final output) => (
            exitCode: located ? 0 : exitCode,
            output: output,
            withoutReport: cause,
          ),
        };
      }(),
  };
}

final _header = RegExp(r'^\d+:\d+ \+\d+(?: ~\d+)?(?: -\d+)?: ');

/// Les blocs de la console du reporter `expanded` dont l'en-tête
/// (`00:04 +1: <chemin>: <test>`) nomme le fichier [name], chacun jusqu'à
/// l'en-tête suivant.
String consoleBlocks(String console, String name) {
  final out = StringBuffer();
  var inside = false;
  for (final line in const LineSplitter().convert(console)) {
    if (_header.hasMatch(line)) inside = line.contains('/$name');
    if (inside) out.writeln(line);
  }
  return '$out';
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/environment_failure.dart';
import '../project/flutter_sdk.dart';

enum Severity { error, warning, info }

typedef Diagnostic = ({
  Severity severity,
  String code,
  String file,
  int line,
  int column,
  String message,
});

Map<String, Object?> diagnosticToJson(Diagnostic d) => {
  'severity': d.severity.name,
  'code': d.code,
  'file': d.file,
  'line': d.line,
  'column': d.column,
  'message': d.message,
};

String describeDiagnostic(Diagnostic d) =>
    '${d.file}:${d.line}:${d.column}: [${d.code}] ${d.message}';

/// `dart analyze --format=json` du SDK épinglé sur [paths], chemins rendus
/// relatifs au projet.
Future<List<Diagnostic>> analyze(
  FlutterSdk sdk,
  Directory project,
  List<String> paths,
) async {
  await ensureResolved(sdk, project);
  final result = await Process.run(sdk.dart, [
    'analyze',
    '--format=json',
    ...paths,
  ], workingDirectory: project.path);
  final root = project.resolveSymbolicLinksSync();
  final Object? json;
  try {
    json = jsonDecode(result.stdout as String);
  } on FormatException {
    throw EnvironmentFailure('dart analyze failed: ${result.stderr}');
  }
  return switch (json) {
    {'diagnostics': final List<Object?> items} => [
      for (final item in items) _diagnostic(item, root),
    ],
    _ => throw EnvironmentFailure('dart analyze: output has no diagnostics.'),
  };
}

/// Un projet cloné ou nettoyé n'a pas `.dart_tool/package_config.json` :
/// sans lui, l'analyseur ne résout aucun `package:` et tout est en erreur.
Future<void> ensureResolved(FlutterSdk sdk, Directory project) async {
  final config = File(
    p.join(project.path, '.dart_tool', 'package_config.json'),
  );
  if (config.existsSync()) return;
  final result = await Process.run(sdk.flutter, [
    'pub',
    'get',
  ], workingDirectory: project.path);
  if (result.exitCode != 0 || !config.existsSync()) {
    throw EnvironmentFailure('flutter pub get failed: ${result.stderr}');
  }
}

Diagnostic _diagnostic(Object? json, String root) => switch (json) {
  {
    'severity': final String severity,
    'code': final String code,
    'problemMessage': final String message,
    'location': {
      'file': final String file,
      'range': {'start': {'line': final int line, 'column': final int column}},
    },
  } =>
    (
      severity: Severity.values.byName(severity.toLowerCase()),
      code: code,
      file: p.isWithin(root, file) ? p.relative(file, from: root) : file,
      line: line,
      column: column,
      message: message,
    ),
  _ => throw const EnvironmentFailure('dart analyze: unreadable diagnostic.'),
};

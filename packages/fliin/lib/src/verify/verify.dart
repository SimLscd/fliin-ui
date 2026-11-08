import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/analyze.dart';
import '../project/environment_failure.dart';
import '../project/project.dart';
import 'harness_source.g.dart';
import 'reference.dart';
import 'report.dart';
import 'test_results.dart';
import 'test_source.dart';

/// L'entrée à rendre, préfixe déjà substitué, et ses imports en URI `package:`.
typedef VerifySpec = ({
  String entry,
  Set<String> imports,
  VerifyCanvas? canvas,
  int? settleMs,
});

sealed class VerifyOutcome {
  const VerifyOutcome();
}

/// Sortie 2 : les fichiers de l'élément ne passent pas `dart analyze`.
final class VerifyAnalysisFailed extends VerifyOutcome {
  const VerifyAnalysisFailed(this.errors);

  final List<Diagnostic> errors;
}

/// Sortie 2 : `flutter test` n'a pas produit de rapport (compilation, environnement).
final class VerifyTestFailed extends VerifyOutcome {
  const VerifyTestFailed(this.output);

  final String output;
}

/// Sortie 3 : un fichier installé de l'élément manque, ou son `report.json`
/// est illisible. [message] est celui que l'élément vérifié seul donnerait.
final class VerifyEnvironmentFailed extends VerifyOutcome {
  const VerifyEnvironmentFailed(this.message);

  final String message;
}

/// Sortie 1 : `<out>/<élément>/golden/` existe et verify ne l'a pas créé.
final class VerifyOutDirTaken extends VerifyOutcome {
  const VerifyOutDirTaken(this.path);

  /// Relatif au projet.
  final String path;
}

/// Le fichier que verify pose dans le dossier des références qu'il écrit :
/// seul un dossier qui le porte est supprimé au rendu suivant.
const goldenMarker = '.fliin-verify';

final class VerifyDone extends VerifyOutcome {
  const VerifyDone(
    this.report,
    this.outDir, {
    required this.plan,
    required this.testExitCode,
    required this.missing,
    required this.output,
  });

  final VerifyReport report;

  /// La décision sur la référence, rendu compris.
  final ReferencePlan plan;

  /// Relatif au projet : les PNG, `overview.png` et `report.json` sont dedans.
  final String outDir;

  /// Celui de `flutter test` : non nul quand un test a échoué pour une raison
  /// que le rapport ne porte pas, comme un minuteur laissé en attente.
  final int testExitCode;

  /// Les variantes demandées que le rapport ne contient pas.
  final List<String> missing;

  /// Ce que `flutter test` a écrit.
  final String output;
}

const harnessDir = 'test/.fliin';

/// Un élément à vérifier : sa version installée, ses fichiers (relatifs au
/// projet), son entrée, ses références téléchargées (PNG vérifiés, par
/// variante) et la décision qui dit, avec ce que le harnais rapporte de son
/// rendu, si l'écart à ces références vaut quelque chose.
typedef VerifyItem = ({
  ItemRef ref,
  Iterable<String> files,
  VerifySpec spec,
  Map<String, Uint8List> references,
  ReferencePlan Function(Rendering? rendered) reference,
});

/// DESIGN.md §4.5 : analyse, génération des tests, `flutter test`, lecture
/// des rapports, une issue par élément de [items], dans leur ordre. Un seul
/// `dart analyze` porte sur l'union de leurs fichiers, et un seul `flutter
/// test` sur leurs tests générés : un diagnostic d'erreur fait échouer chaque
/// élément qui possède son fichier (tous, si aucun ne le possède : l'analyse
/// ne s'assouplit jamais), un test qui ne compile pas ou ne produit pas de
/// rapport seulement le sien. Les diagnostics non bloquants d'un
/// élément vont dans `analyze.diagnostics` de son rapport, le code de sortie
/// de son test et ses variantes manquantes dans `test`. Ses références sont
/// écrites sous `<out>/<élément>/golden/`, que le harnais compare
/// (ADR 0011), et sa décision devient `reference` du rapport. Un `golden/`
/// que verify n'a pas créé (sans [goldenMarker]) n'est jamais supprimé :
/// [VerifyOutDirTaken].
Future<List<VerifyOutcome>> runVerify({
  required Project project,
  required RenderConfig render,
  required List<VerifyItem> items,
  required String out,
  required List<String> variants,
}) async {
  final outcomes = List<VerifyOutcome?>.filled(items.length, null);
  for (final (index, item) in items.indexed) {
    if (item.files.every(
      (f) => File(p.join(project.dir.path, f)).existsSync(),
    )) {
      continue;
    }
    try {
      await analyze(project.sdk, project.dir, item.files.toList());
    } on EnvironmentFailure catch (e) {
      outcomes[index] = VerifyEnvironmentFailed(e.message);
    }
  }
  final analyzed = {
    for (final (index, item) in items.indexed)
      if (outcomes[index] == null) ...item.files,
  };
  final diagnostics = analyzed.isEmpty
      ? const <Diagnostic>[]
      : await analyze(project.sdk, project.dir, analyzed.toList());
  final owned = [for (final item in items) item.files.toSet()];
  bool orphan(Diagnostic d) => !owned.any((files) => files.contains(d.file));
  final pending = <(int, VerifyItem, List<Diagnostic>, String outDir)>[];
  for (final (index, item) in items.indexed) {
    if (outcomes[index] != null) continue;
    final mine = [
      for (final d in diagnostics)
        if (owned[index].contains(d.file) || orphan(d)) d,
    ];
    final errors = [
      for (final d in mine)
        if (d.severity == Severity.error) d,
    ];
    if (errors.isNotEmpty) {
      outcomes[index] = VerifyAnalysisFailed(errors);
      continue;
    }
    final outDir = p.join(out, item.ref.name);
    final goldens = p.join(outDir, 'golden');
    final goldensDir = Directory(p.join(project.dir.path, goldens));
    if (goldensDir.existsSync()) {
      if (!File(p.join(goldensDir.path, goldenMarker)).existsSync()) {
        outcomes[index] = VerifyOutDirTaken(goldens);
        continue;
      }
      goldensDir.deleteSync(recursive: true);
    }
    if (item.references.isNotEmpty) {
      File(p.join(goldensDir.path, goldenMarker))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('');
    }
    for (final MapEntry(key: id, value: png) in item.references.entries) {
      File(p.join(goldensDir.path, '$id.png')).writeAsBytesSync(png);
    }
    File(p.join(project.dir.path, _testPath(item.ref)))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        verifyTestSource(
          item: item.ref.name,
          version: '${item.ref.version}',
          prefix: render.prefix,
          entry: item.spec.entry,
          imports: item.spec.imports,
          outDir: outDir,
          variants: variants,
          canvas: item.spec.canvas,
          settleMs: item.spec.settleMs,
          goldens: item.references.isEmpty ? null : goldens,
        ),
      );
    final reportFile = File(p.join(project.dir.path, outDir, 'report.json'));
    if (reportFile.existsSync()) reportFile.deleteSync();
    pending.add((index, item, mine, outDir));
  }
  if (pending.isEmpty) return outcomes.cast();

  File(p.join(project.dir.path, harnessDir, 'fliin_harness.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(harnessSource);
  final tests = await _flutterTest(project, [
    for (final (_, item, _, _) in pending) _testPath(item.ref),
  ]);
  for (final (index, item, mine, outDir) in pending) {
    try {
      outcomes[index] = _read(
        project,
        item,
        mine,
        outDir,
        variants,
        tests[_testPath(item.ref)]!,
      );
    } on EnvironmentFailure catch (e) {
      outcomes[index] = VerifyEnvironmentFailed(e.message);
    } on FormatException catch (e) {
      outcomes[index] = VerifyEnvironmentFailed(
        'report.json is unreadable: ${e.message}',
      );
    }
  }
  return outcomes.cast();
}

String _testPath(ItemRef ref) =>
    p.join(harnessDir, '${ref.name}_verify_test.dart');

/// Un `flutter test` pour tous les [paths], le résultat par fichier. Avec un
/// seul fichier, celui du processus. Avec plusieurs, [splitTestRun] découpe
/// le rapport JSON et la console. Un fichier à la fois : quand un fichier ne
/// compile pas, `flutter test` signale aussi en échec le chargement d'un
/// fichier compilé en même temps (constaté sous Flutter 3.47.7), et un seul
/// `flutter_tester` tient la mémoire de la machine où verify enchaînait déjà
/// les éléments un par un.
Future<Map<String, TestRun>> _flutterTest(
  Project project,
  List<String> paths,
) async {
  if (paths case [final path]) {
    final result = await Process.run(project.sdk.flutter, [
      'test',
      path,
    ], workingDirectory: project.dir.path);
    return {
      path: (
        exitCode: result.exitCode,
        output: '${result.stdout}${result.stderr}',
        withoutReport: '',
      ),
    };
  }
  final scratch = Directory.systemTemp.createTempSync('fliin-verify-');
  try {
    final reporter = File(p.join(scratch.path, 'results.json'));
    final result = await Process.run(project.sdk.flutter, [
      'test',
      '--concurrency=1',
      '--file-reporter',
      'json:${reporter.path}',
      ...paths,
    ], workingDirectory: project.dir.path);
    return splitTestRun(
      paths: paths,
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
      suites: reporter.existsSync()
          ? suiteResults(reporter.readAsStringSync())
          : null,
    );
  } finally {
    scratch.deleteSync(recursive: true);
  }
}

VerifyOutcome _read(
  Project project,
  VerifyItem item,
  List<Diagnostic> diagnostics,
  String outDir,
  List<String> variants,
  TestRun test,
) {
  final reportFile = File(p.join(project.dir.path, outDir, 'report.json'));
  if (!reportFile.existsSync()) {
    return VerifyTestFailed('${test.output}${test.withoutReport}');
  }
  final json = jsonDecode(reportFile.readAsStringSync());
  final plan = item.reference(
    json is Map<String, Object?> ? renderingOf(json) : null,
  );
  if (json case {'variants': final List<Object?> all}
      when plan is SkipReference) {
    for (final variant in all) {
      if (variant is Map<String, Object?>) variant['golden'] = null;
    }
  }
  final report = VerifyReport.parse(json);
  final rendered = {for (final v in report.variants) v.id};
  final missing = [
    for (final id in variants.isEmpty ? variantIds : variants)
      if (!rendered.contains(id)) id,
  ];
  report.json['analyze'] = {
    'diagnostics': [for (final d in diagnostics) diagnosticToJson(d)],
  };
  report.json['reference'] = plan.toJson();
  report.json['test'] = {'exitCode': test.exitCode, 'missingVariants': missing};
  reportFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report.json)}\n',
  );
  return VerifyDone(
    report,
    outDir,
    plan: plan,
    testExitCode: test.exitCode,
    missing: missing,
    output: test.output,
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../install/analyze.dart';
import '../install/registry_port.dart';
import '../install/lockfile_io.dart';
import '../install/status.dart';
import '../install/targets.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import '../tokens/project_tokens.dart';
import '../verify/reference.dart';
import '../verify/report.dart';
import '../verify/verify.dart';
import 'exit_code.dart';
import 'project_command.dart';

class VerifyCommand extends ProjectCommand {
  VerifyCommand(super.openRegistry, super.io) {
    argParser
      ..addMultiOption(
        'variants',
        allowed: variantIds,
        help: 'The variants to render (default: all 16).',
      )
      ..addOption(
        'out',
        defaultsTo: 'build/fliin/verify',
        help: 'The output folder for renders.',
      )
      ..addFlag(
        'all',
        negatable: false,
        help:
            'Every installed item that has a verify entry, instead of a '
            'list.',
      )
      ..addFlag(
        'changed',
        negatable: false,
        help:
            'The installed items with a file, or a dependency’s file, that is '
            'no longer the one fliin wrote (modified, deleted, in conflict), '
            'instead of a list.',
      )
      ..addFlag(
        'strict',
        negatable: false,
        help: 'A difference from the reference golden also fails.',
      )
      ..addOption(
        'entry',
        help: 'A Dart expression for the widget to render, instead of the manifest’s verify.entry.',
      )
      ..addMultiOption(
        'import',
        help: 'A file under lib/ or a package: URI that --entry uses.',
      );
  }

  @override
  String get name => 'verify';

  @override
  bool get writesProject => true;

  @override
  String get description =>
      'Renders installed items across the variant matrix and writes their '
      'reports. Several items share one analysis and one flutter test. Each '
      'item’s output is the one it would have alone, --json groups them '
      'under items in the requested order, and the exit code is the most '
      'severe one (3, then 2, then 1, then 0). --all and --changed pick the '
      'items, and --json always groups them under items.';

  @override
  String get invocation => 'fliin verify <item> [<item>…] | --all | --changed';

  @override
  Future<int> execute() async {
    final args = argResults!;
    final selection = _selection(args.rest);
    final custom =
        args.option('entry') != null || args.multiOption('import').isNotEmpty;
    if (custom && (selection != null || args.rest.length > 1)) {
      usageException(
        '--entry and --import render a single item. Verify it on its own.',
      );
    }
    final dir = projectDir;
    final config = readFliinConfig(dir);
    final lockfile = readLockfile(dir);
    if (config == null || lockfile == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName or $lockfileName not found. Run fliin init.',
      );
    }
    requireSameConfig(lockfile, config.render);
    final refs = _refs(switch (selection) {
      null => [for (final text in args.rest) _parse(text)],
      _Selection.all => lockfile.items.keys.toList(),
      _Selection.changed => _changed(dir, lockfile),
    }, args.option('out')!);
    final absent = [
      for (final ref in refs)
        if (!lockfile.items.containsKey(ref)) ref,
    ];
    if (absent.isNotEmpty) {
      return fail(
        ExitCode.failure,
        [
          for (final ref in absent)
            describeNotInstalled(ref, lockfile.items.keys),
        ].join('\n'),
      );
    }
    final project = await probe(dir);
    requireFlutter(project);
    final render = config.render;
    final variants = args.multiOption('variants');
    final items = <VerifyItem>[];
    final unverifiable = <String>[];
    Future<Registry>? registry;
    final skipped = <ItemRef>[];
    final verified = <ItemRef>[];
    for (final ref in refs) {
      final item = await _item(
        () => registry ??= openProjectRegistry(config),
        project,
        ref,
        lockfile,
        config,
        variants,
        args.option('entry'),
        args.multiOption('import'),
      );
      if (item == null && selection != null) {
        skipped.add(ref);
      } else if (item == null) {
        unverifiable.add(
          'The manifest of $ref has no verify entry. Pass --entry and --import.',
        );
      } else {
        items.add(item);
        verified.add(ref);
      }
    }
    if (unverifiable.isNotEmpty) {
      return fail(ExitCode.failure, unverifiable.join('\n'));
    }
    if (selection != null) {
      final chosen = verified;
      final note = [
        '--${selection.name}: ${switch (chosen) {
          [] => switch (selection) {
            _Selection.all => 'no installed item has a verify entry',
            _Selection.changed => 'no verifiable item is touched by a local change',
          },
          _ => chosen.join(', '),
        }}',
        if (skipped.isNotEmpty)
          '  no verify entry, not rendered: ${skipped.join(', ')}',
      ];
      if (!jsonOutput) note.forEach(io.out.writeln);
      if (items.isEmpty) {
        if (jsonOutput) {
          io.out.writeln(
            jsonEncode({
              'selection': selection.name,
              'items': const <Object?>[],
              'skipped': [for (final ref in skipped) '$ref'],
            }),
          );
        }
        return ExitCode.ok.code;
      }
    }

    final outcomes = await runVerify(
      project: project,
      render: render,
      items: items,
      out: args.option('out')!,
      variants: variants,
    );
    final results = [
      for (final (index, outcome) in outcomes.indexed)
        _result(
          verified[index],
          items[index].ref,
          outcome,
          args.flag('strict'),
        ),
    ];
    if (results case [final only] when jsonOutput && selection == null) {
      _write(only, [jsonEncode(only.json)]);
    } else {
      for (final result in results) {
        _write(result, jsonOutput ? const [] : result.out);
      }
      if (jsonOutput) {
        io.out.writeln(
          jsonEncode({
            if (selection != null) 'selection': selection.name,
            'items': [for (final result in results) result.json],
            if (selection != null)
              'skipped': [for (final ref in skipped) '$ref'],
          }),
        );
      }
    }
    return mostSevere([for (final result in results) result.code]).code;
  }

  /// [out] sur stdout et les erreurs de [result] sur stderr, dans l'ordre où
  /// un élément vérifié seul les écrit : un échec avant tout rendu dit sa
  /// cause d'abord, un rendu écrit son résultat d'abord.
  void _write(_ItemResult result, List<String> out) {
    if (result.errorFirst) result.err.forEach(io.err.writeln);
    out.forEach(io.out.writeln);
    if (!result.errorFirst) result.err.forEach(io.err.writeln);
  }

  /// L'élément [ref] tel que verify le rend : `verify` de son manifeste, ou
  /// [entry] et [imports] ; null quand le manifeste n'a pas de `verify`.
  Future<VerifyItem?> _item(
    Future<Registry> Function() openOnce,
    Project project,
    ItemRef ref,
    Lockfile lockfile,
    FliinConfig config,
    List<String> variants,
    String? entry,
    List<String> imports,
  ) async {
    final locked = lockfile.items[ref]!;
    final render = config.render;
    final core = importUri(
      render,
      projectPath(render, ItemTarget(TargetAlias.core, 'fliin.dart')),
    );
    if (entry != null) {
      return (
        ref: ref.at(locked.version),
        files: locked.files.keys,
        spec: (
          entry: _withPrefix(entry, render.prefix),
          imports: {core, for (final text in imports) _importUri(text, render)},
          canvas: null,
          settleMs: null,
        ),
        references: const <String, Uint8List>{},
        reference: (Rendering? rendered) => planReference(
          goldens: null,
          customEntry: true,
          host: Platform.operatingSystem,
          defaultTheme: true,
          rendered: rendered,
        ),
      );
    }
    final registry = await openOnce();
    final manifest = await registry.fetchManifest(ref, locked.version);
    // Seule la borne basse : pub ignore la borne haute de la contrainte
    // flutter, et l'élément rendu est déjà installé.
    requireFlutter(project, {
      '${ref.at(locked.version)}': switch (manifest.flutter) {
        VersionRange(:final min?, :final includeMin) => VersionRange(
          min: min,
          includeMin: includeMin,
        ),
        _ => VersionConstraint.any,
      },
    });
    final verify = manifest.verify;
    if (verify == null) return null;
    final defaultTheme = _defaultTheme(projectDir, render, lockfile);
    final defaultIcons =
        config.preset?.icons.variant == null || !_drawsIcons(ref, lockfile);
    ReferencePlan reference(Rendering? rendered) => planReference(
      goldens: verify.goldens,
      customEntry: false,
      host: Platform.operatingSystem,
      defaultTheme: defaultTheme,
      defaultIcons: defaultIcons,
      rendered: rendered,
    );
    return (
      ref: ref.at(locked.version),
      files: locked.files.keys,
      spec: (
        entry: _withPrefix(verify.entry, render.prefix),
        imports: {
          core,
          for (final target in verify.imports)
            importUri(render, projectPath(render, target)),
        },
        canvas: verify.canvas,
        settleMs: verify.settleMs,
      ),
      references: switch (reference(null)) {
        CompareToReference(:final goldens) => {
          for (final id in variants.isEmpty ? variantIds : variants)
            id: await registry.fetchBlob(goldens.variants[id]!),
        },
        SkipReference() => const <String, Uint8List>{},
      },
      reference: reference,
    );
  }

  /// Ce que l'élément [ref] aurait écrit et rendu, vérifié seul.
  _ItemResult _result(
    ItemRef ref,
    ItemRef installed,
    VerifyOutcome outcome,
    bool strict,
  ) {
    switch (outcome) {
      case VerifyAnalysisFailed(:final errors):
        return _failed(
          ExitCode.analysis,
          [
            'dart analyze rejects $ref:',
            for (final d in errors) '  ${describeDiagnostic(d)}',
          ].join('\n'),
          {
            'analyze': {
              'diagnostics': [for (final d in errors) diagnosticToJson(d)],
            },
          },
        );
      case VerifyOutDirTaken(:final path):
        return _failed(
          ExitCode.failure,
          '$path exists and fliin verify did not create it. Pick another '
          '--out. Nothing was deleted.',
        );
      case VerifyEnvironmentFailed(:final message):
        return _failed(ExitCode.environment, message);
      case VerifyTestFailed(:final output):
        return _failed(
          ExitCode.analysis,
          'flutter test produced no report:\n$output',
        );
      case VerifyDone(
        :final report,
        :final outDir,
        :final testExitCode,
        :final missing,
        :final output,
        :final plan,
      ):
        final unverifiable = strict && plan is SkipReference;
        return (
          code: unverifiable
              ? ExitCode.failure
              : report.verdict(
                  strict: strict,
                  testExitCode: testExitCode,
                  missing: missing,
                ),
          out: [
            '$installed: ${report.summary.join('\n  ')}',
            '  ${_describeReference(plan, report)}',
            if (report.warnings.isNotEmpty)
              '  warning: ${report.warnings.length} contrast '
                  '${report.warnings.length > 1 ? 'failures' : 'failure'} covered by '
                  'the theme’s declared exceptions, details in report.json. '
                  'fliin theme --primary gives a compliant theme with no exception',
            '  ${p.join(outDir, 'overview.png')}',
            '  ${p.join(outDir, 'report.json')}',
          ],
          err: [
            if (missing.isNotEmpty)
              'Variants requested but not rendered: ${missing.join(', ')}',
            if (unverifiable)
              '--strict requires a comparable reference: ${plan.reason}',
            if (testExitCode != 0)
              'flutter test failed (exit code $testExitCode):\n${_tail(output)}',
          ],
          json: report.json,
          errorFirst: false,
        );
    }
  }

  /// Ce que [ProjectCommand.fail] aurait écrit pour un seul élément.
  static _ItemResult _failed(
    ExitCode code,
    String message, [
    Map<String, Object?> json = const {},
  ]) => (
    code: code,
    out: const [],
    err: [message],
    errorFirst: true,
    json: {
      ...json,
      'error': {'code': code.code, 'message': message},
    },
  );

  /// Ce que `flutter test` dit du premier échec, depuis l'exception qu'il
  /// journalise avant la ligne `[E]`, borné à quarante lignes ; à défaut, ses
  /// vingt dernières lignes.
  static String _tail(String output) {
    final lines = output.trimRight().split('\n');
    final first = lines.indexWhere(
      (line) => line.contains('EXCEPTION CAUGHT') || line.contains(' [E]'),
    );
    return (first >= 0
            ? lines.skip(first).take(40)
            : lines.skip(lines.length > 20 ? lines.length - 20 : 0))
        .join('\n');
  }

  /// L'écart reste indicatif sans `--strict` (règle 9) : la ligne le dit.
  static String _describeReference(ReferencePlan plan, VerifyReport report) {
    switch (plan) {
      case SkipReference(:final reason):
        return 'reference not compared: $reason';
      case CompareToReference():
        final diffs = [
          for (final variant in report.variants)
            if (variant.goldenDiffPct case final pct?) (variant.id, pct),
        ];
        final drifted = diffs.where((d) => d.$2 > 0).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
        return switch (drifted) {
          [] =>
            'difference from the reference golden (for information): '
                '${diffs.length}/${diffs.length} identical',
          [(final id, final pct), ...] =>
            'difference from the reference golden (for information): '
                '${drifted.length}/${diffs.length} variants differ, '
                'at most ${pct.toStringAsFixed(2)}% ($id)',
        };
    }
  }

  /// `fliin.tokens.json` est celui que `core` a installé, préfixe compris :
  /// aucun `fliin theme` ni édition depuis.
  static bool _defaultTheme(
    Directory dir,
    RenderConfig render,
    Lockfile lockfile,
  ) {
    final path = projectPath(
      render,
      ItemTarget(TargetAlias.core, 'tokens/$tokensJsonName'),
    );
    final locked = lockfile.items[ItemRef('core')]?.files[path];
    final file = File(p.join(dir.path, path));
    return locked != null &&
        file.existsSync() &&
        Sha256.ofBytes(file.readAsBytesSync()) == (locked.base ?? locked.raw);
  }

  /// Vrai quand [ref] est `icons` ou en dépend, directement ou non, selon
  /// les dépendances résolues du lockfile.
  static bool _drawsIcons(ItemRef ref, Lockfile lockfile) {
    final seen = <ItemRef>{};
    final pending = [ref];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (next == _icons) return true;
      if (!seen.add(next)) continue;
      for (final dependency
          in lockfile.items[next]?.registryDependencies ?? const <ItemRef>[]) {
        pending.add(ItemRef(dependency.name, namespace: dependency.namespace));
      }
    }
    return false;
  }

  static final _icons = ItemRef('icons');

  /// `--all` ou `--changed`, nul pour une liste d'éléments : l'un des trois,
  /// jamais deux.
  _Selection? _selection(List<String> rest) {
    final flags = [
      for (final selection in _Selection.values)
        if (argResults!.flag(selection.name)) selection,
    ];
    return switch ((flags, rest)) {
      ([], []) => usageException(
        'Expected an item, or --all (everything installed and verifiable) '
        'or --changed (what a local change touches).',
      ),
      ([], _) => null,
      ([final only], []) => only,
      ([_], _) => usageException(
        '--${flags.single.name} replaces the list of items. Use one or the '
        'other.',
      ),
      _ => usageException('Use --all or --changed, not both.'),
    };
  }

  ItemRef _parse(String text) {
    try {
      return ItemRef.parseUnversioned(text);
    } on FormatException catch (e) {
      usageException('${e.message}: ${e.source}');
    }
  }

  /// Les éléments dont un fichier n'est plus celui que fliin a écrit, au
  /// sens de `localState` (un fichier fusionné par update compte), et ceux
  /// qui en dépendent, de proche en proche : leur rendu passe par ce code,
  /// les jetons de `core` compris.
  static List<ItemRef> _changed(Directory dir, Lockfile lockfile) {
    final touched = {
      for (final MapEntry(key: ref, value: item) in lockfile.items.entries)
        if (item.files.entries.any(
          (f) =>
              localState(f.value, onDisk(dir, f.key)) != InstalledState.intact,
        ))
          ref,
    };
    bool reaches(ItemRef ref, Set<ItemRef> seen) =>
        touched.contains(ref) ||
        (lockfile.items[ref]?.registryDependencies ?? const []).any(
          (d) => switch (ItemRef(d.name, namespace: d.namespace)) {
            final bare => seen.add(bare) && reaches(bare, seen),
          },
        );
    return [
      for (final ref in lockfile.items.keys)
        if (reaches(ref, {ref})) ref,
    ];
  }

  /// Chaque élément une seule fois. Deux éléments distincts du
  /// même nom, dans deux espaces de noms, écriraient le même test et le même
  /// `<out>/<élément>/` : refusés aussi.
  List<ItemRef> _refs(List<ItemRef> refs, String out) {
    final byName = <String, ItemRef>{};
    for (final ref in refs) {
      switch (byName[ref.name]) {
        case null:
          byName[ref.name] = ref;
        case final seen when seen == ref:
          usageException('$ref is requested twice.');
        case final seen:
          usageException(
            '$seen and $ref would both write under '
            '${p.join(out, ref.name)}. Verify them separately.',
          );
      }
    }
    return refs;
  }

  String _withPrefix(String entry, String prefix) =>
      entry.replaceAll('{prefix}', prefix);

  String _importUri(String text, RenderConfig render) {
    if (text.startsWith('package:')) return text;
    if (text.startsWith('lib/')) return importUri(render, text);
    usageException(
      '--import expects a path under lib/ or a package: URI: $text',
    );
  }
}

enum _Selection { all, changed }

/// La sortie d'un élément : son code, ses lignes sur stdout et stderr, et son
/// objet `--json`.

typedef _ItemResult = ({
  ExitCode code,
  List<String> out,
  List<String> err,
  Map<String, Object?> json,
  bool errorFirst,
});

/// Du moins grave au plus grave, les codes qu'un élément peut rendre : un
/// fichier ou un rapport que l'environnement rend illisible (3) et une
/// analyse ou une compilation refusée (2) empêchent tout résultat, une
/// vérification qui échoue (1) en a un.
const verifySeverity = [
  ExitCode.ok,
  ExitCode.failure,
  ExitCode.analysis,
  ExitCode.environment,
];

/// Le plus grave de [codes] ; un code absent de [verifySeverity] passe avant
/// tous, pour qu'un échec nouveau ne soit jamais pris pour un succès.
ExitCode mostSevere(Iterable<ExitCode> codes) {
  int rank(ExitCode code) => switch (verifySeverity.indexOf(code)) {
    -1 => verifySeverity.length,
    final index => index,
  };
  return codes.reduce((a, b) => rank(b) > rank(a) ? b : a);
}

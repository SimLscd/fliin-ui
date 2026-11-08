import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../install/analyze.dart';
import '../install/lockfile_io.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import '../update/journal.dart';
import '../update/report.dart';
import '../update/updater.dart';
import 'exit_code.dart';
import 'project_command.dart';

class UpdateCommand extends ProjectCommand {
  UpdateCommand(super.openRegistry, super.io) {
    argParser
      ..addOption(
        'conflict',
        allowed: [for (final s in ConflictStrategy.values) s.name],
        defaultsTo: ConflictStrategy.sidecar.name,
        help:
            'sidecar: the local file stays and the upstream version waits in '
            '<file>.fliin-new, so the project still compiles. markers: '
            'conflict markers in the file.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help:
            'Tells whether a newer version exists, without writing anything. '
            'Exits with 6 if one does (for CI).',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Computes and shows the result for each file, without writing.',
      );
  }

  @override
  String get name => 'update';

  @override
  String get description =>
      'Updates installed items with a three-way merge, without ever losing '
      'a local change.';

  @override
  String get invocation => 'fliin update [<item>...]';

  bool get _check => argResults!.flag('check');

  bool get _dryRun => argResults!.flag('dry-run');

  @override
  bool get writesProject => !_check && !_dryRun;

  @override
  Future<int> execute() async {
    final dir = projectDir;
    final config = readFliinConfig(dir);
    final lockfile = readLockfile(dir);
    if (config == null || lockfile == null) {
      return fail(
        ExitCode.environment,
        '${config == null ? fliinYamlName : lockfileName} not found. '
        'Run fliin init.',
      );
    }
    final rest = argResults!.rest;
    final requested = rest.isEmpty ? <ItemDependency>[] : parseRefs(rest);
    final project = await probe(dir);
    requireFlutter(project);
    final updater = Updater(
      project: project,
      config: config,
      registry: await openProjectRegistry(config),
      lockfile: lockfile,
    );
    if (writesProject) updater.dropStaleJournal();
    final UpdatePlan plan;
    switch (await updater.plan(requested, check: _check)) {
      case JournalPending(:final targets):
        return fail(
          ExitCode.failure,
          'An interrupted update to '
          '${[for (final MapEntry(:key, :value) in targets.entries) '$key@$value'].join(', ')} '
          'is pending (${UpdateJournal.path}). Run fliin update with no '
          'arguments to finish it first.',
        );
      case NotInstalled(:final ref):
        return fail(
          ExitCode.failure,
          describeNotInstalled(ref, lockfile.items.keys),
        );
      case PlanFailed(error: final FlutterTooOld error):
        return fail(
          ExitCode.environment,
          '${describeResolution(error)} ${flutterRemedy(project.sdk)}',
        );
      case PlanFailed(:final error):
        return fail(ExitCode.failure, describeResolution(error));
      case final UpdatePlan planned:
        plan = planned;
    }

    final needsFlutter = (
      json: needsFlutterJson(plan.needsFlutter),
      lines: needsFlutterLines(plan.needsFlutter, project),
    );
    if (_check) {
      return _available(await updater.available(plan), plan, needsFlutter);
    }
    final resolved = updater.resolved;
    if (plan.changes.isEmpty) {
      if (resolved.isNotEmpty && !_dryRun) updater.writeSettled();
      final waiting = updater.pendingConflicts();
      return succeed(
        {
          'dryRun': _dryRun,
          'resolved': resolved,
          'pendingConflicts': [
            for (final f in waiting) {'path': f.path, 'sidecar': f.sidecar},
          ],
          'items': const <Object?>[],
          'held': heldJson(plan.held),
          'needsFlutter': needsFlutter.json,
          'lockfileWritten': resolved.isNotEmpty && !_dryRun,
        },
        [
          for (final path in resolved) 'conflict resolved: $path',
          ...heldLines(plan.held),
          ...needsFlutter.lines,
          'Everything is up to date.',
          for (final f in waiting)
            'pending conflict: ${f.path} (upstream version: ${f.sidecar})',
        ],
      );
    }

    final strategy = ConflictStrategy.values.byName(
      argResults!.option('conflict')!,
    );
    final UpdateOutcome outcome;
    try {
      outcome = await updater.apply(plan, strategy: strategy, dryRun: _dryRun);
    } on FileSystemException catch (e) {
      return fail(
        ExitCode.environment,
        'Writing was interrupted (${e.message}${e.path == null ? '' : ': ${e.path}'}). '
        'Run fliin update again. It resumes where it stopped '
        '(${UpdateJournal.path}).',
      );
    }
    switch (outcome) {
      case UnresolvedConflicts(:final files):
        return fail(
          ExitCode.failure,
          [
            'Conflicts are waiting to be resolved. Nothing was written:',
            for (final f in files)
              '  ${f.path} (upstream version: ${f.sidecar})',
            'In each file, keep what you want from the upstream version, '
                'delete the .fliin-new file, then run fliin update again.',
          ].join('\n'),
          {
            'unresolved': [
              for (final f in files) {'path': f.path, 'sidecar': f.sidecar},
            ],
          },
        );
      case PathOwned(:final path, :final owner, :final claimedBy):
        return fail(
          ExitCode.failure,
          '$path belongs to $owner, and the new version of $claimedBy '
          'wants to install it. Nothing was written.',
        );
      case MissingPubDependencies(:final dependencies):
        return fail(
          ExitCode.confirmation,
          [
            'The new versions require pub packages the project does not '
                'have. Nothing was written. Add them (flutter pub add), then '
                'run the command again:',
            for (final d in dependencies)
              '  ${d.package} ${d.constraint} (${d.requiredBy})',
          ].join('\n'),
          {
            'needsDependencies': [
              for (final d in dependencies)
                {
                  'package': d.package,
                  'constraint': '${d.constraint}',
                  'requiredBy': '${d.requiredBy}',
                },
            ],
          },
        );
      case AnalysisRegressed(:final items, :final errors):
        return fail(
          ExitCode.analysis,
          [
            'After the update, dart analyze finds errors these files did not '
                'have. Nothing was written and the lockfile did not change.',
            for (final d in errors) '  ${describeDiagnostic(d)}',
          ].join('\n'),
          {
            ..._report(items, resumed: plan.resumed, resolved: resolved),
            'lockfileWritten': false,
            'analyze': {
              'diagnostics': [for (final d in errors) diagnosticToJson(d)],
            },
          },
        );
      case Updated(:final items, :final dryRun, :final held):
        final presetNotes = [
          if (config.retiredPreset case final code?)
            'preset $code in fliin.yaml ignored: ${retiredPresetMessage(code[0])}, '
                'then run fliin theme --preset <code>',
          if (config.preset case final preset?)
            for (final note in updater.presetNotes)
              'preset ${preset.encode()} not reapplied to '
                  'fliin.tokens.json ($note). Merged without it. Once this '
                  'is fixed, run fliin theme --preset ${preset.encode()}',
        ];
        // Un thème posé par fliin theme --primary ne laisse pas de trace à
        // réappliquer, contrairement à un préréglage : quand la nouvelle
        // version de core change les couleurs, le fichier de jetons part en
        // conflit et retient core, donc tout ce qui l'exige.
        final tokenNotes = [
          if (config.preset == null)
            for (final item in items)
              for (final file in item.files)
                if (file case Conflict(:final path, :final sidecar?)
                    when path.endsWith('/core/tokens/fliin.tokens.json'))
                  '$path holds your theme settings and ${item.ref} ${item.to} '
                      'changes the shipped tokens. To update, replace it with '
                      '$sidecar, delete the .fliin-new file, run fliin tokens '
                      'then fliin update, then redo your theme (fliin theme '
                      '--primary …) and carry over your other token changes',
        ];
        final json = {
          ..._report(items, resumed: plan.resumed, resolved: resolved),
          'tokenWarnings': tokenNotes,
          'held': heldJson(held),
          'needsFlutter': needsFlutter.json,
          'lockfileWritten': !dryRun,
          'presetWarnings': presetNotes,
        };
        final lines = [
          if (plan.resumed) 'Resuming the interrupted update.',
          for (final note in presetNotes) 'Warning: $note.',
          for (final note in tokenNotes) 'Warning: $note.',
          for (final path in resolved) 'conflict resolved: $path',
          ...heldLines(held),
          ...needsFlutter.lines,
          for (final item in items) ..._itemLines(item),
          if (dryRun) 'Dry run: nothing was written.',
          if (!dryRun && _has(items, ConflictStrategy.sidecar))
            'For each conflict, copy what you keep from the .fliin-new file '
                'into the file, delete the .fliin-new file, then run fliin '
                'update again to finish the update.',
          if (!dryRun && _has(items, ConflictStrategy.markers))
            'Remove the <<<<<<< ||||||| ======= >>>>>>> markers from each '
                'conflicting file.',
        ];
        if (outcome.hasConflicts && !dryRun) {
          return emit(ExitCode.failure, json, lines);
        }
        return succeed(json, lines);
    }
  }

  /// 6 quand une version plus récente s'applique, sinon 3 quand seul le
  /// Flutter du projet en écarte une, sinon 0.
  int _available(
    List<ItemUpdate> items,
    UpdatePlan plan,
    ({List<Map<String, Object?>> json, List<String> lines}) needsFlutter,
  ) {
    final json = {
      'upToDate': items.isEmpty && plan.needsFlutter.isEmpty,
      'updates': [for (final item in items) item.toJson()..remove('files')],
      'held': heldJson(plan.held),
      'needsFlutter': needsFlutter.json,
    };
    final lines = [...heldLines(plan.held), ...needsFlutter.lines];
    if (items.isNotEmpty) {
      return emit(ExitCode.updateAvailable, json, [
        ...lines,
        for (final item in items) ..._itemLines(item),
        'Run fliin update to apply these updates.',
      ]);
    }
    if (plan.needsFlutter.isNotEmpty) {
      return emit(ExitCode.environment, json, lines);
    }
    return succeed(json, [...lines, 'Everything is up to date.']);
  }

  Map<String, Object?> _report(
    List<ItemUpdate> items, {
    required bool resumed,
    required List<String> resolved,
  }) => {
    'dryRun': _dryRun,
    'conflict': argResults!.option('conflict'),
    'resumed': resumed,
    'resolved': resolved,
    'items': [for (final item in items) item.toJson()],
  };

  bool _has(List<ItemUpdate> items, ConflictStrategy strategy) => items.any(
    (i) => i.files.any((f) => f is Conflict && f.strategy == strategy),
  );
}

List<Map<String, Object?>> heldJson(List<HeldItem> held) => [
  for (final h in held)
    {
      'ref': '${h.ref}',
      'from': h.from == null ? null : '${h.from}',
      'to': '${h.to}',
      'reason': h.reason,
    },
];

List<String> heldLines(List<HeldItem> held) => [
  for (final h in held)
    '${h.ref} ${h.from ?? '(new)'} → ${h.to} held back: ${h.reason}',
];

List<Map<String, Object?>> needsFlutterJson(List<NeedsFlutter> items) => [
  for (final n in items)
    {
      'ref': '${n.ref}',
      'kept': '${n.kept}',
      'to': '${n.to}',
      'flutter': '${n.flutter}',
    },
];

List<String> needsFlutterLines(List<NeedsFlutter> items, Project project) => [
  for (final n in items)
    '${n.ref} ${n.to} requires Flutter ${n.flutter}. The project has '
        '${project.flutter}, so ${n.ref} stays at ${n.kept}. '
        '${flutterRemedy(project.sdk)}',
];

List<String> _itemLines(ItemUpdate item) => [
  '${item.ref} ${item.from ?? '(new)'} → ${item.to}',
  for (final file in item.files)
    '  ${_label(file).padRight(16)} ${file.path}${_detail(file)}',
  for (final note in item.changelog) '  ${note.version}: ${note.value}',
  for (final note in item.breaking)
    '  breaking ${note.version}: ${_breaking(note.value)}',
];

String _label(FileUpdate file) => switch (file) {
  FastForward() => 'fast-forward',
  LocalOnly() => 'local only',
  Merged() => 'merged',
  Conflict() => 'conflict',
  AddedUpstream() => 'added',
  RemovedUpstream() => 'removed upstream',
  Regenerated() => 'regenerated',
};

String _detail(FileUpdate file) => switch (file) {
  Conflict(:final sidecar?) => ' (upstream version in $sidecar)',
  Conflict() => ' (markers in the file)',
  LocalOnly(:final note?) => ' ($note)',
  RemovedUpstream(:final locallyModified) =>
    ' (kept on disk${locallyModified ? ', modified locally' : ''}, no longer tracked)',
  Regenerated() => ' (from fliin.tokens.json)',
  _ => '',
};

String _breaking(BreakingChange change) => switch (change) {
  RemovedDeclaration(:final symbol) => '$symbol removed',
  ChangedSignature(:final symbol, :final before, :final after) =>
    '$symbol: $before becomes $after',
  RequiredParameterAdded(:final symbol, :final parameter) =>
    '$symbol: new required parameter $parameter',
  SemanticBreak(:final description) => description,
};

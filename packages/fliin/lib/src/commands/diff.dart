import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';

import '../install/lockfile_io.dart';
import '../install/registry_port.dart';
import '../update/report.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import '../update/journal.dart';
import '../update/updater.dart';
import 'exit_code.dart';
import 'project_command.dart';
import 'update.dart';

class DiffCommand extends ProjectCommand {
  DiffCommand(super.openRegistry, super.io) {
    argParser.addFlag(
      'local',
      negatable: false,
      help:
          'Shows local changes: the installed base against the project file. '
          'Needs no registry and no compatible Flutter.',
    );
  }

  @override
  String get name => 'diff';

  @override
  String get description =>
      'Shows, as a unified diff, what the latest published version would '
      'change in each file before fliin update (the installed base against '
      'the target version, added and removed files included). Exits with 6 '
      'when a newer version exists, like update --check. --local shows local '
      'changes.';

  @override
  String get invocation => 'fliin diff [<item>...] [--local]';

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
    for (final dependency in requested) {
      if (!lockfile.items.containsKey(dependency.ref)) {
        return fail(
          ExitCode.failure,
          describeNotInstalled(dependency.ref, lockfile.items.keys),
        );
      }
    }
    final project = await probe(dir);
    final updater = Updater(
      project: project,
      config: config,
      registry: await openProjectRegistry(config),
      lockfile: lockfile,
    );
    if (argResults!.flag('local')) {
      return _local(updater, [
        for (final dependency in requested) dependency.ref,
      ], lockfile);
    }

    requireFlutter(project);
    final UpdatePlan plan;
    final List<(ItemUpdate, List<FileSides>)> sides;
    try {
      switch (await updater.plan(requested, check: true)) {
        case PlanFailed(error: final FlutterTooOld error):
          return fail(
            ExitCode.environment,
            '${describeResolution(error)} ${flutterRemedy(project.sdk)}',
          );
        case PlanFailed(:final error):
          return fail(ExitCode.failure, describeResolution(error));
        case NotInstalled(:final ref):
          return fail(
            ExitCode.failure,
            describeNotInstalled(ref, lockfile.items.keys),
          );
        case JournalPending():
          throw StateError('plan(check: true) ignores the journal');
        case final UpdatePlan planned:
          plan = planned;
      }
      sides = await updater.upstreamSides(plan);
    } on RegistryFailure catch (e) {
      return fail(
        registryExitCode(e),
        '${e.message} fliin diff --local shows local changes without the '
        'registry.',
      );
    }
    final changing = {
      for (final (item, _) in sides) item.ref,
      for (final held in plan.held) held.ref,
      for (final needs in plan.needsFlutter) needs.ref,
    };
    final current = [
      for (final dependency in requested)
        if (!changing.contains(dependency.ref)) dependency.ref,
    ];
    final diffs = [
      for (final (item, files) in sides) (item: item, files: _diffs(files)),
    ];
    final json = {
      'upToDate': sides.isEmpty && plan.needsFlutter.isEmpty,
      'updates': [
        for (final (:item, :files) in diffs)
          {
            ...item.toJson(),
            'files': [for (final file in files) file.json],
          },
      ],
      'held': heldJson(plan.held),
      'needsFlutter': needsFlutterJson(plan.needsFlutter),
      'presetWarnings': updater.presetNotes,
    };
    final lines = [
      for (final note in updater.presetNotes) 'Warning: $note.',
      ...heldLines(plan.held),
      ...needsFlutterLines(plan.needsFlutter, project),
      for (final ref in current)
        '$ref ${lockfile.items[ref]!.version}: up to date',
      if (sides.isEmpty && current.isEmpty) 'Everything is up to date.',
      for (final (:item, :files) in diffs) ...[
        '${item.ref} ${item.from ?? '(new)'} → ${item.to}',
        for (final file in files) file.text,
      ],
      if (sides.isNotEmpty) 'Run fliin update to apply these changes.',
    ];
    final code = sides.isNotEmpty
        ? ExitCode.updateAvailable
        : plan.needsFlutter.isNotEmpty
        ? ExitCode.environment
        : ExitCode.ok;
    return emit(code, json, lines);
  }

  /// [refs] vide : tout ce qui est installé, et seuls les éléments retouchés
  /// sont nommés.
  Future<int> _local(
    Updater updater,
    List<ItemRef> refs,
    Lockfile lockfile,
  ) async {
    final journal = UpdateJournal.read(projectDir);
    final items = [
      for (final ref in refs.isEmpty ? lockfile.items.keys : refs)
        if (lockfile.items[ref]! case final locked)
          (
            ref: ref,
            version: locked.version,
            files: _diffs(await updater.localSides(ref)),
            sidecars: [
              for (final file in locked.files.values)
                if (file.conflicted case final marker?) marker.sidecarPath,
            ],
            interrupted: switch (journal?.targets[ref]) {
              final target? when target != locked.version => target,
              _ => null,
            },
          ),
    ];
    // Une mise à jour interrompue a pu écrire la version visée sans avancer
    // le lockfile : ses lignes passeraient pour des retouches.
    List<String> notes(
      ({
        ItemRef ref,
        Version version,
        List<({String text, Map<String, Object?> json})> files,
        List<String> sidecars,
        Version? interrupted,
      })
      item,
    ) => [
      for (final sidecar in item.sidecars) '  pending conflict: $sidecar',
      if (item.interrupted case final target?)
        '  interrupted update to $target. Run fliin update to finish it. '
            'The lines below may come from upstream.',
    ];
    final shown = [
      for (final item in items)
        if (item.files.isNotEmpty ||
            item.sidecars.isNotEmpty ||
            item.interrupted != null)
          item,
    ];
    return emit(
      ExitCode.ok,
      {
        'items': [
          for (final item in shown)
            {
              'ref': '${item.ref}',
              'version': '${item.version}',
              'files': [for (final file in item.files) file.json],
              'pendingConflicts': item.sidecars,
              'interruptedUpdate': item.interrupted == null
                  ? null
                  : '${item.interrupted}',
            },
        ],
        'presetWarnings': updater.presetNotes,
      },
      [
        for (final note in updater.presetNotes) 'Warning: $note.',
        for (final item in items)
          if (shown.contains(item)) ...[
            '${item.ref} ${item.version}: local changes',
            ...notes(item),
            for (final file in item.files) file.text,
          ] else if (refs.isNotEmpty)
            '${item.ref} ${item.version}: no local changes',
        if (refs.isEmpty && shown.isEmpty) 'No local changes.',
      ],
    );
  }

  /// Les fichiers qui diffèrent d'un côté à l'autre, avec leur diff unifié.
  static List<({String text, Map<String, Object?> json})> _diffs(
    List<FileSides> files,
  ) => [
    for (final file in files)
      if (unifiedDiff(file.before, file.after, path: file.path) case final diff
          when diff.isNotEmpty)
        (
          text: diff.trimRight(),
          json: {
            'path': file.path,
            'change': switch ((file.before, file.after)) {
              (null, _) => 'added',
              (_, null) => 'removed',
              _ => 'modified',
            },
            'diff': diff,
          },
        ),
  ];
}

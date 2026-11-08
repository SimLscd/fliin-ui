import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/lockfile_io.dart';
import '../install/removal.dart';
import '../install/status.dart';
import '../update/journal.dart';
import 'exit_code.dart';
import 'project_command.dart';

class RemoveCommand extends ProjectCommand {
  RemoveCommand(super.openRegistry, super.io) {
    argParser
      ..addFlag(
        'force',
        negatable: false,
        help: 'Also deletes locally modified files.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Shows what would be deleted, without writing anything.',
      );
  }

  @override
  String get name => 'remove';

  @override
  String get description =>
      'Deletes the files of installed items and their lockfile entries. '
      'Refuses if another item depends on them (exit code 7), or if a file '
      'is modified locally, unless --force.';

  @override
  String get invocation => 'fliin remove <item>...';

  bool get _dryRun => argResults!.flag('dry-run');

  @override
  bool get writesProject => !_dryRun;

  @override
  Future<int> execute() async {
    final dir = projectDir;
    final lockfile = readLockfile(dir);
    if (lockfile == null) {
      return fail(
        ExitCode.environment,
        '$lockfileName not found. Run fliin init.',
      );
    }
    // La reprise d'update réécrirait d'après son journal les fichiers et
    // l'entrée d'un élément retiré entre-temps.
    if (File(p.join(dir.path, UpdateJournal.path)).existsSync()) {
      return fail(
        ExitCode.failure,
        'An interrupted update is pending (${UpdateJournal.path}). Run fliin '
        'update to finish it, then fliin remove. Nothing was deleted.',
      );
    }
    final refs = {
      for (final dependency in parseRefs(argResults!.rest)) dependency.ref,
    }.toList();
    switch (planRemoval(
      dir,
      lockfile,
      refs,
      force: argResults!.flag('force'),
    )) {
      case NotInstalledItems(refs: final unknown):
        return fail(
          ExitCode.failure,
          [
            for (final ref in unknown)
              '$ref is not installed.'
                  '${didYouMean(ref, lockfile.items.keys)}',
          ].join('\n'),
          {
            'error': {
              'notInstalled': [for (final ref in unknown) '$ref'],
            },
          },
        );
      case RequiredBy(:final dependents, :final together):
        return fail(
          ExitCode.hasDependents,
          [
            for (final MapEntry(key: ref, value: users) in dependents.entries)
              '$ref is required by ${users.join(', ')}.',
            'Nothing was deleted. To remove them together, run '
                'fliin remove ${together.join(' ')}',
          ].join('\n'),
          {
            'error': {
              'dependents': {
                for (final MapEntry(key: ref, value: users)
                    in dependents.entries)
                  '$ref': [for (final user in users) '$user'],
              },
              'together': [for (final ref in together) '$ref'],
            },
          },
        );
      case LocallyModified(:final files):
        return fail(
          ExitCode.failure,
          [
            'These files are no longer the ones fliin installed. Nothing was '
                'deleted. --force deletes them with the rest:',
            for (final file in files)
              '  ${file.state.name.padRight(10)} ${file.path}  (${file.item})',
          ].join('\n'),
          {
            'error': {
              'modified': [
                for (final file in files)
                  {
                    'path': file.path,
                    'item': '${file.item}',
                    'state': file.state.name,
                  },
              ],
            },
          },
        );
      case final RemovalPlan plan:
        if (!_dryRun) applyRemoval(dir, lockfile, plan);
        return succeed(
          {
            'dryRun': _dryRun,
            'removed': [
              for (final MapEntry(key: ref, value: files) in plan.items.entries)
                {
                  'ref': '$ref',
                  'files': [
                    for (final file in files)
                      {
                        'path': file.path,
                        'state': file.state.name,
                        'sidecar': _sidecar(lockfile, file),
                      },
                  ],
                },
            ],
            'orphans': [for (final ref in plan.orphans) '$ref'],
          },
          [
            for (final MapEntry(key: ref, value: files)
                in plan.items.entries) ...[
              '$ref',
              for (final file in files) ...[
                '  ${file.path}'
                    '${file.state == InstalledState.intact ? '' : ' (${file.state.name})'}',
                if (_sidecar(lockfile, file) case final sidecar?)
                  '  $sidecar (pending upstream version)',
              ],
            ],
            if (plan.orphans.isNotEmpty)
              'No installed item requires '
                  '${plan.orphans.join(', ')} anymore. If you did not ask '
                  'for them yourself, run fliin remove ${plan.orphans.join(' ')}',
            if (_dryRun) 'Dry run: nothing was written.',
          ],
        );
    }
  }
}

/// Le `.fliin-new` d'un conflit en attente : supprimé avec le fichier.
String? _sidecar(Lockfile lockfile, FileStatus file) =>
    lockfile.items[file.item]?.files[file.path]?.conflicted?.sidecarPath;

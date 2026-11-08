import 'package:fliin_schema/fliin_schema.dart' show InstalledState;

import '../install/lockfile_io.dart';
import '../install/status.dart';
import '../license/license_store.dart';
import '../project/project_lock.dart';
import '../update/conflicts.dart';
import '../update/journal.dart';
import 'exit_code.dart';
import 'project_command.dart';

class StatusCommand extends ProjectCommand {
  StatusCommand(super.openRegistry, super.io, this.licenses) {
    argParser.addFlag(
      'files',
      negatable: false,
      help: 'One line per file instead of one per item.',
    );
  }

  final LicenseStore licenses;

  @override
  String get name => 'status';

  @override
  String get description =>
      'One line per installed item: its version, how many of its files are '
      'in each state other than intact (modified, deleted, pending, '
      'conflicted), its pending conflicts and any interrupted update. '
      '--files classifies each file, orphans included. A conflict whose '
      '.fliin-new file was deleted is resolved, and its base moves forward. '
      'Last, whether a Fliin Pro license key is active.';

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
    final settled = settleConflicts(dir, lockfile);
    if (settled.resolved.isNotEmpty) {
      final lock = ProjectLock.acquire(dir);
      try {
        writeLockfile(dir, settled.lockfile);
      } finally {
        lock.release();
      }
    }
    final status = projectStatus(dir, settled.lockfile);
    final license = licenses.read();
    final journal = UpdateJournal.read(dir);
    final items = [
      for (final ref
          in settled.lockfile.items.keys.toList()
            ..sort((a, b) => '$a'.compareTo('$b')))
        if (settled.lockfile.items[ref]! case final item)
          (
            ref: ref,
            version: item.version,
            states: {
              for (final state in InstalledState.values)
                if (state != InstalledState.intact)
                  if (status.files
                          .where((f) => f.item == ref && f.state == state)
                          .length
                      case final n when n > 0)
                    state: n,
            },
            sidecars: [
              for (final file in item.files.values)
                if (file.conflicted case final marker?) marker.sidecarPath,
            ],
            interrupted: switch (journal?.targets[ref]) {
              final target? when target != item.version => target,
              _ => null,
            },
          ),
    ];
    final width = items.fold(
      0,
      (w, item) => '${item.ref}'.length > w ? '${item.ref}'.length : w,
    );
    final touched =
        status.orphans.isNotEmpty ||
        items.any((i) => i.states.isNotEmpty || i.interrupted != null);
    return succeed(
      {
        'items': [
          for (final item in items)
            {
              'ref': '${item.ref}',
              'version': '${item.version}',
              'files': {
                for (final MapEntry(:key, :value) in item.states.entries)
                  key.name: value,
              },
              'pendingConflicts': item.sidecars,
              'interruptedUpdate': item.interrupted == null
                  ? null
                  : '${item.interrupted}',
            },
        ],
        'resolved': settled.resolved,
        'files': [
          for (final file in status.files)
            {
              'path': file.path,
              'item': '${file.item}',
              'state': file.state.name,
            },
        ],
        'orphans': status.orphans,
        'license': license == null
            ? {'active': false}
            : {
                'active': true,
                'key': license.hint,
                'origin': license.origin.name,
              },
      },
      [
        for (final path in settled.resolved)
          'conflict resolved, base moved forward: $path',
        if (argResults!.flag('files')) ...[
          for (final file in status.files)
            '${file.state.name.padRight(10)} ${file.path}  (${file.item})',
          for (final path in status.orphans) '${'orphan'.padRight(10)} $path',
        ] else ...[
          for (final item in items)
            [
              '${'${item.ref}'.padRight(width)} ${item.version}',
              if (item.states.isEmpty && item.interrupted == null) 'intact',
              for (final MapEntry(:key, :value) in item.states.entries)
                '$value ${key.name}',
              for (final sidecar in item.sidecars) 'pending conflict: $sidecar',
              if (item.interrupted case final target?)
                'interrupted update to $target. Run fliin update to finish '
                    'it.',
            ].join('  '),
          if (status.orphans.isNotEmpty)
            '${status.orphans.length} '
                '${status.orphans.length > 1 ? 'files' : 'file'} under the '
                'root that the lockfile does not know (orphan)',
          if (touched) 'Details per file: fliin status --files',
        ],
        switch (license) {
          null => 'Fliin Pro: no license key. Run fliin login to add one.',
          License(:final hint, origin: LicenseOrigin.environment) =>
            'Fliin Pro: license key $hint active (${LicenseStore.variable}).',
          License(:final hint, origin: LicenseOrigin.file) =>
            'Fliin Pro: license key $hint active (${licenses.path}).',
        },
      ],
    );
  }
}

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';

import '../install/lockfile_io.dart';
import '../install/registry_port.dart';
import '../install/status.dart';
import '../project/environment_failure.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import 'exit_code.dart';
import 'project_command.dart';
import 'view.dart';

class ListCommand extends ProjectCommand {
  ListCommand(super.openRegistry, super.io);

  @override
  String get name => 'list';

  @override
  String get description =>
      'Lists the installed items and their versions, with available updates '
      'and modified or deleted files. When the registry cannot be reached, '
      'says so and lists them anyway.';

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
    final files = [
      for (final MapEntry(key: ref, value: item) in lockfile.items.entries)
        for (final MapEntry(key: path, value: file) in item.files.entries)
          (path: path, item: ref, state: localState(file, onDisk(dir, path))),
    ];
    Map<ItemRef, Version?>? latest;
    String? unreachable;
    try {
      final entries = await fetchEntries(
        await openProjectRegistry(config),
      );
      final flutter = (await probe(dir)).flutter;
      latest = {
        for (final entry in entries) entry.ref: latestRelease(entry, flutter),
      };
    } on RegistryFailure catch (e) {
      // La liste vient du lockfile et du disque : un registre muet, expiré ou
      // illisible ne retire que la colonne des mises à jour.
      unreachable = e.message;
    } on EnvironmentFailure catch (e) {
      unreachable = e.message;
    }
    final refs = lockfile.items.keys.toList()
      ..sort((a, b) => '$a'.compareTo('$b'));
    final width = refs.fold(
      0,
      (w, ref) => '$ref'.length > w ? '$ref'.length : w,
    );
    final rows = [
      for (final ref in refs)
        (
          ref: ref,
          version: lockfile.items[ref]!.version,
          latest: latest?[ref],
          states: {
            for (final state in InstalledState.values)
              if (state != InstalledState.intact)
                if (files.where((f) => f.item == ref && f.state == state).length
                    case final n when n > 0)
                  state: n,
          },
        ),
    ];
    return succeed(
      {
        'registryReachable': unreachable == null,
        'items': [
          for (final row in rows)
            {
              'ref': '${row.ref}',
              'version': '${row.version}',
              'latest': row.latest == null ? null : '${row.latest}',
              'files': {
                for (final MapEntry(:key, :value) in row.states.entries)
                  key.name: value,
              },
            },
        ],
      },
      [
        for (final row in rows)
          [
            '${'${row.ref}'.padRight(width)} ${row.version}',
            if (row.latest case final newer? when newer > row.version)
              '→ $newer',
            for (final MapEntry(:key, :value) in row.states.entries)
              '$value ${key.name}',
          ].join('  '),
        if (unreachable != null) '$unreachable Updates were not checked.',
      ],
    );
  }
}

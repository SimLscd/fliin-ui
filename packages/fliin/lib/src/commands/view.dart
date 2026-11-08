import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../install/lockfile_io.dart';
import '../install/registry_port.dart';
import '../install/status.dart';
import '../install/targets.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import '../registry/public_api.dart';
import 'add.dart';
import 'exit_code.dart';
import 'project_command.dart';

class ViewCommand extends ProjectCommand {
  ViewCommand(super.openRegistry, super.io);

  @override
  String get name => 'view';

  @override
  List<String> get aliases => const ['info'];

  @override
  String get description =>
      'Describes an item, installed or not: versions, files, imports, '
      'public API, dependencies, snippets for the detected router and state '
      'management, changelog.';

  @override
  String get invocation => 'fliin view <item>';

  @override
  Future<int> execute() async {
    final rest = argResults!.rest;
    if (rest.length > 1) usageException('Expected a single item.');
    final requested = parseRefs(rest).single;
    if (!requested.constraint.isAny) {
      usageException('Expected a name without a version: ${rest.single}');
    }
    final ref = requested.ref;
    final dir = projectDir;
    final config = readFliinConfig(dir);
    if (config == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName not found. Run fliin init.',
      );
    }
    final locked = readLockfile(dir)?.items[ref];
    final project = await probe(dir);
    final Registry registry;
    final List<IndexEntry> entries;
    try {
      registry = await openProjectRegistry(config);
      entries = await fetchEntries(registry);
    } on RegistryFailure catch (e) {
      if (locked == null) rethrow;
      return _local(ref, locked, config, e.message);
    }
    final entry = entries.where((e) => e.ref == ref).firstOrNull;
    if (entry == null && locked != null) {
      return _local(ref, locked, config, 'The registry does not serve $ref.');
    }
    if (entry == null) {
      return fail(
        ExitCode.failure,
        describeResolution(ItemNotFound(ref), [for (final e in entries) e.ref]),
      );
    }
    final available = latestRelease(entry, project.flutter);
    final shown = locked?.version ?? available;
    if (shown == null) {
      return fail(
        ExitCode.failure,
        '$ref: no published version supports Flutter '
        '${project.flutter}.',
      );
    }
    final manifest = await registry.fetchManifest(ref, shown);
    final changelog = [
      for (final release
          in entry.versions.toList()
            ..sort((a, b) => a.version.compareTo(b.version)))
        if (release.version >= shown && release.version <= (available ?? shown))
          if ((release.version == shown
                      ? manifest
                      : await registry.fetchManifest(ref, release.version))
                  .changelog
              case final text?)
            (version: release.version, text: text),
    ];
    final files = [
      if (locked != null)
        for (final MapEntry(key: path, value: file) in locked.files.entries)
          (path: path, state: localState(file, onDisk(dir, path)))
      else
        for (final file in manifest.files)
          (path: projectPath(config.render, file.target), state: null),
    ];
    final imports = [
      for (final file in files)
        if (file.path.endsWith('.dart'))
          "import '${importUri(config.render, file.path)}';",
    ];
    final api = locked != null
        ? _localApi(files.map((file) => file.path))
        : [
            for (final line in await publishedApi(registry, manifest))
              applyRewrites(line, config.render),
          ];
    final docs = renderedDocs(manifest, config);
    return succeed(
      {
        'ref': '$ref',
        'type': manifest.type.wire,
        'title': manifest.title,
        'description': manifest.description,
        'installed': locked == null ? null : '${locked.version}',
        'available': available == null ? null : '$available',
        'registryDependencies': [
          for (final d in manifest.registryDependencies) '$d',
        ],
        'files': [
          for (final file in files)
            {'path': file.path, 'state': file.state?.name},
        ],
        'imports': imports,
        'api': api,
        'docs': docs,
        'snippets': snippetsJson(manifest, project, config),
        'changelog': [
          for (final note in changelog)
            {'version': '${note.version}', 'text': note.text},
        ],
      },
      [
        '$ref (${manifest.type.wire}): ${manifest.title}',
        '  ${manifest.description}',
        '  installed: ${locked?.version ?? 'no'}. available: '
            '${available ?? 'no version for Flutter ${project.flutter}'}',
        if (manifest.registryDependencies.isNotEmpty)
          '  dependencies: ${manifest.registryDependencies.join(', ')}',
        'Files:',
        for (final file in files)
          file.state == null
              ? '  ${file.path}'
              : '  ${file.state!.name.padRight(10)} ${file.path}',
        if (imports.isNotEmpty) ...[
          'Imports:',
          for (final i in imports) '  $i',
        ],
        if (api.isNotEmpty) ...[
          'API:',
          for (final line in summarizeApi(
            api,
            rest: 'fliin view $ref --json gives them all',
          ).split('\n'))
            '  $line',
        ],
        if (docs != null) ...[
          'Notes:',
          for (final line in docs.trim().split('\n'))
            line.isEmpty ? '' : '  $line',
        ],
        ...describeSnippets(manifest, project, config),
        if (changelog.isNotEmpty) ...[
          'Changelog:',
          for (final note in changelog) '  ${note.version}: ${note.text}',
        ],
      ],
    );
  }

  /// Ce que le lockfile et le disque disent d'un élément installé que le
  /// registre ne décrit pas : [reason] dit pourquoi le reste manque.
  int _local(
    ItemRef ref,
    LockedItem locked,
    FliinConfig config,
    String reason,
  ) {
    final files = [
      for (final MapEntry(key: path, value: file) in locked.files.entries)
        (path: path, state: localState(file, onDisk(projectDir, path))),
    ];
    final imports = [
      for (final file in files)
        if (file.path.endsWith('.dart'))
          "import '${importUri(config.render, file.path)}';",
    ];
    return succeed(
      {
        'ref': '$ref',
        'installed': '${locked.version}',
        'available': null,
        'registryDependencies': [
          for (final d in locked.registryDependencies) '$d',
        ],
        'files': [
          for (final file in files)
            {'path': file.path, 'state': file.state.name},
        ],
        'imports': imports,
        'api': _localApi(files.map((file) => file.path)),
        'unavailable': reason,
      },
      [
        '$ref: installed ${locked.version}',
        '  $reason Description, snippets and changelog are unavailable.',
        if (locked.registryDependencies.isNotEmpty)
          '  dependencies: ${locked.registryDependencies.join(', ')}',
        'Files:',
        for (final file in files)
          '  ${file.state.name.padRight(10)} ${file.path}',
        if (imports.isNotEmpty) ...[
          'Imports:',
          for (final i in imports) '  $i',
        ],
      ],
    );
  }

  /// Les signatures publiques des fichiers Dart installés tels qu'ils sont
  /// sur le disque : retouches et préfixe du projet compris.
  List<String> _localApi(Iterable<String> paths) => apiLines([
    for (final path in paths)
      if (path.endsWith('.dart'))
        if (File(p.join(projectDir.path, path)) case final file
            when file.existsSync())
          utf8.decode(file.readAsBytesSync(), allowMalformed: true),
  ]);
}

/// La plus haute version publiée qui supporte [flutter] : ce qu'un `add`
/// installerait sans autre contrainte.
Version? latestRelease(IndexEntry entry, Version flutter) => [
  for (final release in entry.versions)
    if (release.status is Published && release.flutter.allows(flutter))
      release.version,
].fold<Version?>(null, (best, v) => best == null || v > best ? v : best);

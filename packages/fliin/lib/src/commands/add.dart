import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../install/analyze.dart';
import '../install/installer.dart';
import '../install/lockfile_io.dart';
import '../install/registry_port.dart';
import '../install/status.dart';
import '../project/fliin_yaml.dart';
import '../project/project.dart';
import 'exit_code.dart';
import 'project_command.dart';

class AddCommand extends ProjectCommand {
  AddCommand(super.openRegistry, super.io) {
    argParser.addFlag(
      'accept-deps',
      negatable: false,
      help: 'Adds the pub dependencies the items require to pubspec.yaml.',
    );
    argParser.addFlag(
      'force',
      negatable: false,
      help:
          'Restores deleted files of an installed item and of its '
          'dependencies. A locally modified file stays as it is.',
    );
  }

  @override
  String get name => 'add';

  @override
  bool get writesProject => true;

  @override
  String get description =>
      'Installs items and the registry items they depend on.';

  @override
  String get invocation => 'fliin add <item>...';

  @override
  Future<int> execute() async {
    final roots = parseRefs(argResults!.rest);
    final dir = projectDir;
    final config = readFliinConfig(dir);
    if (config == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName not found. Run fliin init.',
      );
    }
    final project = await probe(dir);
    final registry = await openProjectRegistry(config);
    final lockfile = readLockfile(dir);
    final installer = Installer(
      project: project,
      config: config,
      registry: registry,
      lockfile: lockfile,
    );
    final InstallPlan plan;
    switch (await installer.plan(roots)) {
      case final ResolutionError error:
        return fail(
          ExitCode.failure,
          describeResolution(error, [
            for (final entry in await fetchEntries(registry)) entry.ref,
          ]),
        );
      case final InstallPlan resolved:
        plan = resolved;
    }
    final force = argResults!.flag('force');
    switch (await installer.apply(
      plan,
      acceptDeps: argResults!.flag('accept-deps'),
      restore: force,
    )) {
      case NeedsConfirmation(:final dependencies):
        return fail(ExitCode.confirmation, describeConfirmation(dependencies), {
          'installed': const <Object?>[],
          'needsConfirmation': [
            for (final d in dependencies)
              {
                'package': d.package,
                'constraint': '${d.constraint}',
                'requiredBy': '${d.requiredBy}',
              },
          ],
        });
      case AnalysisRegressed(:final errors):
        return fail(ExitCode.failure, describeRegression(errors), {
          'installed': const <Object?>[],
          'analyze': {
            'diagnostics': [for (final d in errors) diagnosticToJson(d)],
          },
        });
      case TargetsInTheWay(:final files):
        return fail(ExitCode.failure, describeInTheWay(files), {
          'installed': const <Object?>[],
          'inTheWay': [
            for (final f in files) {'path': f.path, 'state': f.state.name},
          ],
        });
      case Installed(:final items, :final kept):
        final restored = {
          for (final item in items)
            if (lockfile
                    ?.items[ItemRef(
                      item.ref.name,
                      namespace: item.ref.namespace,
                    )]
                    ?.version ==
                item.ref.version)
              item.ref,
        };
        final skipped = [
          for (final planned in plan.items)
            if (!items.any((item) => item.ref.name == planned.ref.name))
              planned,
        ];
        final requested = {for (final root in roots) root.ref};
        final skippedDependencies = skipped
            .where((planned) => !requested.contains(planned.ref))
            .length;
        final keptInDependencies = kept
            .where((file) => !requested.contains(file.item))
            .length;
        final verify = [
          for (final root in roots)
            if (items.any((item) => item.ref.name == root.ref.name))
              '${root.ref}',
        ];
        final next = [
          if (verify.isNotEmpty) 'fliin verify ${verify.join(' ')} --json',
        ];
        return succeed(
          {
            'installed': [
              for (final item in items)
                {
                  'ref': '${item.ref}',
                  'restored': restored.contains(item.ref),
                  'files': item.files,
                  'snippets': snippetsJson(item.manifest, project, config),
                  'docs': renderedDocs(item.manifest, config),
                },
            ],
            'alreadyInstalled': [
              for (final planned in skipped)
                '${planned.ref.at(planned.version)}',
            ],
            'kept': [
              for (final file in kept)
                {
                  'path': file.path,
                  'item': '${file.item}',
                  'state': file.state.name,
                },
            ],
            'needsConfirmation': const <Object?>[],
            'next': next,
          },
          [
            for (final item in items) ...[
              restored.contains(item.ref)
                  ? '${item.ref} (deleted files restored)'
                  : '${item.ref}',
              for (final path in item.files) '  $path',
              ...describeSnippets(item.manifest, project, config),
              if (renderedDocs(item.manifest, config) case final docs?)
                for (final line in docs.trim().split('\n'))
                  line.isEmpty ? '' : '  $line',
            ],
            for (final file in kept)
              if (requested.contains(file.item))
                file.state == InstalledState.conflicted
                    ? 'kept, in conflict: ${file.path} (${file.item}). '
                          'Resolve the pending update first (fliin status).'
                    : 'kept, ${file.state.name}: ${file.path} '
                          '(${file.item}). To get the installed version '
                          'back, delete it, then run '
                          'fliin add --force ${file.item}.',
            if (keptInDependencies > 0)
              '$keptInDependencies modified '
                  'file${keptInDependencies > 1 ? 's' : ''} in dependencies '
                  'kept as ${keptInDependencies > 1 ? 'they are' : 'it is'} '
                  '(fliin list)',
            for (final planned in skipped)
              if (requested.contains(planned.ref)) ...[
                '${planned.ref.at(planned.version)} (already installed)',
                if (!force)
                  if (_deleted(dir, lockfile!.items[planned.ref]!) case final n
                      when n > 0)
                    '  $n deleted file${n > 1 ? 's' : ''}. '
                        'Run fliin add --force ${planned.ref} to restore '
                        '${n > 1 ? 'them' : 'it'}.',
              ],
            if (skippedDependencies > 0)
              '$skippedDependencies '
                  '${skippedDependencies > 1 ? 'dependencies' : 'dependency'} '
                  'already installed',
            if (verify.isNotEmpty)
              'Next: fliin verify ${verify.join(' ')} renders the 16 '
                  'variants.',
          ],
        );
    }
  }
}

int _deleted(Directory dir, LockedItem item) => [
  for (final MapEntry(key: path, value: file) in item.files.entries)
    if (classify(file, onDisk(dir, path)) == InstalledState.deleted) path,
].length;

/// Les extraits pour le routeur et l'état détectés. Ils importent
/// `package:fliin_ui/` comme les fichiers du registre : la même réécriture
/// les rend justes pour le paquet, le `root` et le préfixe de `fliin.yaml`.
({String? route, String? state}) _snippets(
  ItemManifest manifest,
  Project project,
  FliinConfig config,
) => (
  route: switch (manifest.snippets.route[project.router.wire]) {
    final snippet? => applyRewrites(snippet, config.render),
    null => null,
  },
  state: switch (manifest.snippets.state[project.state.name]) {
    final snippet? => applyRewrites(snippet, config.render),
    null => null,
  },
);

/// La note d'usage de l'élément, aux noms du projet.
String? renderedDocs(ItemManifest manifest, FliinConfig config) =>
    switch (manifest.docs) {
      final docs? => applyRewrites(docs, config.render),
      null => null,
    };

Map<String, Object?> snippetsJson(
  ItemManifest manifest,
  Project project,
  FliinConfig config,
) {
  final (:route, :state) = _snippets(manifest, project, config);
  return {'route': route, 'state': state, 'screens': manifest.snippets.screens};
}

/// Les extraits tels que `add` et `view` les affichent.
List<String> describeSnippets(
  ItemManifest manifest,
  Project project,
  FliinConfig config,
) {
  final (:route, :state) = _snippets(manifest, project, config);
  return [
    if (route != null)
      ...describeSnippet('Route (${project.router.wire})', route),
    if (state != null)
      ...describeSnippet('State (${project.state.name})', state),
    if (manifest.snippets.screens case final screens when screens.isNotEmpty)
      describeSnippetScreens(screens),
  ];
}

/// Un extrait tel que `add` l'affiche : [label], puis chaque ligne de
/// [snippet] retirée de quatre, une ligne vide restant vide.
List<String> describeSnippet(String label, String snippet) => [
  '  $label:',
  for (final line in snippet.split('\n')) line.isEmpty ? '' : '    $line',
];

/// Les écrans auxquels les extraits mènent : `add` ne les installe
/// pas d'office (ce ne sont pas des dépendances de l'écran).
String describeSnippetScreens(List<String> screens) =>
    '  The snippets lead to ${screens.join(', ')}. '
    'Install them (fliin add ${screens.join(' ')}) and paste their snippets.';

String describeConfirmation(List<PubDependency> dependencies) => [
  'These pub dependencies must be added to pubspec.yaml. '
      'Run the command again with --accept-deps:',
  for (final d in dependencies)
    '  ${d.package} ${d.constraint} (${d.requiredBy})',
].join('\n');

String describeInTheWay(List<({String path, InstalledState state})> files) => [
  'Files already exist where the install would write. Nothing was '
      'written. Move the files fliin does not know (orphan). For an '
      'installed item you modified, fliin update <item> merges the new '
      'version with your changes:',
  for (final f in files) '  ${f.path} (${f.state.name})',
].join('\n');

String describeRegression(List<Diagnostic> errors) => [
  'The rendered files fail dart analyze. Nothing was written:',
  for (final d in errors) '  ${describeDiagnostic(d)}',
].join('\n');

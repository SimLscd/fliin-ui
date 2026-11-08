import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/installer.dart';
import '../install/lockfile_io.dart';
import '../project/agents.dart';
import '../project/fliin_yaml.dart';
import '../project/local_state.dart';
import '../project/project.dart';
import '../tokens/preset_notes.dart';
import '../tokens/project_tokens.dart';
import '../update/journal.dart';
import 'add.dart';
import 'exit_code.dart';
import 'project_command.dart';

class InitCommand extends ProjectCommand {
  InitCommand(super.openRegistry, super.io) {
    argParser
      ..addOption(
        'registry',
        help: 'The https:// or file:// URL of the @fliin registry.',
      )
      ..addMultiOption(
        'trusted-key',
        help: 'The registry’s Ed25519 public key (base64), with --registry.',
      )
      ..addOption(
        'root',
        defaultsTo: 'lib/ui/fliin',
        help: 'The folder for items.',
      )
      ..addOption('prefix', defaultsTo: 'Fl', help: 'The class prefix.')
      ..addFlag(
        'allow-dirty',
        negatable: false,
        help: 'Continues even if the git tree has uncommitted changes.',
      )
      ..addOption(
        'preset',
        valueHelp: 'code',
        help:
            'Applies this preset from the theme page to the installed tokens '
            '(like fliin theme --preset).',
      )
      ..addMultiOption(
        'agent',
        allowed: [for (final kind in AgentKind.values) kind.wire, 'none'],
        help:
            'Writes the MCP config of these clients and AGENTS.md. Without '
            'it, the clients the project shows signs of (CLAUDE.md, .cursor/, '
            '.codex/…). none: no agent file.',
      );
  }

  @override
  String get name => 'init';

  @override
  bool get writesProject => true;

  @override
  String get description =>
      'Installs core/ in this project and writes fliin.yaml and '
      'fliin.lock.json.';

  @override
  Future<int> execute() async {
    final dir = projectDir;
    final args = argResults!;
    final preset = switch (args.option('preset')) {
      null => null,
      final code => _decode(code),
    };
    final project = await probe(dir);
    if (project.flutter < minimumFlutter) {
      return fail(
        ExitCode.environment,
        'Flutter ${project.flutter}: fliin requires $minimumFlutter or later. '
        '${flutterRemedy(project.sdk)}',
      );
    }
    if (project.git == GitTree.dirty && !args.flag('allow-dirty')) {
      return fail(
        ExitCode.environment,
        'The git tree has uncommitted changes. Commit them first, or run '
        'the command again with --allow-dirty.',
      );
    }
    if (readFliinConfig(dir) != null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName already exists. The project is already initialized.',
      );
    }
    final render = _render(
      args.option('root')!,
      args.option('prefix')!,
      project.package,
    );
    final lockfile = readLockfile(dir);
    final requested = args.multiOption('agent');
    final noAgents = requested.contains('none');
    if (noAgents && requested.length > 1) {
      usageException('--agent none cannot be combined with another client.');
    }
    final detected = requested.isEmpty;
    final found = detected && !noAgents
        ? usableAgents(dir, detectAgents(dir))
        : (kept: const <AgentKind>[], skipped: const <SkippedAgent>[]);
    final kinds = noAgents
        ? const <AgentKind>[]
        : detected
        ? found.kept
        : [for (final text in requested) AgentKind.parse(text)];
    checkAgentConfigs(dir, kinds);
    final android = kinds.contains(AgentKind.androidStudio)
        ? androidStudioFor(dir, null)
        : null;
    final config = FliinConfig(
      render: render,
      registries: _registries(
        args.option('registry'),
        args.multiOption('trusted-key'),
      ),
      agents: agentConfigs(kinds, android?.mcp),
    );

    final installer = Installer(
      project: project,
      config: config,
      registry: await openRegistry(config.registries[Namespace.fliin]),
      lockfile: lockfile,
    );
    final List<String> installed;
    switch (await installer.plan([ItemDependency.parse('core')])) {
      case final ResolutionError error:
        return fail(ExitCode.failure, describeResolution(error));
      case final InstallPlan plan:
        switch (await installer.apply(plan, acceptDeps: false)) {
          case Installed(:final items):
            installed = [for (final item in items) ...item.files];
          case NeedsConfirmation(:final dependencies):
            return fail(
              ExitCode.confirmation,
              describeConfirmation(dependencies),
            );
          case AnalysisRegressed(:final errors):
            return fail(ExitCode.failure, describeRegression(errors));
          case TargetsInTheWay(:final files):
            return fail(
              ExitCode.failure,
              '${describeInTheWay(files)}\n'
              'Or pick another --root than ${render.root}.',
            );
        }
    }

    writeFliinConfig(dir, config);
    final written = [fliinYamlName, lockfileName, _gitignore(dir)];
    if (android case (:final mcp, stored: false)) {
      written.add(storeAndroidStudioToken(dir, mcp));
    }
    final agents = noAgents
        ? (written: const <String>[], androidStudio: null)
        : writeAgentConfigs(
            dir,
            kinds,
            executable: await fliinExecutable(Platform.environment),
            render: render,
            androidStudio: android?.mcp,
          );
    written.addAll(agents.written);
    // Le préréglage en dernier : s'il échoue, le reste de l'initialisation
    // est déjà écrit, et seul fliin theme --preset est à relancer.
    final List<String> themed;
    try {
      themed = preset == null ? const [] : _apply(dir, render, preset);
    } on InitPresetFailed catch (e) {
      return fail(ExitCode.failure, '$e');
    } on FormatterException catch (e) {
      return fail(
        ExitCode.failure,
        '${InitPresetFailed('le Dart généré ne se formate pas : ${e.message()}')}',
      );
    }
    if (preset != null) writeFliinConfig(dir, config.withPreset(preset));
    final snippet = _snippet(render.prefix);
    return succeed(
      {
        'project': project.toJson(),
        'config': config.withPreset(preset).toJson(),
        'installed': installed,
        'written': written,
        'snippet': snippet,
        'agents': {
          'configured': [for (final kind in kinds) kind.wire],
          'detected': detected,
          'skipped': skippedJson(found.skipped),
        },
        'next': ['fliin search "<intent>" --json', 'fliin add <item> --json'],
        if (preset != null)
          'preset': {
            'code': preset.encode(),
            ...preset.describe,
            'written': themed,
            'warnings': presetFontWarnings(preset),
            'pubspec': presetPubspecBlock(preset),
          },
        if (android case (mcp: (:final port, token: _), stored: _))
          'androidStudio': {
            'httpUrl': 'http://127.0.0.1:$port/mcp',
            'tokenFile': LocalState.path,
          }
        else
          'androidStudio': null,
      },
      [
        'Fliin initialized in ${render.root} (prefix ${render.prefix}).',
        for (final path in [...installed, ...written]) '  $path',
        if (preset != null) ...[
          '',
          ...presetLines(preset),
          for (final path in themed) '  $path rewritten',
          for (final warning in presetFontWarnings(preset))
            'Warning: $warning.',
          if (presetPubspecBlock(preset).isNotEmpty) presetPubspecBlock(preset),
        ],
        if (detected && kinds.isNotEmpty)
          'Agents detected and connected to the MCP server: '
              '${kinds.map((kind) => kind.wire).join(', ')}.',
        if (!noAgents && kinds.isEmpty)
          'AGENTS.md tells your agents how to use fliin. '
              'fliin agents --agent claude|cursor|gemini|codex|vscode also '
              'connects the MCP server.',
        '',
        'Paste this into the builder: of your MaterialApp or WidgetsApp:',
        '',
        snippet,
        '',
        'Next: fliin search "<intent>" to find an item, '
            'fliin add <item> to install it.',
        ...agentLines(agents, found.skipped),
      ],
    );
  }

  Preset _decode(String code) {
    try {
      return Preset.decode(code.trim());
    } on PresetError catch (e) {
      usageException('--preset: ${e.message}');
    }
  }

  /// [preset] appliqué aux jetons que `init` vient d'installer, qui sont
  /// ceux du registre : les chemins réécrits, relatifs au projet. Lève
  /// [InitPresetFailed] si le thème ne se calcule pas.
  List<String> _apply(Directory dir, RenderConfig render, Preset preset) {
    final tokens = p.join(dir.path, render.root, 'core', 'tokens');
    final source = File(p.join(tokens, tokensJsonName));
    final target = File(p.join(tokens, tokensDartName));
    try {
      final json = jsonDecode(source.readAsStringSync());
      switch (applyPreset(json, json, preset)) {
        case Unsatisfiable(:final failing):
          throw InitPresetFailed(
            '${failing.pair.foreground} on ${failing.pair.background}: '
            'no color meets the contrast threshold',
          );
        case ThemeSolved(:final patch) when patch.isEmpty:
          return const [];
        case ThemeSolved(:final patch):
          final patched = applyJsonPatch(json, patch);
          replaceFiles({
            source: tokensJsonText(patched),
            target: renderTokensDart(patched, prefix: render.prefix),
          });
          return [
            for (final file in [source, target])
              p.relative(file.path, from: dir.path),
          ];
      }
    } on TokenError catch (e) {
      throw InitPresetFailed('$e');
    } on JsonPatchError catch (e) {
      throw InitPresetFailed('$e');
    } on PresetError catch (e) {
      throw InitPresetFailed(e.message);
    } on FormatException catch (e) {
      throw InitPresetFailed('${p.basename(source.path)}: ${e.message}');
    }
  }

  RenderConfig _render(String root, String prefix, String package) {
    try {
      return RenderConfig(root: root, prefix: prefix, package: package);
    } on FormatException catch (e) {
      usageException('${e.message}: ${e.source}');
    }
  }

  Map<Namespace, RegistrySource> _registries(String? url, List<String> keys) {
    if (url == null) {
      if (keys.isNotEmpty) usageException('--trusted-key requires --registry.');
      return const {};
    }
    if (keys.isEmpty) {
      usageException('--registry requires at least one --trusted-key.');
    }
    try {
      return {
        Namespace.fliin: RegistrySource.fromJson({
          'url': url,
          'trustedKeys': keys,
        }),
      };
    } on ManifestError catch (e) {
      usageException('$e');
    }
  }

  String _snippet(String prefix) =>
      '  builder: (context, child) => ${prefix}Scope(\n'
      '    child: child ?? const SizedBox.shrink(),\n'
      '  ),';
}

const _ignored = [
  'test/.fliin/',
  'build/fliin/',
  LocalState.path,
  UpdateJournal.path,
];

String _gitignore(Directory dir) {
  final file = File(p.join(dir.path, '.gitignore'));
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final lines = existing.split('\n');
  final missing = [
    for (final line in _ignored)
      if (!lines.contains(line)) line,
  ];
  if (missing.isNotEmpty) {
    final separator = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
    file.writeAsStringSync(
      '$existing$separator# fliin\n${missing.join('\n')}\n',
    );
  }
  return '.gitignore';
}

/// Le préréglage de `init --preset` ne s'applique pas : `core` est installé,
/// ses jetons restent ceux du registre.
final class InitPresetFailed implements Exception {
  const InitPresetFailed(this.message);

  final String message;

  @override
  String toString() =>
      'Preset not applied. core is installed with the registry theme: '
      '$message. Run fliin theme --preset again.';
}

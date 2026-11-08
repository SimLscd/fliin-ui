import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../project/agents.dart';
import '../project/fliin_yaml.dart';
import '../project/local_state.dart';
import 'exit_code.dart';
import 'project_command.dart';

/// Branche le MCP de clients sur un projet déjà initialisé et réécrit le bloc
/// d'`AGENTS.md` : après `init` sans `--agent`, à l'arrivée d'un nouvel
/// agent, ou après une montée du CLI qui change ses consignes.
class AgentsCommand extends ProjectCommand {
  AgentsCommand(super.openRegistry, super.io) {
    argParser.addMultiOption(
      'agent',
      allowed: [for (final kind in AgentKind.values) kind.wire],
      help:
          'Adds these clients to the ones in fliin.yaml. Without it, the '
          'clients the project shows signs of (CLAUDE.md, .cursor/, .codex/…).',
    );
  }

  @override
  String get name => 'agents';

  @override
  bool get writesProject => true;

  @override
  String get description =>
      'Connects the fliin MCP server to the project’s agents and rewrites '
      'AGENTS.md.';

  @override
  Future<int> execute() async {
    final dir = projectDir;
    final config = readFliinConfig(dir);
    if (config == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName not found. Run fliin init.',
      );
    }
    final requested = [
      for (final text in argResults!.multiOption('agent'))
        AgentKind.parse(text),
    ];
    final configured = [for (final agent in config.agents) AgentKind.of(agent)];
    final named = {...configured, ...requested};
    final detected = requested.isEmpty
        ? usableAgents(dir, [
            for (final kind in detectAgents(dir))
              if (!named.contains(kind)) kind,
          ])
        : (kept: const <AgentKind>[], skipped: const <SkippedAgent>[]);
    final wanted = {...named, ...detected.kept};
    final kinds = [
      for (final kind in AgentKind.values)
        if (wanted.contains(kind)) kind,
    ];
    checkAgentConfigs(dir, kinds);
    final android = kinds.contains(AgentKind.androidStudio)
        ? androidStudioFor(dir, config)
        : null;
    final updated = FliinConfig(
      render: config.render,
      registries: config.registries,
      agents: agentConfigs(kinds, android?.mcp),
      preset: config.preset,
    );
    final files = writeAgentConfigs(
      dir,
      kinds,
      executable: await fliinExecutable(Platform.environment),
      render: config.render,
      androidStudio: android?.mcp,
    );
    writeFliinConfig(dir, updated);
    final written = [...files.written, fliinYamlName];
    if (android case (:final mcp, stored: false)) {
      written.add(storeAndroidStudioToken(dir, mcp));
    }
    final added = [
      for (final kind in kinds)
        if (!configured.contains(kind)) kind,
    ];
    return succeed(
      {
        'agents': [for (final kind in kinds) kind.wire],
        'added': [for (final kind in added) kind.wire],
        'written': written,
        'skipped': skippedJson(detected.skipped),
        'androidStudio': switch (android) {
          (mcp: (:final port, token: _), stored: _) => {
            'httpUrl': 'http://127.0.0.1:$port/mcp',
            'tokenFile': LocalState.path,
          },
          null => null,
        },
      },
      [
        if (kinds.isEmpty)
          'No agent detected. AGENTS.md rewritten. Name one with '
              '--agent claude|cursor|gemini|codex|vscode|android-studio.'
        else
          'fliin MCP server connected: '
              '${kinds.map((kind) => kind.wire).join(', ')}.',
        for (final path in files.written) '  $path',
        ...agentLines(files, detected.skipped),
        if (kinds.isNotEmpty)
          'Restart the agent, or reload its MCP servers, so it sees fliin.',
      ],
    );
  }
}

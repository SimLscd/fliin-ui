import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'invalid_project_file.dart';
import 'local_state.dart';
import 'pubspec.dart';

/// Les clients MCP que `init` et `agents` savent configurer.
enum AgentKind {
  claude('claude'),
  cursor('cursor'),
  gemini('gemini'),
  codex('codex'),
  vscode('vscode'),
  androidStudio('android-studio');

  const AgentKind(this.wire);

  final String wire;

  static AgentKind parse(String text) =>
      values.firstWhere((kind) => kind.wire == text);

  static AgentKind of(AgentConfig config) => switch (config) {
    ClaudeCodeAgent() => claude,
    CursorAgent() => cursor,
    GeminiCliAgent() => gemini,
    CodexAgent() => codex,
    VsCodeAgent() => vscode,
    AndroidStudioAgent() => androidStudio,
  };
}

typedef AndroidStudioMcp = ({int port, String token});

typedef AgentFiles = ({
  List<String> written,
  Map<String, Object?>? androidStudio,
});

/// L'exécutable que les clients MCP lanceront. `Platform.resolvedExecutable`
/// est la VM Dart sous `dart pub global`, d'où le PATH puis le défaut de pub.
Future<String> fliinExecutable(Map<String, String> environment) async {
  final which = await Process.run('which', ['fliin']);
  if (which.exitCode == 0) return (which.stdout as String).trim();
  return p.join(environment['HOME'] ?? '~', '.pub-cache', 'bin', 'fliin');
}

/// Les traces qu'un client laisse dans un projet où il sert déjà. Android
/// Studio n'en laisse aucune qui le distingue d'un projet Flutter ordinaire,
/// et `.vscode/` seul ne dit pas que Copilot y travaille.
const _traces = {
  AgentKind.claude: ['CLAUDE.md', '.claude', '.mcp.json'],
  AgentKind.cursor: ['.cursor', '.cursorrules'],
  AgentKind.gemini: ['GEMINI.md', '.gemini'],
  AgentKind.codex: ['.codex'],
  AgentKind.vscode: ['.vscode/mcp.json', '.github/copilot-instructions.md'],
};

/// Les clients dont [dir] porte déjà la trace, dans l'ordre de [AgentKind].
List<AgentKind> detectAgents(Directory dir) => [
  for (final MapEntry(key: kind, value: paths) in _traces.entries)
    if (paths.any(
      (path) =>
          FileSystemEntity.typeSync(p.join(dir.path, path)) !=
          FileSystemEntityType.notFound,
    ))
      kind,
];

/// La config de `fliin.yaml` pour [kinds] ; [androidStudio] porte le port.
List<AgentConfig> agentConfigs(
  List<AgentKind> kinds,
  AndroidStudioMcp? androidStudio,
) => [
  for (final kind in kinds)
    switch (kind) {
      AgentKind.claude => const ClaudeCodeAgent(),
      AgentKind.cursor => const CursorAgent(),
      AgentKind.gemini => const GeminiCliAgent(),
      AgentKind.codex => const CodexAgent(),
      AgentKind.vscode => const VsCodeAgent(),
      AgentKind.androidStudio => AndroidStudioAgent(port: androidStudio!.port),
    },
];

/// Un port éphémère et un jeton de 32 octets, tirés une fois par projet.
AndroidStudioMcp _newAndroidStudioMcp() {
  final random = Random.secure();
  return (
    port: 49152 + random.nextInt(65536 - 49152),
    token: base64Url
        .encode([for (var i = 0; i < 32; i++) random.nextInt(256)])
        .replaceAll('=', ''),
  );
}

/// Les fichiers JSON que [writeAgentConfigs] fusionnera, par client, et la
/// clé de leur table de serveurs.
const _jsonConfigs = {
  AgentKind.claude: (path: '.mcp.json', servers: 'mcpServers'),
  AgentKind.cursor: (path: '.cursor/mcp.json', servers: 'mcpServers'),
  AgentKind.gemini: (path: '.gemini/settings.json', servers: 'mcpServers'),
  AgentKind.vscode: (path: '.vscode/mcp.json', servers: 'servers'),
};

const _codexConfig = '.codex/config.toml';

/// Un client détecté que [usableAgents] écarte : le fichier à fusionner, et
/// pourquoi il ne se fusionne pas.
typedef SkippedAgent = ({AgentKind kind, String path, String reason});

/// Lève une [InvalidProjectFile] si un fichier que [writeAgentConfigs]
/// fusionnerait n'est pas lisible : à appeler avant la première écriture,
/// pour qu'une commande n'échoue pas à moitié faite.
void checkAgentConfigs(Directory dir, List<AgentKind> kinds) {
  for (final kind in kinds) {
    if (_jsonConfigs[kind] case final config?) {
      _readConfig(dir, config.path, config.servers);
    } else if (kind == AgentKind.codex) {
      _codexKept(dir);
    }
  }
}

/// [detected] sans les clients dont la config ne se fusionne pas : un
/// `.vscode/mcp.json` ou un `.gemini/settings.json` à commentaires, que leurs
/// clients acceptent et qu'une réécriture appauvrirait, ou une config de
/// Codex qui déclare `fliin` en ligne. Un client détecté n'a pas été demandé :
/// il ne fait pas échouer la commande, il est écarté et nommé.
({List<AgentKind> kept, List<SkippedAgent> skipped}) usableAgents(
  Directory dir,
  List<AgentKind> detected,
) {
  final kept = <AgentKind>[];
  final skipped = <SkippedAgent>[];
  for (final kind in detected) {
    try {
      checkAgentConfigs(dir, [kind]);
      kept.add(kind);
    } on InvalidProjectFile catch (e) {
      skipped.add((
        kind: kind,
        path: p.relative(e.path, from: dir.path),
        reason: e.reason,
      ));
    }
  }
  return (kept: kept, skipped: skipped);
}

/// Les lignes de texte qu'`init` et `agents` ajoutent après leurs fichiers.
List<String> agentLines(AgentFiles files, List<SkippedAgent> skipped) => [
  for (final agent in skipped)
    '${agent.kind.wire} detected, but ${agent.path} cannot be merged '
        '(${agent.reason}). Left as it is. Fix it, or add fliin by hand, '
        'then run fliin agents --agent ${agent.kind.wire}.',
  if (files.androidStudio case final block?) ...[
    '',
    'Android Studio: paste this block into the IDE’s mcp.json '
        '(Settings > Tools > Gemini > MCP):',
    const JsonEncoder.withIndent('  ').convert(block),
  ],
];

/// [skipped] pour une sortie JSON.
List<Map<String, Object?>> skippedJson(List<SkippedAgent> skipped) => [
  for (final agent in skipped)
    {'agent': agent.kind.wire, 'path': agent.path, 'reason': agent.reason},
];

/// Écrit la config MCP de chaque client de [kinds] et le bloc `AGENTS.md`,
/// que Claude Code lit par un import dans `CLAUDE.md` et Gemini CLI par son
/// `context.fileName`. Android Studio ne lit qu'une config globale à l'IDE :
/// son bloc est rendu, à coller.
AgentFiles writeAgentConfigs(
  Directory dir,
  List<AgentKind> kinds, {
  required String executable,
  required RenderConfig render,
  AndroidStudioMcp? androidStudio,
}) {
  final written = <String>[];
  Map<String, Object?>? block;
  for (final kind in kinds) {
    switch (kind) {
      case AgentKind.claude:
        written
          ..add(_mergeServer(dir, kind, _stdio(executable)))
          ..add(_importAgentsMd(dir));
      case AgentKind.cursor:
        written.add(_mergeServer(dir, kind, _stdio(executable)));
      case AgentKind.gemini:
        written.add(_mergeServer(dir, kind, _stdio(executable), _readAgentsMd));
      case AgentKind.vscode:
        written.add(
          _mergeServer(dir, kind, {'type': 'stdio', ..._stdio(executable)}),
        );
      case AgentKind.codex:
        written.add(_mergeCodex(dir, executable));
      case AgentKind.androidStudio:
        final mcp = androidStudio!;
        block = {
          'mcpServers': {
            'fliin': {
              'httpUrl': 'http://127.0.0.1:${mcp.port}/mcp',
              'headers': {'Authorization': 'Bearer ${mcp.token}'},
            },
          },
        };
    }
  }
  written.add(_writeAgentsMd(dir, render));
  return (written: written, androidStudio: block);
}

/// Le port et le jeton d'Android Studio pour [config] : ceux déjà tirés s'il
/// y en a, de nouveaux sinon. `stored` : le jeton est déjà dans
/// `.fliin/local.json` ; sinon [storeAndroidStudioToken] l'y écrira, une fois
/// la commande sûre d'aboutir.
({AndroidStudioMcp mcp, bool stored}) androidStudioFor(
  Directory dir,
  FliinConfig? config,
) {
  final port = config?.agents.whereType<AndroidStudioAgent>().firstOrNull?.port;
  final token = LocalState.read(dir).androidStudioToken;
  final fresh = _newAndroidStudioMcp();
  return (
    mcp: (port: port ?? fresh.port, token: token ?? fresh.token),
    stored: token != null,
  );
}

/// Écrit le jeton de [mcp] dans `.fliin/local.json` et rend ce chemin.
String storeAndroidStudioToken(Directory dir, AndroidStudioMcp mcp) {
  LocalState(androidStudioToken: mcp.token).write(dir);
  return LocalState.path;
}

Map<String, Object?> _stdio(String executable) => {
  'command': executable,
  'args': ['mcp'],
};

/// Le fichier [path] décodé, avec sa table [servers], tous deux vides si le
/// fichier n'existe pas.
(File, Map<String, Object?>, Map<String, Object?>) _readConfig(
  Directory dir,
  String path,
  String servers,
) {
  final file = File(p.join(dir.path, path));
  final root = switch (file.existsSync() ? readJson(file) : null) {
    null => <String, Object?>{},
    final Map<String, Object?> root => root,
    _ => throw InvalidProjectFile(file.path, 'expected a JSON object'),
  };
  final table = switch (root[servers]) {
    null => <String, Object?>{},
    final Map<String, Object?> table => table,
    _ => throw InvalidProjectFile(file.path, '$servers must be an object'),
  };
  return (file, root, table);
}

String _mergeServer(
  Directory dir,
  AgentKind kind,
  Map<String, Object?> server, [
  void Function(Map<String, Object?> root)? also,
]) {
  final config = _jsonConfigs[kind]!;
  final (file, root, servers) = _readConfig(dir, config.path, config.servers);
  servers['fliin'] = server;
  root[config.servers] = servers;
  also?.call(root);
  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(root)}\n',
    );
  return config.path;
}

/// Gemini CLI ne lit que `GEMINI.md` par défaut ; `context.fileName` le
/// remplace, d'où `GEMINI.md` gardé à côté d'`AGENTS.md`.
void _readAgentsMd(Map<String, Object?> root) {
  final context = switch (root['context']) {
    final Map<String, Object?> context => context,
    _ => <String, Object?>{},
  };
  final names = switch (context['fileName']) {
    final String name => [name],
    final List<Object?> names => [for (final name in names) '$name'],
    _ => ['GEMINI.md'],
  };
  if (!names.contains('AGENTS.md')) names.insert(0, 'AGENTS.md');
  context['fileName'] = names;
  root['context'] = context;
}

/// Claude Code lit `CLAUDE.md`, pas `AGENTS.md` : une ligne `@AGENTS.md` l'y
/// importe.
String _importAgentsMd(Directory dir) {
  final file = File(p.join(dir.path, 'CLAUDE.md'));
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  if (existing.split('\n').any((line) => line.trim() == '@AGENTS.md')) {
    return 'CLAUDE.md';
  }
  final separator = existing.isEmpty
      ? ''
      : existing.endsWith('\n')
      ? '\n'
      : '\n\n';
  file.writeAsStringSync('$existing$separator@AGENTS.md\n');
  return 'CLAUDE.md';
}

/// Remplace la table `[mcp_servers.fliin]` de la config de Codex, et ses
/// sous-tables, sans toucher au reste du fichier.
String _mergeCodex(Directory dir, String executable) {
  final kept = _codexKept(dir);
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  File(p.join(dir.path, _codexConfig))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      [
        ...kept,
        if (kept.isNotEmpty) '',
        '[mcp_servers.fliin]',
        'command = ${jsonEncode(executable)}',
        'args = ["mcp"]',
        '',
      ].join('\n'),
    );
  return _codexConfig;
}

final _tomlHeader = RegExp(r'^\s*\[\[?([^\[\]]*)\]\]?\s*(#.*)?$');
final _tomlKey = RegExp(
  r'''^\s*((?:[A-Za-z0-9_-]+|"[^"]*"|'[^']*')(?:\s*\.\s*(?:[A-Za-z0-9_-]+|"[^"]*"|'[^']*'))*)\s*=''',
);
final _tomlSegment = RegExp(
  r'[A-Za-z0-9_-]+|"([^"]*)"|'
  r"'([^']*)'",
);
final _tomlString = RegExp(
  r'"(?:[^"\\]|\\.)*"|'
  r"'[^']*'",
);

/// Les lignes de la config de Codex hors de la table `[mcp_servers.fliin]`
/// et de ses sous-tables. Sans analyseur TOML : les en-têtes sont lus hors
/// des tableaux sur plusieurs lignes. Lève une [InvalidProjectFile] si
/// `fliin`, ou `mcp_servers` entier, est défini autrement, en ligne ou par
/// clés pointées : la table ajoutée en ferait une seconde définition, que
/// Codex refuse au chargement.
List<String> _codexKept(Directory dir) {
  final file = File(p.join(dir.path, _codexConfig));
  if (!file.existsSync()) return [];
  final kept = <String>[];
  var table = '';
  var depth = 0;
  for (final line in file.readAsLinesSync()) {
    final code = line.replaceAll(_tomlString, '""').split('#').first;
    if (depth == 0) {
      if (_tomlHeader.firstMatch(line) case final header?) {
        table = _tomlPath(header[1]!);
      } else if (_tomlKey.firstMatch(line) case final key?) {
        final path = [
          if (table.isNotEmpty) table,
          _tomlPath(key[1]!),
        ].join('.');
        if (!_inFliin(table) && (path == 'mcp_servers' || _inFliin(path))) {
          throw InvalidProjectFile(
            file.path,
            '$path is defined inline or with dotted keys. fliin only merges '
            'a [mcp_servers.fliin] table.',
          );
        }
      }
    }
    if (!_inFliin(table)) kept.add(line);
    depth +=
        RegExp(r'[\[{]').allMatches(code).length -
        RegExp(r'[\]}]').allMatches(code).length;
    if (depth < 0) depth = 0;
  }
  return kept;
}

bool _inFliin(String path) =>
    path == 'mcp_servers.fliin' || path.startsWith('mcp_servers.fliin.');

/// `mcp_servers . "fliin"` → `mcp_servers.fliin`.
String _tomlPath(String dotted) => [
  for (final segment in _tomlSegment.allMatches(dotted))
    segment[1] ?? segment[2] ?? segment[0]!,
].join('.');

const _start = '<!-- fliin:start -->';
const _end = '<!-- fliin:end -->';

String _writeAgentsMd(Directory dir, RenderConfig render) {
  final file = File(p.join(dir.path, 'AGENTS.md'));
  final block = '$_start\n${agentsMdBlock(render)}\n$_end';
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final start = existing.indexOf(_start);
  final end = existing.indexOf(_end);
  final text = start >= 0 && end > start
      ? existing.replaceRange(start, end + _end.length, block)
      : '${existing.isEmpty ? '' : '$existing\n'}$block\n';
  file.writeAsStringSync(text);
  return 'AGENTS.md';
}

/// Ce que l'agent du projet doit savoir de Fliin, entre les marqueurs
/// d'`AGENTS.md`.
String agentsMdBlock(RenderConfig render) {
  final root = render.root;
  final prefix = render.prefix;
  return '''
## Fliin

Flutter components and screens installed by copy-paste under `$root/` (prefix `$prefix`). They are project files: edit them freely, and `fliin update` will merge the published version with your changes. Do not edit `fliin.lock.json` by hand: `fliin status` sums up each item (`--files`: each file), and `fliin list` lists the installed items and their updates.

Before you write a widget:
- `fliin list --json` tells what is already installed. Reuse it rather than writing another one.
- Otherwise, `fliin search "<intent in three words or more>" --json` searches the registry (full screens, blocks, components). Results include the public signatures (`apiSummary`) and the install command (`install`).

Working loop:
1. Find the item (above). With the `fliin` MCP server connected, `request_selection` lets the human pick among the candidates on a local page with previews. Read the state again with `selectionHandle` until it is `chosen` or `declined`. `previewUrl` is `null` outside the MCP server.
2. `fliin add <item> --json` installs it with its dependencies. Exit code 4: run it again with `--accept-deps`. The output gives the files, the snippets to paste for the project's router and state management, and `next`: the commands to run next. `fliin view <item> --json` gives them again.
3. `fliin verify <item> --json` renders 16 variants (iOS and Android, light and dark, text at 1× and 2×, LTR and RTL). Read `build/fliin/verify/<item>/overview.png`, then `report.json`, fix, and run it again until exit code 0. After a change under `$root/`, `fliin verify --changed --json` renders what it touches.

Writing under `$root/`:
- Import only `package:flutter/widgets.dart` (never material or cupertino) and neighboring files.
- No literal color, size, radius or duration: read the theme with `${prefix}Scope.of(context)` (`.colors.accent`, `.colors.onSurface`, `.space.md`, `.shape`, `.typography`, `.shadows`).
- Directional types only: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start`.

Theme: `fliin theme --primary "#RRGGBB"` adjusts the accent and the neutrals until they meet the contrast thresholds. `fliin theme --preset <code>` applies a preset from the website. Never edit `core/tokens/tokens.g.dart` by hand: `fliin tokens` generates it from `core/tokens/fliin.tokens.json`.

Updating: `fliin diff <item>` shows, as a unified diff, what the published version would change (exit code 6: a newer version exists, like `fliin update --check`). `fliin diff --local` shows local changes, without the registry. Then `fliin update <item> --json` merges. Exit code 1 with a `.fliin-new` file: copy what you keep, delete the `.fliin-new` file, run it again. Exit code 3: the environment, often the Flutter on the PATH (the message says which one and what is required), never the project.

Files deleted by mistake: `fliin add --force <item>` restores them without touching a modified file. To uninstall: `fliin remove <item>`. Exit code 7: other items depend on it (the output gives the command that removes them together). Exit code 1 on a modified file: `--force` deletes it too.

`fliin agents` rewrites this block. It also connects the MCP server of another client (`--agent claude|cursor|gemini|codex|vscode|android-studio`).''';
}

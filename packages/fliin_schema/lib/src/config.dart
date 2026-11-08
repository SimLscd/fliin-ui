import 'dart:convert';

import 'canonical_json.dart';
import 'item_ref.dart';
import 'json_node.dart';
import 'manifest_error.dart';
import 'sha256.dart';
import 'theme/preset.dart';

/// Les champs de `fliin.yaml` dont dépend `base` (règle 3) : ils rendent un
/// fichier brut dans le projet, et eux seuls entrent dans [configHash].
final class RenderConfig {
  /// Lève une [FormatException] si un champ est invalide.
  RenderConfig({
    required String root,
    required String prefix,
    required String package,
  }) : root = _root(root),
       prefix = _prefix(prefix),
       package = _package(package);

  factory RenderConfig.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return RenderConfig(
      root: node['root'].parse(_root),
      prefix: node['prefix'].parse(_prefix),
      package: node['package'].parse(_package),
    );
  }

  /// Relatif au projet et sous `lib/` : `lib/ui/fliin`.
  final String root;

  /// Remplace `Fl` devant une majuscule : `Ac` donne `AcButton`.
  final String prefix;
  final String package;

  /// [root] sans `lib/`, tel qu'il s'écrit dans un URI `package:`.
  String get importRoot => root.substring('lib/'.length);

  Sha256 get configHash => Sha256.ofString(canonicalJson(toJson()));

  Map<String, Object?> toJson() => {
    'root': root,
    'prefix': prefix,
    'package': package,
  };

  static String _root(String text) => _check(
    text,
    RegExp(r'^lib(/[a-z0-9_]+)+$'),
    'expected a lowercase folder under lib/',
  );

  static String _prefix(String text) => _check(
    text,
    RegExp(r'^[A-Z][A-Za-z0-9]*$'),
    'expected a prefix starting with an uppercase letter',
  );

  static String _package(String text) => _check(
    text,
    RegExp(r'^[a-z_][a-z0-9_]*$'),
    'expected a Dart package name',
  );

  static String _check(String text, RegExp pattern, String message) =>
      pattern.hasMatch(text) ? text : throw FormatException(message, text);
}

enum RegistryAuth { none, header, licenseKey }

final class RegistrySource {
  RegistrySource({
    required this.url,
    required this.trustedKeys,
    this.auth = RegistryAuth.none,
  });

  factory RegistrySource.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    final keys = node['trustedKeys'];
    if (keys.items.isEmpty) {
      throw InvalidValue(keys.path, 'expected at least one trusted key');
    }
    return RegistrySource(
      url: node['url'].parse(parseUrl),
      trustedKeys: [for (final key in keys.items) key.parse(_publicKey)],
      auth: node['auth']
          .orElse(RegistryAuth.none.name)
          .oneOf(RegistryAuth.values),
    );
  }

  /// `https://`, `file://`, ou `http://` sur la boucle locale (ADR 0011),
  /// toujours terminée par `/` pour que les chemins de `DistLayout` se
  /// résolvent dessous et non à côté.
  static Uri parseUrl(String text) {
    final uri = Uri.parse(text);
    if (uri.isScheme('http') && !isLoopbackHost(uri.host)) {
      throw FormatException(
        'plain http:// is refused outside localhost (use https://)',
        text,
      );
    }
    if (!(uri.isScheme('https') && uri.host.isNotEmpty ||
        uri.isScheme('http') ||
        uri.isScheme('file'))) {
      throw FormatException('expected an https:// or file:// URL', text);
    }
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }

  final Uri url;

  /// Clés publiques Ed25519 en base64, fixées par l'utilisateur.
  final List<String> trustedKeys;
  final RegistryAuth auth;

  Map<String, Object?> toJson() => {
    'url': '$url',
    'trustedKeys': trustedKeys,
    'auth': auth.name,
  };

  static String _publicKey(String text) => base64Decode(text).length == 32
      ? text
      : throw FormatException('expected a 32-byte Ed25519 public key', text);
}

/// Un client MCP configuré par `fliin init` ou `fliin agents`, rangé sous
/// `agents`.
sealed class AgentConfig {
  const AgentConfig();

  String get key;

  Map<String, Object?> toJson() => const {};
}

final class ClaudeCodeAgent extends AgentConfig {
  const ClaudeCodeAgent();

  @override
  String get key => 'claudeCode';
}

final class CursorAgent extends AgentConfig {
  const CursorAgent();

  @override
  String get key => 'cursor';
}

final class GeminiCliAgent extends AgentConfig {
  const GeminiCliAgent();

  @override
  String get key => 'geminiCli';
}

final class CodexAgent extends AgentConfig {
  const CodexAgent();

  @override
  String get key => 'codex';
}

/// GitHub Copilot dans VS Code.
final class VsCodeAgent extends AgentConfig {
  const VsCodeAgent();

  @override
  String get key => 'vscode';
}

/// Android Studio ne parle MCP qu'en HTTP : un port par projet. Le jeton
/// porteur n'est jamais ici, `fliin.yaml` étant versionné ; il vit dans
/// `.fliin/local.json`.
final class AndroidStudioAgent extends AgentConfig {
  const AndroidStudioAgent({required this.port});

  final int port;

  @override
  String get key => 'androidStudio';

  @override
  Map<String, Object?> toJson() => {'port': port};
}

/// `fliin.yaml`, que l'appelant a déjà décodé en Map.
final class FliinConfig {
  const FliinConfig({
    required this.render,
    required this.registries,
    required this.agents,
    this.preset,
    this.retiredPreset,
  });

  factory FliinConfig.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return FliinConfig(
      render: node.read(RenderConfig.fromJson),
      registries: {
        for (final MapEntry(:key, :value)
            in node['registries'].orElse(const {}).fields.entries)
          JsonNode(key, value.path).parse(Namespace.parse): value.read(
            RegistrySource.fromJson,
          ),
      },
      agents: [
        for (final MapEntry(:key, :value)
            in node['agents'].orElse(const {}).fields.entries)
          _agent(key, value),
      ],
      preset: switch (node['theme'].orElse(const {})['preset']) {
        final preset when preset.isAbsent => null,
        final preset when isRetiredPresetCode(preset.string) => null,
        final preset => _preset(preset),
      },
      retiredPreset: switch (node['theme'].orElse(const {})['preset']) {
        final preset
            when !preset.isAbsent && isRetiredPresetCode(preset.string) =>
          preset.string,
        _ => null,
      },
    );
  }

  final RenderConfig render;
  final Map<Namespace, RegistrySource> registries;
  final List<AgentConfig> agents;

  /// Le préréglage que `fliin theme --preset` ou `init --preset` a appliqué
  /// (`theme: preset:`) : `fliin update` le réapplique aux jetons de la
  /// version montée avant de fusionner (ADR 0016 §5.1).
  final Preset? preset;

  /// Un code de la version `a` que `fliin.yaml` garde d'avant `core` 0.2.0 :
  /// il ne se lit plus, et le refuser au chargement bloquerait toutes les
  /// commandes, `theme --preset` compris, qui le remplacerait. Il reste dans
  /// le fichier jusqu'à ce qu'un préréglage le remplace ; `update` et `theme`
  /// le signalent.
  final String? retiredPreset;

  /// Le même fichier, avec [preset] ; nul l'efface.
  FliinConfig withPreset(Preset? preset) => FliinConfig(
    render: render,
    registries: registries,
    agents: agents,
    preset: preset,
  );

  Map<String, Object?> toJson() => {
    ...render.toJson(),
    'registries': {
      for (final MapEntry(:key, :value) in registries.entries)
        key.value: value.toJson(),
    },
    'agents': {for (final agent in agents) agent.key: agent.toJson()},
    if (preset case final preset?)
      'theme': {'preset': preset.encode()}
    else if (retiredPreset case final code?)
      'theme': {'preset': code},
  };

  static Preset _preset(JsonNode node) {
    try {
      return Preset.decode(node.string);
    } on PresetError catch (e) {
      throw InvalidValue(node.path, e.message);
    }
  }

  static int _port(JsonNode node) => switch (node.integer) {
    final port when port >= 1 && port <= 65535 => port,
    _ => throw InvalidValue(
      node.path,
      'expected a TCP port between 1 and 65535',
    ),
  };

  static AgentConfig _agent(String key, JsonNode node) => switch (key) {
    'claudeCode' => const ClaudeCodeAgent(),
    'cursor' => const CursorAgent(),
    'geminiCli' => const GeminiCliAgent(),
    'codex' => const CodexAgent(),
    'vscode' => const VsCodeAgent(),
    'androidStudio' => AndroidStudioAgent(port: _port(node['port'])),
    _ => throw UnknownValue(node.path, key, [
      'claudeCode',
      'cursor',
      'geminiCli',
      'codex',
      'vscode',
      'androidStudio',
    ]),
  };
}

/// `localhost`, `127.0.0.0/8` ou `::1` : le seul endroit où un registre peut
/// être servi en clair (ADR 0011).
bool isLoopbackHost(String host) =>
    host == 'localhost' ||
    host == '::1' ||
    RegExp(r'^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);

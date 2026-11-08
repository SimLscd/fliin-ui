import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/registry_port.dart';
import '../install/selected_registry.dart';
import '../mcp/local/gates.dart';
import '../mcp/local/index_source.dart';
import '../mcp/server.dart';
import '../mcp/transports.dart';
import '../project/environment_failure.dart';
import '../project/fliin_yaml.dart';
import '../project/invalid_project_file.dart';
import '../project/local_state.dart';
import 'exit_code.dart';
import 'project_command.dart';

class McpCommand extends Command<int> {
  McpCommand(this.openRegistry, this.io) {
    argParser
      ..addFlag(
        'http',
        negatable: false,
        help:
            'Streamable HTTP on 127.0.0.1 with the token from ${LocalState.path}, for Android Studio (default: stdio).',
      )
      ..addOption(
        'port',
        help:
            'The HTTP port (default: agents.androidStudio.port in fliin.yaml).',
      )
      ..addOption(
        'registry',
        help: 'An https:// or file:// URL to use instead of the registry in fliin.yaml.',
      )
      ..addMultiOption(
        'trusted-key',
        help: 'The registry’s Ed25519 public key (base64), with --registry.',
      );
  }

  final OpenRegistry openRegistry;
  final CliIo io;

  @override
  String get name => 'mcp';

  @override
  String get description =>
      'Serves search_items, get_item and request_selection to agents (MCP), over stdio or local HTTP.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final dir = Directory(
      p.normalize(p.absolute(globalResults?.option('directory') ?? '.')),
    );
    final FliinConfig? config;
    final String? localToken;
    try {
      config = readFliinConfig(dir);
      localToken = LocalState.read(dir).androidStudioToken;
    } on InvalidProjectFile catch (e) {
      return _fail(ExitCode.failure, '$e');
    }
    final Registry registry;
    try {
      // Le jeu d'icônes du projet : get_item donne le fichier qu'add
      // installerait.
      registry = SelectedRegistry(
        await openRegistry(
          _source(args.option('registry'), args.multiOption('trusted-key')) ??
              config?.registries[Namespace.fliin],
        ),
        config?.preset?.icons.variant,
      );
    } on RegistryFailure catch (e) {
      return _fail(ExitCode.environment, e.message);
    } on EnvironmentFailure catch (e) {
      return _fail(ExitCode.environment, e.message);
    }
    final server = FliinMcpServer(
      index: LocalIndexSource(registry),
      registry: registry,
      entitlement: RegistryEntitlement(registry),
    );
    if (!args.flag('http')) {
      await serveStdio(server);
      return ExitCode.ok.code;
    }

    final port =
        _port(args.option('port')) ??
        config?.agents.whereType<AndroidStudioAgent>().firstOrNull?.port;
    if (port == null) {
      usageException(
        '--port is required when $fliinYamlName has no agents.androidStudio.port.',
      );
    }
    final token = localToken;
    if (token == null) {
      return _fail(
        ExitCode.environment,
        'No token in ${LocalState.path}. Run fliin agents --agent android-studio.',
      );
    }
    final http = await serveHttp(server, port: port, token: token);
    io.err.writeln('fliin mcp: http://127.0.0.1:${http.boundPort}/mcp');
    await _terminated();
    await http.stop();
    await server.close();
    return ExitCode.ok.code;
  }

  int _fail(ExitCode code, String message) {
    io.err.writeln(message);
    return code.code;
  }

  RegistrySource? _source(String? url, List<String> keys) {
    if (url == null) {
      if (keys.isNotEmpty) usageException('--trusted-key requires --registry.');
      return null;
    }
    if (keys.isEmpty) {
      usageException('--registry requires at least one --trusted-key.');
    }
    try {
      return RegistrySource.fromJson({'url': url, 'trustedKeys': keys});
    } on ManifestError catch (e) {
      usageException('$e');
    }
  }

  int? _port(String? text) {
    if (text == null) return null;
    final port = int.tryParse(text);
    if (port == null || port < 1 || port > 65535) {
      usageException('--port expects a TCP port between 1 and 65535: $text');
    }
    return port;
  }

  /// Un abonnement à un signal garde la VM en vie : les deux sont annulés
  /// dès que l'un se déclenche, sinon le processus ne sortirait jamais.
  static Future<void> _terminated() {
    final fired = Completer<void>();
    final subscriptions = [
      for (final signal in [
        ProcessSignal.sigint,
        if (!Platform.isWindows) ProcessSignal.sigterm,
      ])
        signal.watch().listen((_) {
          if (!fired.isCompleted) fired.complete();
        }),
    ];
    return fired.future.whenComplete(() {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }
}

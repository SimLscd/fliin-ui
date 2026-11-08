/// Point d'entrée du CLI. `run` retourne le code de sortie, sans appeler `exit`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import 'src/commands/project_command.dart';
import 'src/commands/registry.dart';
import 'src/install/client_registry.dart';
import 'src/install/registry_port.dart';
import 'src/license/license_store.dart';
import 'src/registry/official.dart';

export 'src/commands/project_command.dart' show CliIo;
export 'src/install/registry_port.dart';
export 'src/license/license_store.dart' show License, LicenseStore;
export 'src/registry/official.dart';

/// [official] et [licenses] remplacent, pour les tests, le registre
/// officiel et la clé de licence de l'utilisateur ; [openRegistry], tout
/// accès au registre.
Future<int> run(
  List<String> args, {
  OpenRegistry? openRegistry,
  CliIo? io,
  OfficialRegistry? official,
  LicenseStore? licenses,
}) async {
  final streams = io ?? (out: stdout, err: stderr);
  final registry = official ?? OfficialRegistry.fliin;
  final store = licenses ?? LicenseStore();
  final runner =
      CommandRunner<int>('fliin', 'Copy-paste Flutter components and screens.')
        ..argParser.addOption(
          'directory',
          abbr: 'C',
          help: 'The Flutter project to work on (default: the current directory).',
        );
  for (final command in allCommands(
    openRegistry:
        openRegistry ??
        clientRegistryOpener(official: registry, licenses: store),
    io: streams,
    official: registry,
    licenses: store,
  )) {
    runner.addCommand(command);
  }
  try {
    return await runner.run(args) ?? 0;
  } on UsageException catch (e) {
    streams.err.writeln(e);
    return 64;
  }
}

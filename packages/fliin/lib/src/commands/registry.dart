// Table des commandes du CLI. Une commande = un fichier dans ce dossier, une ligne ici.
// Une sous-commande (`fliin registry build`) est une `Command` ajoutée à sa commande parente
// dans le fichier de celle-ci, pas ici.
import 'package:args/command_runner.dart';

import '../install/registry_port.dart';
import '../license/license_store.dart';
import '../registry/official.dart';
import 'add.dart';
import 'agents.dart';
import 'create.dart';
import 'diff.dart';
import 'init.dart';
import 'mcp.dart';
import 'list.dart';
import 'login.dart';
import 'logout.dart';
import 'project_command.dart';
import 'registry_command.dart';
import 'remove.dart';
import 'search.dart';
import 'status.dart';
import 'theme.dart';
import 'tokens.dart';
import 'update.dart';
import 'verify.dart';
import 'version.dart';
import 'view.dart';

List<Command<int>> allCommands({
  required OpenRegistry openRegistry,
  required CliIo io,
  OfficialRegistry? official,
  LicenseStore? licenses,
}) => _commands(
  openRegistry,
  io,
  official ?? OfficialRegistry.fliin,
  licenses ?? LicenseStore(),
);

List<Command<int>> _commands(
  OpenRegistry openRegistry,
  CliIo io,
  OfficialRegistry official,
  LicenseStore licenses,
) => [
  VersionCommand(),
  RegistryCommand(),
  SearchCommand(openRegistry, io),
  CreateCommand(openRegistry, io),
  InitCommand(openRegistry, io),
  AgentsCommand(openRegistry, io),
  AddCommand(openRegistry, io),
  RemoveCommand(openRegistry, io),
  ViewCommand(openRegistry, io),
  ListCommand(openRegistry, io),
  StatusCommand(openRegistry, io, licenses),
  UpdateCommand(openRegistry, io),
  DiffCommand(openRegistry, io),
  TokensCommand(openRegistry, io),
  ThemeCommand(openRegistry, io),
  VerifyCommand(openRegistry, io),
  McpCommand(openRegistry, io),
  LoginCommand(openRegistry, io, official, licenses),
  LogoutCommand(openRegistry, io, licenses),
];

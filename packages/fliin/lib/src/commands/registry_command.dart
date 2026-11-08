import 'package:args/command_runner.dart';

import 'registry_build.dart';
import 'registry_keygen.dart';
import 'registry_verify_pointer.dart';

class RegistryCommand extends Command<int> {
  RegistryCommand() {
    addSubcommand(RegistryBuildCommand());
    addSubcommand(RegistryKeygenCommand());
    addSubcommand(RegistryVerifyPointerCommand());
  }

  @override
  String get name => 'registry';

  @override
  String get description => 'Builds, signs and verifies a static registry.';
}

import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli_version.dart';

class VersionCommand extends Command<int> {
  @override
  String get name => 'version';

  @override
  String get description => 'Prints the CLI version.';

  @override
  int run() {
    stdout.writeln(cliVersion);
    return 0;
  }
}

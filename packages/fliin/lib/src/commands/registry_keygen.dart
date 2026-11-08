import 'dart:io';

import 'package:args/command_runner.dart';

import '../registry/signing.dart';

class RegistryKeygenCommand extends Command<int> {
  RegistryKeygenCommand() {
    argParser.addOption(
      'out',
      mandatory: true,
      help: 'The private key file, created with mode 0600.',
    );
  }

  @override
  String get name => 'keygen';

  @override
  String get description =>
      'Creates an Ed25519 signing key and prints its public key in base64.';

  @override
  Future<int> run() async {
    final out = argResults!.option('out')!;
    final key = await SigningKey.generate();
    try {
      key.write(out);
    } on SigningKeyError catch (e) {
      stderr.writeln(e);
      return 1;
    }
    stderr.writeln('Private key written to $out. Never commit it.');
    stdout.writeln(key.publicKey);
    return 0;
  }
}

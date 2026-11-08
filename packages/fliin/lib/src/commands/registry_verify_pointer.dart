import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../registry/client.dart';
import '../registry/signing.dart';

class RegistryVerifyPointerCommand extends Command<int> {
  RegistryVerifyPointerCommand() {
    argParser.addMultiOption('key', help: 'A trusted public key, in base64.');
  }

  @override
  String get name => 'verify-pointer';

  @override
  String get description =>
      'Checks the signature, expiry and schema of a latest.json.';

  @override
  String get invocation =>
      'fliin registry verify-pointer <latest.json> --key <base64>';

  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1 || args.multiOption('key').isEmpty) {
      usageException('Expected one latest.json and at least one --key.');
    }
    final Ed25519PointerVerifier verifier;
    try {
      verifier = Ed25519PointerVerifier(args.multiOption('key'));
    } on FormatException catch (e) {
      usageException('--key: ${e.message}');
    }
    final file = File(args.rest.single);
    if (!file.existsSync()) {
      stderr.writeln('${file.path}: file not found.');
      return 3;
    }
    try {
      final signed = SignedPointer.fromJson(
        jsonDecode(file.readAsStringSync()),
      );
      switch (await signed.open(
        verifier,
        cachedVersion: null,
        now: DateTime.now(),
      )) {
        case PointerAccepted(:final pointer):
          stdout.writeln(
            'accepted: version ${pointer.version}, published on '
            '${pointer.publishedAt.toIso8601String()}, '
            '${switch (pointer.expires) {
              final expires? => 'expires on ${expires.toIso8601String()}',
              null => 'does not expire',
            }}',
          );
          return 0;
        case PointerRejected(:final reason):
          stderr.writeln(PointerRefused(file.uri, reason));
          return 5;
      }
    } on FormatException catch (e) {
      stderr.writeln('${file.path}: unreadable JSON: ${e.message}');
      return 5;
    } on ManifestError catch (e) {
      stderr.writeln('${file.path}: $e');
      return 5;
    }
  }
}

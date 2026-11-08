import 'dart:convert';
import 'dart:io';

import '../install/registry_port.dart';
import '../license/license_store.dart';
import '../registry/client.dart' as client;
import '../registry/official.dart';
import '../registry/signing.dart';
import 'project_command.dart';

/// Vérifie une clé de licence auprès de l'hôte Pro, puis la range hors du
/// projet (ADR 0020 §5). Elle n'est jamais affichée ni passée ailleurs.
class LoginCommand extends ProjectCommand {
  LoginCommand(super.openRegistry, super.io, this.official, this.licenses);

  final OfficialRegistry official;
  final LicenseStore licenses;

  @override
  String get name => 'login';

  @override
  String get invocation => 'fliin login [<key>]';

  @override
  String get description =>
      'Checks a Fliin Pro license key, then saves it for this user, outside '
      'any project. Without <key>, asks for it without echo. '
      'FLIIN_LICENSE_KEY takes precedence over the saved key.';

  @override
  Future<int> execute() async {
    final rest = argResults!.rest;
    if (rest.length > 1) usageException('Expected at most one license key.');
    final key = (rest.isEmpty ? _ask() : rest.single).trim();
    if (key.isEmpty) usageException('Expected a license key.');
    await _check(key);
    licenses.write(key);
    final license = License(key, LicenseOrigin.file);
    return succeed(
      {'licensed': true, 'key': license.hint, 'path': licenses.path},
      [
        'License key ${license.hint} saved to ${licenses.path}.',
        'Fliin Pro items now install from ${official.proUrl}.',
        if (licenses.fromEnvironment)
          'Note: ${LicenseStore.variable} is set, and takes precedence over '
              'the saved key.',
      ],
    );
  }

  /// Une 200 sur `latest.json` de l'hôte Pro avec cette clé.
  Future<void> _check(String key) async {
    try {
      await client.HttpRegistry(
        official.proUrl,
        Ed25519PointerVerifier(official.keys),
        bearer: key,
      ).fetch('latest.json');
    } on client.LicenseRefused catch (e) {
      throw ProLicenseRefused(e.message);
    } on client.RegistryError catch (e) {
      throw RegistryUnreachable(
        '$e. The license key was not checked, nothing was saved',
      );
    }
  }

  String _ask() {
    io.err.write('License key: ');
    if (!stdin.hasTerminal) return stdin.readLineSync(encoding: utf8) ?? '';
    final echo = stdin.echoMode;
    stdin.echoMode = false;
    try {
      return stdin.readLineSync(encoding: utf8) ?? '';
    } finally {
      stdin.echoMode = echo;
      io.err.writeln();
    }
  }
}

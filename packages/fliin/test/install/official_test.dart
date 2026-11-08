import 'dart:io';

import 'package:fliin/src/install/client_registry.dart';
import 'package:fliin/src/install/registry_port.dart';
import 'package:fliin/src/license/license_store.dart';
import 'package:fliin/src/registry/official.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('devrait connaître la clé publique de la sortie et les deux hôtes de fliin.dev', () {
    expect(OfficialRegistry.fliin.keys, ['ZHdHteCzXTq8i1pr2nvyPlrzP8pyDUgebJAntJqzFb0=']);
    expect('${OfficialRegistry.fliin.publicUrl}', 'https://registry.fliin.dev/');
    expect('${OfficialRegistry.fliin.proUrl}', 'https://pro.fliin.dev/');
  });

  test('devrait refuser un registre officiel sans clé, en nommant son URL et la commande qui contourne', () async {
    final home = Directory.systemTemp.createTempSync('fliin-official-');
    addTearDown(() => home.deleteSync(recursive: true));
    final open = clientRegistryOpener(
      official: OfficialRegistry(
        publicUrl: Uri.parse('https://registry.example.test/'),
        proUrl: Uri.parse('https://pro.example.test/'),
        keys: const [],
      ),
      licenses: LicenseStore(environment: {'HOME': p.join(home.path, 'home')}, windows: false),
    );
    await expectLater(
      open(null),
      throwsA(
        isA<NoOfficialKey>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('has no official registry key yet, so it cannot read https://registry.example.test/'),
            contains('fliin init --registry <url> --trusted-key <key>'),
          ),
        ),
      ),
    );
  });
}

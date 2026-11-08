import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('fliin-yaml-'));
  tearDown(() => dir.deleteSync(recursive: true));

  final config = FliinConfig(
    render: RenderConfig(
      root: 'lib/ui/fliin',
      prefix: 'Ac',
      package: 'mon_app',
    ),
    registries: {
      Namespace.fliin: RegistrySource(
        url: RegistrySource.parseUrl('https://registry.fliin.dev'),
        trustedKeys: [base64Encode(List.filled(32, 7))],
      ),
    },
    agents: const [ClaudeCodeAgent(), AndroidStudioAgent(port: 50123)],
  );

  test('devrait relire la même config quand on écrit puis lit fliin.yaml', () {
    writeFliinConfig(dir, config);
    expect(readFliinConfig(dir)!.toJson(), config.toJson());
  });

  test('devrait rendre nul quand fliin.yaml est absent', () {
    expect(readFliinConfig(dir), isNull);
  });

  test('devrait écrire un YAML lisible en bloc quand la config a des registres et des agents', () {
    writeFliinConfig(dir, config);
    expect(File('${dir.path}/fliin.yaml').readAsStringSync(), '''
root: lib/ui/fliin
prefix: Ac
package: mon_app
registries:
  '@fliin':
    url: 'https://registry.fliin.dev/'
    trustedKeys:
    - '${base64Encode(List.filled(32, 7))}'
    auth: none
agents:
  claudeCode: {}
  androidStudio:
    port: 50123
''');
  });
}

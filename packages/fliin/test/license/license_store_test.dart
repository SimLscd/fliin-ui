import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/license/license_store.dart';
import 'package:fliin/src/project/environment_failure.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late String home;

  setUp(() {
    home = Directory.systemTemp.createTempSync('fliin-license-').path;
    addTearDown(() => Directory(home).deleteSync(recursive: true));
  });

  test('devrait ranger la clé sous ~/.config/fliin, sous XDG_CONFIG_HOME s’il est absolu, et sous APPDATA sous Windows', () {
    expect(
      LicenseStore(environment: {'HOME': home}, windows: false).path,
      p.join(home, '.config', 'fliin', 'credentials.json'),
    );
    expect(
      LicenseStore(environment: {'HOME': home, 'XDG_CONFIG_HOME': '/xdg'}, windows: false).path,
      p.join('/xdg', 'fliin', 'credentials.json'),
    );
    expect(
      LicenseStore(environment: {'HOME': home, 'XDG_CONFIG_HOME': 'relatif'}, windows: false).path,
      p.join(home, '.config', 'fliin', 'credentials.json'),
    );
    expect(
      LicenseStore(environment: {'APPDATA': r'C:\Users\a\AppData\Roaming'}, windows: true).path,
      p.join(r'C:\Users\a\AppData\Roaming', 'fliin', 'credentials.json'),
    );
    expect(
      () => LicenseStore(environment: const {}, windows: false).path,
      throwsA(isA<EnvironmentFailure>().having((e) => e.message, 'message', contains('FLIIN_LICENSE_KEY'))),
    );
  });

  test('devrait écrire la clé en 0600, la relire, et l’effacer', () {
    final store = LicenseStore(environment: {'HOME': home}, windows: false);
    expect(store.read(), isNull);
    store.write('FLIIN-PRO-1234-ABCD');
    expect(FileStat.statSync(store.path).mode & 0x1ff, 0x180);
    expect(jsonDecode(File(store.path).readAsStringSync()), {'licenseKey': 'FLIIN-PRO-1234-ABCD'});
    final license = store.read()!;
    expect((license.key, license.origin, license.hint), ('FLIIN-PRO-1234-ABCD', LicenseOrigin.file, '…ABCD'));
    expect(store.delete(), isTrue);
    expect(store.read(), isNull);
    expect(store.delete(), isFalse);
  });

  test('devrait préférer FLIIN_LICENSE_KEY au fichier', () {
    LicenseStore(environment: {'HOME': home}, windows: false).write('FICHIER-0000');
    final store = LicenseStore(environment: {'HOME': home, LicenseStore.variable: ' CI-KEY-WXYZ '}, windows: false);
    expect(store.fromEnvironment, isTrue);
    final license = store.read()!;
    expect((license.key, license.origin), ('CI-KEY-WXYZ', LicenseOrigin.environment));
  });

  test('devrait refuser un fichier illisible en disant comment repartir', () {
    final store = LicenseStore(environment: {'HOME': home}, windows: false);
    File(store.path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('pas du JSON');
    expect(
      store.read,
      throwsA(isA<EnvironmentFailure>().having((e) => e.message, 'message', contains('fliin logout, then fliin login'))),
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:fliin/fliin.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

import '../support/fake_registry.dart';
import '../support/source_versions.dart';

void main() {
  test('devrait chercher dans le registre officiel hors d’un projet, et montrer le Pro sans droit ni API sans clé (ADR 0020 §5)', skip: withoutPro, () async {
    final dir = Directory.systemTemp.createTempSync('fliin-search-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final sources = <RegistrySource?>[];
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await run(
      ['-C', dir.path, 'search', 'réglages du compte', '--limit', '10', '--json'],
      openRegistry: (source) async {
        sources.add(source);
        return FakeRegistry(servesPro: false);
      },
      io: (out: out, err: err),
    );
    expect(code, 0, reason: '$err');
    expect(sources, [null]);
    final results = ((jsonDecode('$out') as Map<String, Object?>)['results']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final screen = results.firstWhere((r) => r['id'] == 'account-settings');
    expect(screen, allOf(
      containsPair('tier', 'pro'),
      containsPair('entitled', false),
      containsPair('apiSummary', null),
    ));
    expect(screen.containsKey('unavailable'), isFalse);
    final free = results.firstWhere((r) => r['tier'] == 'free');
    expect(free, containsPair('entitled', true));
    expect(free['apiSummary'], isNotNull);
  });
}

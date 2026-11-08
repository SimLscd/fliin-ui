import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:test/test.dart';

import '../support/fake_registry.dart';
import '../support/source_versions.dart';
import 'support.dart';

const _buttonFile = 'components/button/fl_button.dart';

/// Les goldens de référence que `registry build` a publiés pour button.
ItemGoldens _publishedGoldens(TestDist dist) => ItemManifest.fromJson(
  jsonDecode(
    File.fromUri(Uri.parse(dist.url).resolve('items/fliin/button/${sourceVersion('button')}.json'))
        .readAsStringSync(),
  ),
).verify!.goldens!;

void main() {
  late TestDist dist;

  setUpAll(() async => dist = await buildTestDist());

  for (final era in eras) {
    group('client $era', () {
      late McpClient client;

      setUpAll(() async {
        client = eraClient(era);
        await client.connect(await stdioTransport(dist));
      });

      tearDownAll(() => client.close());

      test(
        'devrait négocier $era et lister les trois outils en lecture seule',
        () async {
          expect(client.getProtocolVersion(), era);
          final tools = {
            for (final tool in (await client.listTools()).tools)
              tool.name: tool.annotations,
          };
          expect(
            tools.keys,
            unorderedEquals(['get_item', 'request_selection', 'search_items']),
          );
          for (final MapEntry(key: name, value: hints) in tools.entries) {
            expect(hints?.readOnlyHint, isTrue, reason: name);
            expect(hints?.openWorldHint, isFalse, reason: name);
            expect(
              hints?.idempotentHint,
              name != 'request_selection',
              reason: name,
            );
          }
        },
      );

      test('devrait rendre button en premier avec son API et son golden publié quand on cherche « bouton d\'action principal »', () async {
        final result = await client.callTool(
          const CallToolRequest(
            name: 'search_items',
            arguments: {'intent': "bouton d'action principal"},
          ),
        );
        expect(result.isError, isFalse, reason: '${result.content}');
        final first =
            (textJson(result)['results']! as List<Object?>).first!
                as Map<String, Object?>;
        expect(first['id'], 'button');
        expect(first['install'], 'fliin add button');
        expect(first['entitled'], isTrue);
        expect(
          first['apiSummary'],
          contains('FlButton.new: const new({super.key, required String label'),
        );
        final previewUrl = Uri.parse(first['previewUrl']! as String);
        expect(previewUrl.host, '127.0.0.1');
        expect(previewUrl.path, '/preview/button/${sourceVersion('button')}/ios.light.1.0.ltr.png');
        final http = HttpClient();
        addTearDown(http.close);
        final response = await (await http.getUrl(previewUrl)).close();
        expect(response.statusCode, 200);
        expect(response.headers.contentType?.mimeType, 'image/png');
        final png = [for (final chunk in await response.toList()) ...chunk];
        expect(
          Sha256.ofBytes(png),
          _publishedGoldens(dist).variants['ios.light.1.0.ltr'],
        );
      });

      test('devrait rendre le sha256 attendu quand on lit button avec source et install', () async {
        final result = await client.callTool(
          const CallToolRequest(
            name: 'get_item',
            arguments: {
              'id': 'button',
              'include': ['source', 'install'],
            },
          ),
        );
        expect(result.isError, isFalse, reason: '${result.content}');
        final json = textJson(result);
        final source =
            (json['source']! as List<Object?>).single! as Map<String, Object?>;
        expect(source['sha256'], FakeRegistry.shaOf(_buttonFile).value);
        final install = json['install']! as Map<String, Object?>;
        expect(install['closure'], ['core@${sourceVersion('core')}', 'spinner@${sourceVersion('spinner')}']);
        expect((install['files']! as List<Object?>).single, {
          'rawPath': _buttonFile,
          'targetTemplate': '{root}/components/button/fl_button.dart',
          'sha256': FakeRegistry.shaOf(_buttonFile).value,
        });
      });

      test('devrait rendre INVALID_INPUT au format §5.2 quand l\'intention fait deux mots', () async {
        final result = await client.callTool(
          const CallToolRequest(
            name: 'search_items',
            arguments: {'intent': 'bouton principal'},
          ),
        );
        expect(result.isError, isTrue);
        final error = textJson(result);
        expect(error, containsPair('code', 'INVALID_INPUT'));
        expect(error, containsPair('retryable', false));
        expect(error, containsPair('retryAfterSec', null));
        expect(error, containsPair('fix', null));
        expect(
          (error['details']! as Map<String, Object?>)['suggestions'],
          isNotEmpty,
        );
      });
    });
  }
}

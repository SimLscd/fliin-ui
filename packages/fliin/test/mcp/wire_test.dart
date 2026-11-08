import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../registry/support.dart';
import 'support.dart';

/// Ce qui part sur le fil en 2026-07-28, lu sans client : `resultType` sur
/// chaque résultat, `ttlMs` et `cacheScope` sur les listes (VERIFICATIONS.md
/// §4.1 : sans eux, Claude Code n'affichait aucun outil).
const _token = 'jeton-de-test-fil';

Map<String, Object?> _meta({bool url = false}) => {
  'io.modelcontextprotocol/protocolVersion': '2026-07-28',
  'io.modelcontextprotocol/clientInfo': {'name': 'fil', 'version': '0'},
  'io.modelcontextprotocol/clientCapabilities': {
    'elicitation': url ? {'url': <String, Object?>{}} : <String, Object?>{},
  },
};

typedef _Call = ({String method, String? name, Map<String, Object?> params});

final _calls = <_Call>[
  (method: 'server/discover', name: null, params: {'_meta': _meta()}),
  (method: 'tools/list', name: null, params: {'_meta': _meta()}),
  (
    method: 'tools/call',
    name: 'search_items',
    params: {
      'name': 'search_items',
      'arguments': {'intent': "bouton d'action principal"},
      '_meta': _meta(),
    },
  ),
  (
    method: 'tools/call',
    name: 'request_selection',
    params: {
      'name': 'request_selection',
      'arguments': {
        'candidates': ['button', 'switch'],
        'question': 'Lequel ?',
      },
      '_meta': _meta(url: true),
    },
  ),
  (
    method: 'tools/call',
    name: 'request_selection',
    params: {
      'name': 'request_selection',
      'arguments': {
        'candidates': ['button', 'switch'],
        'question': 'Lequel ?',
      },
      '_meta': _meta(),
    },
  ),
];

/// Les résultats, dans l'ordre de [_calls].
void _expectWire(List<Map<String, Object?>> results) {
  final [discover, list, search, mrtr, fallback] = results;
  for (final listing in [discover, list]) {
    expect(listing['resultType'], 'complete');
    expect(listing['ttlMs'], 0);
    expect(listing['cacheScope'], 'private');
  }
  expect(
    [
      for (final tool in list['tools']! as List<Object?>)
        (tool! as Map<String, Object?>)['name'],
    ],
    ['get_item', 'request_selection', 'search_items'],
    reason: 'liste triée de façon déterministe',
  );
  expect(search['resultType'], 'complete');
  expect(search.containsKey('ttlMs'), isFalse);
  expect(mrtr['resultType'], 'input_required');
  expect(mrtr['requestState'], isA<String>());
  final pick =
      (mrtr['inputRequests']! as Map<String, Object?>)['pick']!
          as Map<String, Object?>;
  expect(pick['method'], 'elicitation/create');
  final params = pick['params']! as Map<String, Object?>;
  expect(params['mode'], 'url');
  expect(params['url'], endsWith('/pick/${mrtr['requestState']}'));
  expect(params.containsKey('elicitationId'), isFalse);
  expect(fallback['resultType'], 'complete');
  expect(
    (fallback['structuredContent']! as Map<String, Object?>)['status'],
    'pending',
  );
}

Map<String, Object?> _request(int id, _Call call) => {
  'jsonrpc': '2.0',
  'id': id,
  'method': call.method,
  'params': call.params,
};

void main() {
  late TestDist dist;

  setUpAll(() async => dist = await buildTestDist());

  test('devrait poser resultType, ttlMs et cacheScope quand un client 2026-07-28 parle en stdio', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [await compiledCli(), ...mcpArgs(dist)],
      environment: {'HOME': tempDir().path},
    );
    addTearDown(process.kill);
    unawaited(process.stderr.drain<void>());
    final responses = <int, Map<String, Object?>>{};
    final done = Completer<void>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final message = jsonDecode(line) as Map<String, Object?>;
          if (message['id'] case final int id) {
            responses[id] = message;
            if (responses.length == _calls.length) done.complete();
          }
        });
    for (final (i, call) in _calls.indexed) {
      process.stdin.writeln(jsonEncode(_request(i + 1, call)));
    }
    await done.future.timeout(const Duration(seconds: 30));
    _expectWire([
      for (var id = 1; id <= _calls.length; id++)
        responses[id]!['result']! as Map<String, Object?>,
    ]);
  });

  test('devrait poser resultType, ttlMs et cacheScope quand un client 2026-07-28 parle en HTTP avec le jeton', () async {
    final port = (await startHttpServer(dist, _token)).port;
    final http = HttpClient();
    addTearDown(http.close);
    final results = <Map<String, Object?>>[];
    for (final (i, call) in _calls.indexed) {
      final request = await http.postUrl(Uri.http('127.0.0.1:$port', '/mcp'))
        ..headers.set('Authorization', 'Bearer $_token')
        ..headers.contentType = ContentType.json
        ..headers.set('Accept', 'application/json, text/event-stream')
        ..headers.set('MCP-Protocol-Version', '2026-07-28')
        ..headers.set('Mcp-Method', call.method);
      if (call.name case final name?) request.headers.set('Mcp-Name', name);
      request.write(jsonEncode(_request(i + 1, call)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200, reason: body);
      final json = response.headers.contentType?.mimeType == 'text/event-stream'
          ? body
                .split('\n')
                .where((line) => line.startsWith('data:'))
                .map((line) => line.substring(5).trim())
                .last
          : body;
      results.add(
        (jsonDecode(json) as Map<String, Object?>)['result']!
            as Map<String, Object?>,
      );
    }
    _expectWire(results);
  });

  test(
    'devrait garder la version du premier initialize quand un second arrive',
    () async {
      final process = await Process.start(
        Platform.resolvedExecutable,
        [await compiledCli(), ...mcpArgs(dist)],
        environment: {'HOME': tempDir().path},
      );
      addTearDown(process.kill);
      unawaited(process.stderr.drain<void>());
      final responses = StreamController<Map<String, Object?>>.broadcast();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .where((message) => message.containsKey('id'))
          .listen(responses.add);
      Future<Map<String, Object?>> send(
        int id,
        String method,
        Map<String, Object?> params,
      ) {
        final reply = responses.stream.firstWhere((m) => m['id'] == id);
        process.stdin.writeln(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'method': method,
            'params': params,
          }),
        );
        return reply.timeout(const Duration(seconds: 30));
      }

      Map<String, Object?> initialize(String version) => {
        'protocolVersion': version,
        'capabilities': {
          'elicitation': {'url': <String, Object?>{}},
        },
        'clientInfo': {'name': 'fil', 'version': '0'},
      };
      final first = await send(1, 'initialize', initialize('2025-11-25'));
      expect((first['result']! as Map)['protocolVersion'], '2025-11-25');
      process.stdin.writeln(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      final second = await send(2, 'initialize', initialize('2025-06-18'));
      expect(
        second.containsKey('error'),
        isTrue,
        reason: 'le SDK refuse un second initialize',
      );
      final call = await send(3, 'tools/call', {
        'name': 'request_selection',
        'arguments': {
          'candidates': ['button', 'switch'],
          'question': 'Lequel ?',
        },
      });
      expect(
        (call['error'] as Map?)?['code'],
        -32042,
        reason: 'la connexion reste en 2025-11-25 : élicitation URL',
      );
    },
  );
}

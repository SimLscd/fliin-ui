import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'support.dart';

const _token = 'jeton-de-test-android-studio';

/// Une requête HTTP/1.1 écrite à la main, pour choisir Host et Origin.
Future<int> _status({
  required int port,
  Map<String, String> headers = const {},
}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  const body = '{"jsonrpc":"2.0","id":1,"method":"tools/list"}';
  socket.write(
    [
      'POST /mcp HTTP/1.1',
      'Host: ${headers['Host'] ?? '127.0.0.1:$port'}',
      'Content-Type: application/json',
      'Accept: application/json, text/event-stream',
      'Content-Length: ${utf8.encode(body).length}',
      'Connection: close',
      for (final MapEntry(:key, :value) in headers.entries)
        if (key != 'Host') '$key: $value',
      '',
      body,
    ].join('\r\n'),
  );
  final response = utf8.decode([
    for (final chunk in await socket.toList()) ...chunk,
  ], allowMalformed: true);
  await socket.close();
  return int.parse(response.split(' ')[1]);
}

void main() {
  late int port;

  setUpAll(() async {
    port = (await startHttpServer(await buildTestDist(), _token)).port;
  });

  test('devrait répondre 401 avec un défi Bearer quand le jeton manque ou est faux', () async {
    expect(await _status(port: port), 401);
    expect(
      await _status(port: port, headers: {'Authorization': 'Bearer faux'}),
      401,
    );
    final request = await HttpClient().postUrl(
      Uri.http('127.0.0.1:$port', '/mcp'),
    );
    final response = await request.close();
    expect(response.statusCode, 401);
    expect(response.headers.value('www-authenticate'), startsWith('Bearer'));
    await response.drain<void>();
  });

  for (final era in eras) {
    test(
      'devrait lister les trois outils quand un client $era se connecte avec le jeton',
      () async {
        final client = eraClient(era);
        final transport = httpTransport(port, _token);
        await client.connect(transport);
        addTearDown(client.close);
        expect(client.getProtocolVersion(), era);
        expect(
          transport.sessionId,
          era == '2026-07-28' ? isNull : isNotNull,
          reason: 'sans état en 2026-07-28, une session par client legacy',
        );
        expect([
          for (final tool in (await client.listTools()).tools) tool.name,
        ], unorderedEquals(['get_item', 'request_selection', 'search_items']));
      },
    );
  }

  test('devrait refuser une origine de navigateur et un Host étranger quand ils se présentent avec le jeton', () async {
    expect(
      await _status(
        port: port,
        headers: {
          'Authorization': 'Bearer $_token',
          'Origin': 'http://localhost:5173',
        },
      ),
      403,
    );
    expect(
      await _status(
        port: port,
        headers: {'Authorization': 'Bearer $_token', 'Host': 'evil.example'},
      ),
      403,
    );
  });
}

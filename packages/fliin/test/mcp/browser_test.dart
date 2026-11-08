@Tags(['slow'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/mcp/local/pick_page.dart';
import 'package:fliin/src/mcp/local/selection_store.dart';
import 'package:fliin/src/mcp/ports.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../registry/support.dart';

/// Un Chromium headless local (par exemple celui du cache de Playwright),
/// piloté par le protocole DevTools, sans réseau. Sans lui, le test est
/// sauté : la CI n'en a pas.
final _chrome = Platform.environment['FLIIN_TEST_CHROME'];

Future<Object?> _evaluate(
  WebSocket socket,
  Stream<Object?> replies,
  int id,
  String expression,
) async {
  socket.add(
    jsonEncode({
      'id': id,
      'method': 'Runtime.evaluate',
      'params': {'expression': expression, 'returnByValue': true},
    }),
  );
  final reply = await replies.firstWhere(
    (message) => message is Map && message['id'] == id,
  ) as Map;
  return ((reply['result'] as Map)['result'] as Map)['value'];
}

void main() {
  test(
    'devrait enregistrer le choix posté par un vrai navigateur',
    skip: _chrome == null ? 'FLIIN_TEST_CHROME non défini' : false,
    () async {
      final store = MemorySelectionStore();
      final page = LocalPickPage(
        store: store,
        describe: (ref, _) async =>
            (title: ref.name, description: 'Un élément.', hasPreview: false),
        preview: (_, _) async => null,
      );
      addTearDown(page.close);
      final selection = await store.open(
        candidates: [
          ItemRef('button', version: Version(0, 1, 0)),
          ItemRef('switch', version: Version(0, 1, 0)),
        ],
        question: 'Lequel ?',
        variant: const GoldenVariant(),
      );
      final url = await page.pickUrl(selection.handle);
      final profile = tempDir();
      final chrome = await Process.start(_chrome!, [
        '--headless',
        '--no-first-run',
        '--remote-debugging-port=0',
        '--user-data-dir=${profile.path}',
        '$url',
      ]);
      addTearDown(() {
        chrome.kill();
        return chrome.exitCode;
      });
      unawaited(chrome.stdout.drain<void>());
      final devtools = await chrome.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map(RegExp(r'DevTools listening on (ws://\S+)').firstMatch)
          .firstWhere((match) => match != null)
          .timeout(const Duration(seconds: 30));
      final port = Uri.parse(devtools![1]!).port;
      final http = HttpClient();
      addTearDown(http.close);
      String? target;
      for (var i = 0; i < 50 && target == null; i++) {
        final list = jsonDecode(
          await (await (await http.getUrl(
            Uri.http('127.0.0.1:$port', '/json/list'),
          )).close()).transform(utf8.decoder).join(),
        ) as List<Object?>;
        target = list
            .cast<Map<String, Object?>>()
            .where((t) => t['type'] == 'page' && '${t['url']}' == '$url')
            .map((t) => t['webSocketDebuggerUrl'] as String)
            .firstOrNull;
        if (target == null) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      final socket = await WebSocket.connect(target!);
      addTearDown(socket.close);
      final replies = socket
          .map<Object?>((message) => jsonDecode(message as String))
          .asBroadcastStream();
      for (var i = 0; i < 50; i++) {
        if (await _evaluate(socket, replies, 1000 + i, 'document.readyState') ==
            'complete') {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await _evaluate(
        socket,
        replies,
        1,
        "document.getElementById('c1').focus();"
        "document.getElementById('c1').click();"
        "document.querySelector('button[value=choose]').click();",
      );
      for (var i = 0; i < 50; i++) {
        if ((await store.find(selection.handle))!.status is Chosen) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        ((await store.find(selection.handle))!.status as Chosen).item,
        ItemRef('switch'),
      );
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/project/local_state.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart';

/// Un registre statique signé par une clé neuve, construit par le vrai CLI
/// sur une copie de `flutter/registry`.
typedef TestDist = ({String url, String publicKey});

Future<TestDist> buildTestDist() async {
  final dir = tempDir().path;
  final keyFile = p.join(dir, 'fliin-signing.key');
  final keygen = await fliin(['registry', 'keygen', '--out', keyFile]);
  expect(keygen.exitCode, 0, reason: '${keygen.stderr}');
  final out = p.join(dir, 'dist');
  final build = await fliin([
    'registry',
    'build',
    '--source',
    copiedSource(),
    '--out',
    out,
    '--key',
    keyFile,
  ]);
  expect(build.exitCode, 0, reason: '${build.stderr}');
  return (url: '${Directory(out).uri}', publicKey: '${keygen.stdout}'.trim());
}

/// Les arguments de `fliin mcp` sur ce registre.
List<String> mcpArgs(TestDist dist, [List<String> extra = const []]) => [
  'mcp',
  '--registry',
  dist.url,
  '--trusted-key',
  dist.publicKey,
  ...extra,
];

/// Les trois ères de VERIFICATIONS.md §4 que les clients parlent.
const eras = ['2026-07-28', '2025-11-25', '2025-06-18'];

/// Un client `mcp_dart` de l'ère [era] qui déclare l'élicitation URL, ou
/// seulement une capacité vide (« formulaire seul »).
McpClient eraClient(
  String era, {
  bool url = false,
  Future<ElicitResult> Function(ElicitRequest request)? onElicit,
}) {
  final capabilities = ClientCapabilities(
    elicitation: url
        ? const ClientElicitation.urlOnly()
        : ClientElicitation.fromJson(const {}),
  );
  return McpClient(
    const Implementation(name: 'fliin-test', version: '0'),
    options: era == '2026-07-28'
        ? McpClientOptions(
            protocol: McpProtocol.require2026,
            capabilities: capabilities,
          )
        : McpClientOptions(
            protocol: McpProtocol.legacy,
            protocolVersion: era,
            capabilities: capabilities,
          ),
  )..onElicitRequest = onElicit;
}

/// `fliin mcp` en stdio sur [dist], un processus par client.
Future<StdioClientTransport> stdioTransport(TestDist dist) async {
  final transport = StdioClientTransport(
    StdioServerParameters(
      command: Platform.resolvedExecutable,
      args: [await compiledCli(), ...mcpArgs(dist)],
      environment: {'HOME': tempDir().path},
      stderrMode: ProcessStartMode.normal,
    ),
  );
  unawaited(transport.stderr?.drain<void>());
  return transport;
}

/// Un `fliin mcp --http` sur un port libre, avec le jeton [token].
Future<({int port, Process process})> startHttpServer(
  TestDist dist,
  String token,
) async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  final project = tempDir();
  LocalState(androidStudioToken: token).write(project);
  final process = await Process.start(
    Platform.resolvedExecutable,
    [
      await compiledCli(),
      ...mcpArgs(dist, ['--http', '--port', '$port']),
    ],
    workingDirectory: project.path,
    environment: {'HOME': tempDir().path},
  );
  unawaited(process.stdout.drain<void>());
  final ready = Completer<void>();
  process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
    (line) {
      if (!ready.isCompleted && line.contains('http://127.0.0.1:$port/mcp')) {
        ready.complete();
      }
    },
  );
  await ready.future.timeout(const Duration(seconds: 30));
  addTearDown(() {
    process.kill();
    return process.exitCode;
  });
  return (port: port, process: process);
}

StreamableHttpClientTransport httpTransport(int port, String token) =>
    StreamableHttpClientTransport(
      Uri.http('127.0.0.1:$port', '/mcp'),
      opts: StreamableHttpClientTransportOptions(
        requestInit: {
          'headers': {'Authorization': 'Bearer $token'},
        },
      ),
    );

/// Ce que fait l'humain : ouvrir la page, choisir [item] (ou refuser sans
/// lui), envoyer. Rend le statut de la réponse au POST.
Future<int> humanAnswers(String pickUrl, {String? item}) async {
  final http = HttpClient();
  try {
    final page = await (await (await http.getUrl(
      Uri.parse(pickUrl),
    )).close()).transform(utf8.decoder).join();
    final token = RegExp(r'name="token" value="([^"]+)"').firstMatch(page)![1]!;
    final post = await http.postUrl(Uri.parse(pickUrl))
      ..followRedirects = false
      ..headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      )
      ..write(
        Uri(
          queryParameters: {
            'token': token,
            'action': item == null ? 'decline' : 'choose',
            'item': ?item,
          },
        ).query,
      );
    final response = await post.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    http.close();
  }
}

/// Le JSON du premier bloc texte d'un résultat d'outil.
Map<String, Object?> textJson(CallToolResult result) =>
    jsonDecode((result.content.first as TextContent).text)
        as Map<String, Object?>;

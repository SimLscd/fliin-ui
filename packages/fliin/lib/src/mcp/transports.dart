import 'dart:async';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

import 'local/pick_page.dart';
import 'server.dart';

/// Stdio, le transport par défaut (Claude Code, Cursor, Gemini CLI) : stdout
/// est le canal JSON-RPC, le SDK journalise sur stderr. Rend quand le client
/// ferme stdin, la page de choix arrêtée.
Future<void> serveStdio(FliinMcpServer server) async {
  final mcp = server.build();
  final closed = Completer<void>();
  mcp.server.onclose = closed.complete;
  await mcp.connect(StdioServerTransport());
  await closed.future;
  await server.close();
}

/// `allowedOrigins` non vide, sans aucune origine de navigateur : `mcp_dart`
/// lit un ensemble vide comme « déduire des hôtes », ce qui accepterait
/// `http://localhost:<port>`. Un navigateur n'envoie jamais ce schéma, donc
/// toute page est refusée en 403 par sa protection DNS rebinding.
const _noBrowserOrigins = {'fliin://no-browser'};

/// HTTP Streamable sur 127.0.0.1 seulement, pour Android Studio (ADR §4.1,
/// constat 11) : jeton porteur obligatoire, 401 avec défi Bearer sinon,
/// hôtes de boucle locale seuls, aucune origine de navigateur. Le SDK sert
/// un client 2026-07-28 sans état et une session par client legacy.
Future<StreamableMcpServer> serveHttp(
  FliinMcpServer server, {
  required int port,
  required String token,
}) async {
  final http = StreamableMcpServer(
    serverFactory: (_) => server.build(),
    host: '127.0.0.1',
    port: port,
    path: '/mcp',
    enableDnsRebindingProtection: true,
    allowedHosts: const {'127.0.0.1', 'localhost'},
    allowedOrigins: _noBrowserOrigins,
    authenticationHandler: (Object? request) =>
        _bearer(request as HttpRequest, token)
        ? const StreamableMcpAuthenticationResult.allow()
        : const StreamableMcpAuthenticationResult.unauthorized(
            errorDescription:
                'the bearer token from .fliin/local.json is required',
          ),
    oauthProtectedResource: OAuthProtectedResourceOptions(
      metadata: OAuthProtectedResourceMetadata(
        resource: Uri.http('127.0.0.1:$port', '/mcp'),
        authorizationServers: const [],
      ),
    ),
  );
  await http.start();
  return http;
}

bool _bearer(HttpRequest request, String token) {
  const prefix = 'Bearer ';
  final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  return header.startsWith(prefix) &&
      secretsMatch(header.substring(prefix.length).trim(), token);
}

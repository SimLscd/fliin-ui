import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Une autorité de test et un certificat serveur pour `localhost` et
/// `127.0.0.1`, créés par `openssl` dans [dir] à chaque exécution : aucune
/// clé n'est commitée. Seul un `SecurityContext` de test leur fait confiance.
final class TestTls {
  TestTls._(this.caPem, this.certPem, this.keyPem);

  static Future<TestTls> create(String dir) async {
    String at(String name) => p.join(dir, name);
    File(at('server.ext')).writeAsStringSync(
      'subjectAltName=DNS:localhost,DNS:registry.example.com,IP:127.0.0.1\n'
      'basicConstraints=CA:FALSE\n'
      'keyUsage=critical,digitalSignature,keyEncipherment\n'
      'extendedKeyUsage=serverAuth\n',
    );
    for (final args in [
      [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        at('ca.key'),
        '-out',
        at('ca.pem'),
        '-days',
        '2',
        '-subj',
        '/CN=fliin test CA',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
      ],
      [
        'req',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        at('server.key'),
        '-out',
        at('server.csr'),
        '-subj',
        '/CN=localhost',
      ],
      [
        'x509',
        '-req',
        '-in',
        at('server.csr'),
        '-CA',
        at('ca.pem'),
        '-CAkey',
        at('ca.key'),
        '-CAcreateserial',
        '-out',
        at('server.pem'),
        '-days',
        '2',
        '-extfile',
        at('server.ext'),
      ],
    ]) {
      final run = await Process.run('openssl', args);
      if (run.exitCode != 0) throw StateError('openssl $args : ${run.stderr}');
    }
    return TestTls._(at('ca.pem'), at('server.pem'), at('server.key'));
  }

  /// Le certificat de l'autorité, à donner au client.
  final String caPem;
  final String certPem;
  final String keyPem;

  SecurityContext get serverContext => SecurityContext()
    ..useCertificateChain(certPem)
    ..usePrivateKey(keyPem);
}

/// Un `SecurityContext` qui ne fait confiance qu'à [caPem].
SecurityContext trusting(String caPem) =>
    SecurityContext(withTrustedRoots: false)..setTrustedCertificates(caPem);

/// Injecte [context] dans chaque `HttpClient` créé : c'est ainsi, et
/// seulement dans les tests, que le client accepte le certificat de test.
final class TrustingOverrides extends HttpOverrides {
  TrustingOverrides(this.context);

  final SecurityContext context;

  @override
  HttpClient createHttpClient(SecurityContext? _) =>
      super.createHttpClient(context);
}

/// Ce que le serveur fait d'une requête au lieu de servir le fichier.
sealed class Fault {
  const Fault();
}

final class Status extends Fault {
  const Status(this.code);

  final int code;
}

/// [code] avec le corps JSON `{"error", "message"}` du Worker du registre
/// Pro.
final class Problem extends Fault {
  const Problem(this.code, this.error, this.message);

  final int code;
  final String error;
  final String message;
}

/// Annonce la longueur du fichier, n'en envoie que la moitié, puis coupe.
final class Truncate extends Fault {
  const Truncate();
}

/// Redirige vers [location], résolu par le client.
final class Redirect extends Fault {
  const Redirect(this.location, {this.code = HttpStatus.found});

  final String location;
  final int code;
}

/// Se tait avant les en-têtes, ou avec [midBody] après un premier octet
/// du corps.
final class Stall extends Fault {
  const Stall({this.midBody = false});

  final bool midBody;
}

/// Envoie un octet toutes les 50 ms, sans fin.
final class Trickle extends Fault {
  const Trickle();
}

/// Sert [bytes] zéros compressés en gzip : peu d'octets transférés, beaucoup
/// une fois décompressés.
final class GzipBomb extends Fault {
  const GzipBomb(this.bytes);

  final int bytes;
}

/// Sert d'autres octets que ceux du fichier.
final class Tamper extends Fault {
  const Tamper();
}

typedef RecordedRequest = ({
  String method,
  String path,
  Map<String, List<String>> headers,
});

/// Un `dist/` servi en HTTPS sur 127.0.0.1 (ou en clair sans `tls`), qui
/// garde chaque requête reçue et applique [faults] par chemin. Avec
/// [license], il répond comme le Worker du registre Pro : 401 sans clé, 403
/// pour une autre clé.
final class HttpsRegistryServer {
  HttpsRegistryServer._(this.dist, this._server, this.uri) {
    _server.listen(_handle);
  }

  static Future<HttpsRegistryServer> start(
    String dist, {
    TestTls? tls,
    int port = 0,
  }) async {
    final server = tls == null
        ? await HttpServer.bind(InternetAddress.loopbackIPv4, port)
        : await HttpServer.bindSecure(
            InternetAddress.loopbackIPv4,
            port,
            tls.serverContext,
          );
    return HttpsRegistryServer._(
      dist,
      server,
      Uri.parse(
        '${tls == null ? 'http' : 'https'}://127.0.0.1:${server.port}/',
      ),
    );
  }

  final String dist;
  final HttpServer _server;

  /// L'URL de base du registre, avec la barre finale.
  final Uri uri;
  final faults = <String, Fault>{};
  final requests = <RecordedRequest>[];

  /// La seule clé de licence acceptée ; nulle, le registre est anonyme.
  String? license;
  final _stalled = <HttpResponse>[];

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path.substring(1);
    final headers = <String, List<String>>{};
    request.headers.forEach((name, values) => headers[name] = values);
    requests.add((method: request.method, path: path, headers: headers));
    final response = request.response;
    final file = File(p.join(dist, path));
    final bearer = request.headers.value(HttpHeaders.authorizationHeader);
    final refusal = switch (license) {
      null => null,
      _ when bearer == null => const Problem(
        HttpStatus.unauthorized,
        'license_required',
        'Fliin Pro needs a license key: get one at https://fliin.dev/pro, '
            'then run fliin login.',
      ),
      final key when bearer != 'Bearer $key' => const Problem(
        HttpStatus.forbidden,
        'license_refused',
        'This license key is not valid for Fliin Pro (unknown, revoked or '
            'expired). See https://fliin.dev/pro.',
      ),
      _ => null,
    };
    switch (refusal ?? faults[path]) {
      case Problem(:final code, :final error, :final message):
        response
          ..statusCode = code
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': error, 'message': message}));
        await response.close();
      case Status(:final code):
        response.statusCode = code;
        await response.close();
      case Redirect(:final location, :final code):
        response
          ..statusCode = code
          ..headers.set(HttpHeaders.locationHeader, location);
        await response.close();
      case Stall(:final midBody):
        if (midBody) {
          response.headers.contentLength = 10;
          response.add([0x7b]);
          await response.flush();
        }
        _stalled.add(response);
      case Trickle():
        response
          ..bufferOutput = false
          ..headers.contentLength = 1 << 30;
        _stalled.add(response);
        while (_stalled.contains(response)) {
          try {
            response.add([0x20]);
            await response.flush();
          } on Object {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      case GzipBomb(:final bytes):
        final zipped = gzip.encode(List<int>.filled(bytes, 0));
        response.headers
          ..set(HttpHeaders.contentEncodingHeader, 'gzip')
          ..contentLength = zipped.length;
        response.add(zipped);
        await response.close();
      case Truncate():
        final bytes = file.readAsBytesSync();
        response.headers.contentLength = bytes.length;
        final socket = await response.detachSocket();
        socket.add(bytes.sublist(0, bytes.length ~/ 2));
        await socket.flush();
        socket.destroy();
      case Tamper():
        response.add(utf8.encode('{"altéré": true}'));
        await response.close();
      case null when file.existsSync():
        response.add(file.readAsBytesSync());
        await response.close();
      case null:
        response.statusCode = HttpStatus.notFound;
        await response.close();
    }
  }

  Future<void> close() async {
    final stalled = [..._stalled];
    _stalled.clear();
    for (final response in stalled) {
      unawaited(response.close().catchError((Object _) {}));
    }
    await _server.close(force: true);
  }
}

/// Un proxy HTTP qui ne sait que `CONNECT` : il garde la cible demandée et
/// relaie les octets sans les lire, comme un proxy d'entreprise devant TLS.
final class ConnectProxy {
  ConnectProxy._(this._server, this._to) {
    _server.listen(_tunnel);
  }

  /// Avec [to], chaque tunnel aboutit à 127.0.0.1:[to] quelle que soit la
  /// cible demandée : un nom distant sert ainsi le serveur de test.
  static Future<ConnectProxy> start({int? to}) async => ConnectProxy._(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    to,
  );

  final ServerSocket _server;
  final int? _to;
  final targets = <String>[];

  int get port => _server.port;

  void _tunnel(Socket client) {
    final head = <int>[];
    late StreamSubscription<List<int>> subscription;
    subscription = client.listen((chunk) async {
      head.addAll(chunk);
      final text = latin1.decode(head);
      final end = text.indexOf('\r\n\r\n');
      if (end < 0) return;
      subscription.pause();
      final target = text.split(' ')[1];
      targets.add(target);
      final [host, port] = target.split(':');
      final upstream = _to == null
          ? await Socket.connect(host, int.parse(port))
          : await Socket.connect(InternetAddress.loopbackIPv4, _to);
      client.add(latin1.encode('HTTP/1.1 200 Connection established\r\n\r\n'));
      final rest = head.sublist(end + 4);
      if (rest.isNotEmpty) upstream.add(rest);
      subscription
        ..onData(upstream.add)
        ..onDone(upstream.destroy)
        ..resume();
      upstream.listen(client.add, onDone: client.destroy);
    });
  }

  Future<void> close() => _server.close();
}

/// Sert un `dist/` en HTTPS pour `tool/slice.sh` : écrit l'URL dans
/// [args][1] et le certificat de l'autorité dans [args][2], puis sert
/// jusqu'à ce qu'on le tue.
/// `dart run test/support/https_registry.dart <dist> <url> <ca.pem>`
Future<void> main(List<String> args) async {
  final [dist, urlFile, caFile] = args;
  final tls = await TestTls.create(
    Directory.systemTemp.createTempSync('fliin_tls_').path,
  );
  final server = await HttpsRegistryServer.start(dist, tls: tls);
  File(caFile).writeAsStringSync(File(tls.caPem).readAsStringSync());
  File(urlFile).writeAsStringSync('${server.uri}');
}

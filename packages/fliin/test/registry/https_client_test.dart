import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/client.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/https_registry.dart';
import 'support.dart';

final _publishedAt = DateTime.utc(2026, 10, 18, 9);
final _dayAfter = _publishedAt.add(const Duration(days: 1));

late TestTls _tls;
late String _dist;
late HttpsRegistryServer _server;

/// Le client tel que le CLI le construit, sans proxy, avec [timeout] et la
/// confiance en l'autorité de test injectée par `HttpOverrides`.
Future<RegistryClient> _client({
  Uri? url,
  Duration timeout = HttpRegistry.defaultTimeout,
  Duration deadline = HttpRegistry.defaultDeadline,
  Map<String, String> environment = const {},
  DateTime? now,
  String? cache,
  String? bearer,
}) async => HttpRegistry(
  url ?? _server.uri,
  Ed25519PointerVerifier([(await testKey()).publicKey]),
  cacheRoot: cache ?? tempDir().path,
  clock: () => now ?? _dayAfter,
  timeout: timeout,
  deadline: deadline,
  environment: environment,
  bearer: bearer,
);

/// Un blob que le pointeur désigne, et son chemin.
Future<(Sha256, String)> _aBlob() async {
  final manifest = SourceRegistry.read(sourceRoot).manifests.first;
  final sha256 = manifest.files.first.sha256;
  return (sha256, DistLayout.blobPath(sha256));
}

Matcher _unreachable(List<String> fragments) => throwsA(
  isA<RegistryUnreachable>().having(
    (e) => '$e',
    'message',
    allOf([for (final f in fragments) contains(f)]),
  ),
);

void main() {
  setUpAll(() async {
    _tls = await TestTls.create(tempDir().path);
    _dist = tempDir().path;
    await DistWriter(_dist).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(
        version: 2,
        publishedAt: _publishedAt,
        lifetime: const Duration(days: 14),
      ),
      key: await testKey(),
    );
    HttpOverrides.global = TrustingOverrides(trusting(_tls.caPem));
  });
  setUp(
    () async => _server = await HttpsRegistryServer.start(_dist, tls: _tls),
  );
  tearDown(() => _server.close());
  tearDownAll(() => HttpOverrides.global = null);

  test('devrait lire pointeur, fragment, manifeste et blob en https quand le certificat est approuvé', () async {
    final client = await _client();
    final pointer = await client.fetchPointer();
    final fragment = await client.fetchFragment(
      pointer,
      pointer.fragments.single,
    );
    final entry = fragment.entries.firstWhere((e) => e.ref.name == 'button');
    final manifest = await client.fetchManifest(
      entry.ref,
      entry.versions.single,
    );
    final blob = await client.fetchBlob(manifest.files.single.sha256);
    expect(Sha256.ofBytes(blob), manifest.files.single.sha256);
  });

  test('devrait refuser un certificat que le système n’approuve pas, sans contournement', () async {
    HttpOverrides.global = null;
    try {
      await expectLater(
        (await _client()).fetchPointer(),
        _unreachable(['${_server.uri}latest.json', 'Handshake']),
      );
    } finally {
      HttpOverrides.global = TrustingOverrides(trusting(_tls.caPem));
    }
  });

  test(
    'devrait nommer l’URL et le statut quand le registre répond 404',
    () async {
      final (sha256, path) = await _aBlob();
      _server.faults[path] = const Status(404);
      await expectLater(
        (await _client()).fetchBlob(sha256),
        _unreachable(['${_server.uri}$path', 'HTTP 404']),
      );
    },
  );

  test(
    'devrait nommer l’URL et le statut quand le registre répond 503',
    () async {
      _server.faults[DistLayout.pointerPath] = const Status(503);
      await expectLater(
        (await _client()).fetchPointer(),
        _unreachable(['${_server.uri}latest.json', 'HTTP 503']),
      );
    },
  );

  test('devrait échouer, URL nommée, quand la réponse est tronquée', () async {
    final (sha256, path) = await _aBlob();
    _server.faults[path] = const Truncate();
    await expectLater(
      (await _client()).fetchBlob(sha256),
      _unreachable(['${_server.uri}$path']),
    );
  });

  test(
    'devrait suivre une redirection https et vérifier ce qu’elle sert',
    () async {
      final (sha256, path) = await _aBlob();
      final mirror = File(p.join(_dist, 'miroir', path))
        ..parent.createSync(recursive: true);
      File(p.join(_dist, path)).copySync(mirror.path);
      addTearDown(
        () => Directory(p.join(_dist, 'miroir')).deleteSync(recursive: true),
      );
      _server.faults[path] = Redirect('/miroir/$path', code: 301);
      final bytes = await (await _client()).fetchBlob(sha256);
      expect(Sha256.ofBytes(bytes), sha256);
      expect(_server.requests.map((r) => r.path), [path, 'miroir/$path']);
    },
  );

  test('devrait refuser une redirection vers http:// en clair hors de localhost, sans la suivre', () async {
    _server.faults[DistLayout.pointerPath] = const Redirect(
      'http://registry.example.com/latest.json',
    );
    await expectLater(
      (await _client()).fetchPointer(),
      throwsA(
        isA<InsecureRegistry>().having(
          (e) => '$e',
          'message',
          allOf(
            contains('http://registry.example.com/latest.json'),
            contains('redirected from ${_server.uri}latest.json'),
            contains('(use https://)'),
          ),
        ),
      ),
    );
  });

  test(
    'devrait refuser une boucle de redirections au-delà de la borne',
    () async {
      _server.faults[DistLayout.pointerPath] = const Redirect('/latest.json');
      await expectLater(
        (await _client()).fetchPointer(),
        _unreachable(['more than ${HttpRegistry.maxRedirects} redirects']),
      );
      expect(_server.requests, hasLength(HttpRegistry.maxRedirects + 1));
    },
  );

  for (final (moment, stall) in [
    ('avant les en-têtes', const Stall()),
    ('au milieu du corps', const Stall(midBody: true)),
  ]) {
    test(
      'devrait abandonner, avec la borne et l’URL, quand le serveur se tait $moment',
      () async {
        _server.faults[DistLayout.pointerPath] = stall;
        final stopwatch = Stopwatch()..start();
        await expectLater(
          (await _client(timeout: const Duration(milliseconds: 300)))
              .fetchPointer(),
          _unreachable(['${_server.uri}latest.json', 'timed out', '0 s']),
        );
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      },
    );
  }

  test('devrait refuser un blob dont l’empreinte ne correspond pas, URL nommée (règle 1)', () async {
    final (sha256, path) = await _aBlob();
    _server.faults[path] = const Tamper();
    await expectLater(
      (await _client()).fetchBlob(sha256),
      throwsA(
        isA<IntegrityError>().having(
          (e) => '$e',
          'message',
          contains('${_server.uri}$path'),
        ),
      ),
    );
  });

  test(
    'devrait refuser un pointeur expiré servi en https (règle 12)',
    () async {
      await expectLater(
        (await _client(now: _publishedAt.add(const Duration(days: 15))))
            .fetchPointer(),
        throwsA(
          isA<PointerRefused>()
              .having((e) => e.rejection, 'rejection', PointerRejection.expired)
              .having((e) => '${e.url}', 'url', '${_server.uri}latest.json'),
        ),
      );
    },
  );

  test('devrait refuser un pointeur plus ancien que celui déjà vu pour cette URL (règle 12)', () async {
    final cache = tempDir().path;
    await (await _client(cache: cache)).fetchPointer();
    final older = tempDir().path;
    await DistWriter(older).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: _publishedAt),
      key: await testKey(),
    );
    _server.faults[DistLayout.pointerPath] = const Redirect('/ancien');
    File(p.join(_dist, 'ancien')).writeAsBytesSync(
      File(p.join(older, DistLayout.pointerPath)).readAsBytesSync(),
    );
    addTearDown(() => File(p.join(_dist, 'ancien')).deleteSync());
    await expectLater(
      (await _client(cache: cache)).fetchPointer(),
      throwsA(
        isA<PointerRefused>().having(
          (e) => e.rejection,
          'rejection',
          PointerRejection.olderThanCache,
        ),
      ),
    );
  });

  test(
    'devrait refuser http:// en clair hors de localhost avant toute connexion',
    () async {
      await expectLater(
        (await _client(url: Uri.parse('http://registry.example.com/')))
            .fetchPointer(),
        throwsA(
          isA<InsecureRegistry>().having(
            (e) => '$e',
            'message',
            contains('http://registry.example.com/latest.json'),
          ),
        ),
      );
    },
  );

  test('devrait accepter http:// en clair sur la boucle locale', () async {
    final plain = await HttpsRegistryServer.start(_dist);
    addTearDown(plain.close);
    final pointer = await (await _client(url: plain.uri)).fetchPointer();
    expect(pointer.version, 2);
    expect(transportRefusal(Uri.parse('http://localhost:8080/')), isNull);
    expect(transportRefusal(Uri.parse('http://[::1]:8080/')), isNull);
    expect(transportRefusal(Uri.parse('ftp://127.0.0.1/')), contains('ftp'));
  });

  test('devrait passer par le proxy de HTTPS_PROXY, TLS de bout en bout, et l’ignorer pour NO_PROXY', () async {
    final proxy = await ConnectProxy.start();
    addTearDown(proxy.close);
    final via = await _client(
      environment: {'HTTPS_PROXY': 'http://127.0.0.1:${proxy.port}'},
    );
    expect((await via.fetchPointer()).version, 2);
    expect(proxy.targets, ['127.0.0.1:${_server.uri.port}']);

    final direct = await _client(
      environment: {
        'HTTPS_PROXY': 'http://127.0.0.1:${proxy.port}',
        'NO_PROXY': '127.0.0.1',
      },
    );
    await direct.fetchPointer();
    expect(proxy.targets, hasLength(1));
  });

  test('ne devrait envoyer ni identifiant ni en-tête d’authentification, et seulement des chemins du registre (règle 6)', () async {
    final client = await _client();
    final pointer = await client.fetchPointer();
    final fragment = await client.fetchFragment(
      pointer,
      pointer.fragments.single,
    );
    for (final entry in fragment.entries) {
      final manifest = await client.fetchManifest(
        entry.ref,
        entry.versions.last,
      );
      for (final file in manifest.files) {
        await client.fetchBlob(file.sha256);
      }
    }
    expect(_server.requests, isNotEmpty);
    final layout = RegExp(
      r'^(latest\.json|index/[0-9a-f]{64}\.json|items/fliin/[a-z0-9-]+/[0-9.]+\.json|blobs/[0-9a-f]{2}/[0-9a-f]{64})$',
    );
    for (final request in _server.requests) {
      expect(request.method, 'GET');
      expect(request.path, matches(layout));
      expect(
        request.headers.keys.toSet(),
        everyElement(
          isIn(['user-agent', 'accept-encoding', 'host', 'content-length']),
        ),
        reason: jsonEncode(request.headers),
      );
      expect(request.headers['user-agent'], [startsWith('Dart/')]);
    }
  });

  test('devrait envoyer la clé de licence en Bearer à l’hôte Pro seulement, et jamais après une redirection vers une autre origine (règle 7)', () async {
    final other = await HttpsRegistryServer.start(_dist, tls: _tls);
    addTearDown(other.close);
    _server.license = 'cle-pro';
    final (sha256, path) = await _aBlob();
    _server.faults[path] = Redirect('${other.uri}$path');
    final client = await _client(bearer: 'cle-pro');
    await client.fetchPointer();
    expect(Sha256.ofBytes(await client.fetchBlob(sha256)), sha256);
    expect(_server.requests.map((r) => r.path), [DistLayout.pointerPath, path]);
    for (final request in _server.requests) {
      expect(request.headers['authorization'], ['Bearer cle-pro'], reason: request.path);
    }
    expect(other.requests.map((r) => r.path), [path]);
    expect(other.requests.single.headers.keys, isNot(contains('authorization')));
  });

  test('devrait garder la clé après une redirection vers la même origine', () async {
    _server.license = 'cle-pro';
    final (sha256, path) = await _aBlob();
    Directory(p.join(_dist, 'miroir', p.dirname(path))).createSync(recursive: true);
    File(p.join(_dist, path)).copySync(p.join(_dist, 'miroir', path));
    addTearDown(() => Directory(p.join(_dist, 'miroir')).deleteSync(recursive: true));
    _server.faults[path] = Redirect('/miroir/$path');
    expect(Sha256.ofBytes(await (await _client(bearer: 'cle-pro')).fetchBlob(sha256)), sha256);
    expect(_server.requests.map((r) => r.headers['authorization']), everyElement(['Bearer cle-pro']));
  });

  test('devrait rendre le refus de l’hôte Pro avec son message, et une 503 comme un registre indisponible', () async {
    _server.license = 'cle-pro';
    await expectLater(
      (await _client(bearer: 'autre')).fetchPointer(),
      throwsA(isA<LicenseRefused>()
          .having((e) => e.status, 'status', 403)
          .having((e) => e.message, 'message', contains('not valid for Fliin Pro'))),
    );
    _server.license = null;
    _server.faults[DistLayout.pointerPath] = const Problem(401, 'license_required', 'Fliin Pro needs a license key.');
    await expectLater(
      (await _client(bearer: 'cle-pro')).fetchPointer(),
      throwsA(isA<LicenseRefused>().having((e) => e.status, 'status', 401)),
    );
    await expectLater(
      (await _client()).fetchPointer(),
      _unreachable(['HTTP 401', 'Fliin Pro needs a license key.']),
      reason: 'sans clé, une 401 n’est pas un refus de licence',
    );
    _server.license = null;
    _server.faults[DistLayout.pointerPath] = const Problem(503, 'license_check_unavailable', 'The license server cannot be reached right now: try again in a minute.');
    await expectLater(
      (await _client(bearer: 'cle-pro')).fetchPointer(),
      _unreachable(['HTTP 503', 'try again in a minute']),
    );
  });

  test('devrait abandonner à l’échéance totale un serveur qui envoie un octet à chaque étape', () async {
    _server.faults[DistLayout.pointerPath] = const Trickle();
    final stopwatch = Stopwatch()..start();
    await expectLater(
      (await _client(
        timeout: const Duration(milliseconds: 500),
        deadline: const Duration(seconds: 2),
      )).fetchPointer(),
      _unreachable(['${_server.uri}latest.json', 'deadline exceeded']),
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('devrait compter les octets décompressés et abandonner une bombe gzip au plafond du document', () async {
    _server.faults[DistLayout.pointerPath] = const GzipBomb(64 * 1024 * 1024);
    await expectLater(
      (await _client()).fetchPointer(),
      _unreachable([
        '${_server.uri}latest.json',
        'larger than ${HttpRegistry.maxBytes(DistLayout.pointerPath)} bytes',
      ]),
    );
  });

  test('ne devrait jamais recopier les identifiants d’un proxy dans un message d’erreur', () async {
    try {
      await (await _client(
        environment: {'HTTPS_PROXY': 'http://alice:S3CRET-PW@127.0.0.1:80a'},
      )).fetchPointer();
      fail('le proxy invalide devait échouer');
    } on RegistryUnreachable catch (e) {
      expect('$e', isNot(contains('S3CRET-PW')));
      expect('$e', isNot(contains('alice')));
    }
    expect(
      withoutCredentials('PROXY alice:S3CRET-PW@proxy:8080'),
      'PROXY ***@proxy:8080',
    );
  });

  test(
    'devrait refuser qu’un registre distant redirige vers la boucle locale',
    () async {
      final proxy = await ConnectProxy.start(to: _server.uri.port);
      addTearDown(proxy.close);
      Future<RegistryClient> remote() => _client(
        url: Uri.parse('https://registry.example.com/'),
        environment: {'HTTPS_PROXY': '127.0.0.1:${proxy.port}'},
      );
      expect((await (await remote()).fetchPointer()).version, 2);
      _server.faults[DistLayout.pointerPath] = Redirect(
        '${_server.uri}latest.json',
      );
      await expectLater(
        (await remote()).fetchPointer(),
        throwsA(
          isA<InsecureRegistry>().having(
            (e) => '$e',
            'message',
            contains('to the loopback address refused'),
          ),
        ),
      );
    },
  );
}

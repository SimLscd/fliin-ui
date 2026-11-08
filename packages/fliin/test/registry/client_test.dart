import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/client.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support.dart';

final _publishedAt = DateTime.utc(2026, 10, 18, 9);
final _dayAfter = _publishedAt.add(const Duration(days: 1));

/// Un registre dont le pointeur expire au bout de 14 jours (règle 12), sauf
/// [lifetime] nul : celui d'une publication.
Future<String> _dist({
  int version = 1,
  String? out,
  Duration? lifetime = const Duration(days: 14),
}) async {
  final dist = out ?? tempDir().path;
  await DistWriter(dist).write(
    SourceRegistry.read(sourceRoot),
    stamp: BuildStamp(
      version: version,
      publishedAt: _publishedAt,
      lifetime: lifetime,
    ),
    key: await testKey(),
  );
  return dist;
}

Future<RegistryClient> _client(
  String dist, {
  String? cache,
  DateTime? now,
}) async => RegistryClient.forUrl(
  Directory(dist).uri,
  Ed25519PointerVerifier([(await testKey()).publicKey]),
  cacheRoot: cache ?? tempDir().path,
  clock: () => now ?? _dayAfter,
);

Matcher _refusedFor(PointerRejection reason) => throwsA(
  isA<PointerRefused>().having((e) => e.rejection, 'rejection', reason),
);

Future<void> _resign(
  String dist,
  IndexPointer Function(IndexPointer pointer) change,
) async {
  final pointer = await (await _client(dist)).fetchPointer();
  final signed = await (await testKey()).sign(change(pointer));
  File(p.join(dist, DistLayout.pointerPath))
      .writeAsStringSync(canonicalJson(signed.toJson()));
}

IndexPointer _with(
  IndexPointer pointer, {
  List<FragmentRef>? fragments,
  List<ItemRef>? yanked,
  Version? minCli,
}) => IndexPointer(
  version: pointer.version,
  publishedAt: pointer.publishedAt,
  expires: pointer.expires,
  minCli: minCli ?? pointer.minCli,
  fragments: fragments ?? pointer.fragments,
  yanked: yanked ?? pointer.yanked,
);

File _cacheFile(String cache, String dist) => File(
  p.join(
    cache,
    Sha256.ofString('${Directory(dist).uri}').hex.substring(0, 16),
    'pointer.version',
  ),
);

Future<(ItemManifest, Uint8List)> _button(RegistryClient client) async {
  final pointer = await client.fetchPointer();
  final fragment = await client.fetchFragment(
    pointer,
    pointer.fragments.single,
  );
  final entry = fragment.entries.singleWhere((e) => e.ref.name == 'button');
  final manifest = await client.fetchManifest(entry.ref, entry.versions.single);
  return (manifest, await client.fetchBlob(manifest.files.single.sha256));
}

void main() {
  test('devrait lire pointeur, fragment, manifeste et blob quand le registre est un dossier file://', () async {
    final (manifest, blob) = await _button(await _client(await _dist()));
    expect(manifest.name, 'button');
    expect(
      utf8.decode(blob),
      File(p.join(sourceRoot, 'lib/components/button/fl_button.dart'))
          .readAsStringSync(),
    );
  });

  test('devrait rendre les mêmes octets par HTTP que par file:// quand le dossier est servi', () async {
    final dist = await _dist();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final file = File(p.joinAll([dist, ...request.uri.pathSegments]));
      if (file.existsSync()) {
        request.response.add(file.readAsBytesSync());
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final http = RegistryClient.forUrl(
      Uri.parse('http://127.0.0.1:${server.port}/'),
      Ed25519PointerVerifier([(await testKey()).publicKey]),
      cacheRoot: tempDir().path,
      clock: () => _dayAfter,
    );
    expect(http, isA<HttpRegistry>());
    final (viaHttp, blobViaHttp) = await _button(http);
    final (viaFile, blobViaFile) = await _button(await _client(dist));
    expect(viaHttp.toJson(), viaFile.toJson());
    expect(blobViaHttp, blobViaFile);

    File(p.join(dist, DistLayout.pointerPath)).deleteSync();
    await expectLater(http.fetchPointer(), throwsA(isA<RegistryUnreachable>()));
  });

  test(
    'devrait refuser le pointeur quand un octet de latest.json change',
    () async {
      final dist = await _dist();
      final latest = File(p.join(dist, DistLayout.pointerPath));
      latest.writeAsStringSync(
        latest.readAsStringSync().replaceFirst(
          r'\"version\":1',
          r'\"version\":2',
        ),
      );
      await expectLater(
        (await _client(dist)).fetchPointer(),
        _refusedFor(PointerRejection.badSignature),
      );
    },
  );

  test('devrait refuser le pointeur quand il est expiré (règle 12)', () async {
    final client = await _client(
      await _dist(),
      now: _publishedAt.add(const Duration(days: 14)),
    );
    await expectLater(
      client.fetchPointer(),
      _refusedFor(PointerRejection.expired),
    );
  });

  test('devrait accepter des années plus tard un pointeur sans date d’expiration, celui d’une publication (ADR 0020 §11)', () async {
    final client = await _client(
      await _dist(lifetime: null),
      now: _publishedAt.add(const Duration(days: 3 * 365)),
    );
    final pointer = await client.fetchPointer();
    expect(pointer.version, 1);
    expect(pointer.expires, isNull);
  });

  test('devrait refuser le pointeur quand sa version est inférieure à la dernière acceptée, en nommant la version vue, la version reçue et le cache (règle 12 ; tour 3, R4)', () async {
    final cache = tempDir().path;
    final dist = await _dist(version: 5);
    expect(
      (await (await _client(dist, cache: cache)).fetchPointer()).version,
      5,
    );
    await _dist(version: 4, out: dist);
    final seen = _cacheFile(cache, dist);
    await expectLater(
      (await _client(dist, cache: cache)).fetchPointer(),
      throwsA(
        isA<PointerRefused>()
            .having(
              (e) => e.rejection,
              'rejection',
              PointerRejection.olderThanCache,
            )
            .having((e) => e.replay, 'replay', (
              seen: 5,
              received: 4,
              cache: seen.path,
            ))
            .having(
              (e) => '$e',
              'message',
              allOf(
                contains('received version 4'),
                contains('already saw 5'),
                contains(seen.path),
              ),
            ),
      ),
    );
    expect((await (await _client(dist)).fetchPointer()).version, 4);
  });

  test('devrait refuser le pointeur quand minCli dépasse la version du CLI, pour tout lecteur du registre (synthèse #9)', () async {
    final dist = await _dist();
    await _resign(dist, (pointer) => _with(pointer, minCli: Version(99, 0, 0)));
    await expectLater(
      (await _client(dist)).fetchPointer(),
      throwsA(
        isA<CliTooOld>().having((e) => e.minCli, 'minCli', Version(99, 0, 0)),
      ),
    );
    final newer = RegistryClient.forUrl(
      Directory(dist).uri,
      Ed25519PointerVerifier([(await testKey()).publicKey]),
      cacheRoot: tempDir().path,
      clock: () => _dayAfter,
      cliVersion: Version(99, 0, 0),
    );
    expect((await newer.fetchPointer()).version, 1);
  });

  test('devrait retenir la plus haute version acceptée sans fichier temporaire restant, et refuser un cache vide, sans droit de lecture ou qui est un dossier au lieu de l\'ignorer (synthèse #11, règle 12 ; tour 3, R6)', () async {
    final cache = tempDir().path;
    final dist = await _dist(version: 5);
    await (await _client(dist, cache: cache)).fetchPointer();
    final seen = _cacheFile(cache, dist);
    expect(seen.readAsStringSync(), '5');
    expect(seen.parent.listSync().map((e) => p.basename(e.path)), [
      'pointer.version',
    ]);

    final unreadable = throwsA(
      isA<CacheUnreadable>().having((e) => e.path, 'path', seen.path),
    );
    await _dist(version: 4, out: dist);
    seen.writeAsStringSync('');
    await expectLater(
      (await _client(dist, cache: cache)).fetchPointer(),
      unreadable,
    );
    expect(seen.readAsStringSync(), '');

    seen.writeAsStringSync('5');
    Process.runSync('chmod', ['000', seen.path]);
    addTearDown(() => Process.runSync('chmod', ['644', seen.path]));
    await expectLater(
      (await _client(dist, cache: cache)).fetchPointer(),
      unreadable,
    );

    Process.runSync('chmod', ['644', seen.path]);
    seen.deleteSync();
    Directory(seen.path).createSync();
    await expectLater(
      (await _client(dist, cache: cache)).fetchPointer(),
      unreadable,
    );
    expect(seen.parent.listSync().map((e) => p.basename(e.path)), [
      'pointer.version',
    ]);
  });

  test('devrait lever une IntegrityError et ne rien mettre en cache quand un blob est altéré', () async {
    final dist = await _dist();
    final cache = tempDir().path;
    final client = await _client(dist, cache: cache);
    final (manifest, _) = await _button(await _client(dist));
    final sha256 = manifest.files.single.sha256;
    File(p.join(dist, DistLayout.blobPath(sha256)))
        .writeAsStringSync('altéré', mode: FileMode.append);
    await expectLater(
      client.fetchBlob(sha256),
      throwsA(
        isA<IntegrityError>().having((e) => e.expected, 'expected', sha256),
      ),
    );
    expect(
      File(p.join(cache, DistLayout.blobPath(sha256))).existsSync(),
      isFalse,
    );
  });

  test('devrait lever une IntegrityError quand un manifeste ne correspond plus à l\'index', () async {
    final dist = await _dist();
    final manifest = File(
      p.join(
        dist,
        DistLayout.manifestPath(
          ItemRef('button'),
          (await _button(await _client(dist))).$1.version,
        ),
      ),
    );
    manifest.writeAsStringSync(
      manifest.readAsStringSync().replaceFirst('Button', 'Button!'),
    );
    await expectLater(
      _button(await _client(dist)),
      throwsA(isA<IntegrityError>()),
    );
  });

  test('devrait relire un blob depuis le cache et le revérifier quand le cache est altéré', () async {
    final dist = await _dist();
    final cache = tempDir().path;
    final client = await _client(dist, cache: cache);
    final (manifest, original) = await _button(client);
    final sha256 = manifest.files.single.sha256;
    File(p.join(dist, DistLayout.blobPath(sha256))).deleteSync();
    expect(await client.fetchBlob(sha256), original);

    await _dist(out: dist);
    final cached = File(p.join(cache, DistLayout.blobPath(sha256)))
      ..writeAsStringSync('altéré');
    expect(await client.fetchBlob(sha256), original);
    expect(cached.readAsBytesSync(), original);
  });

  test('devrait marquer retirées les versions que le pointeur retire, et elles seules', () async {
    final dist = await _dist();
    final pointer = await (await _client(dist)).fetchPointer();
    final fragmentFile = File(p.join(dist, pointer.fragments.single.path));
    final json =
        jsonDecode(fragmentFile.readAsStringSync()) as Map<String, Object?>;
    for (final entry
        in (json['entries']! as List<Object?>).cast<Map<String, Object?>>()) {
      if (entry['ref'] == 'core') {
        (entry['versions']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .single['status'] = {
          'yanked': 'dans le fragment',
        };
      }
    }
    final bytes = utf8.encode(canonicalJson(json));
    fragmentFile.writeAsBytesSync(bytes);
    await _resign(
      dist,
      (pointer) => _with(
        pointer,
        fragments: [
          (path: pointer.fragments.single.path, sha256: Sha256.ofBytes(bytes)),
        ],
        yanked: [ItemRef.parse('button@${sourceVersion('button')}')],
      ),
    );

    final client = await _client(dist);
    final fresh = await client.fetchPointer();
    final entries = (await client.fetchFragment(
      fresh,
      fresh.fragments.single,
    )).entries;
    final status = {
      for (final e in entries) e.ref.name: e.versions.single.status,
    };
    expect(status['button'], isA<Yanked>());
    expect(status['core'], isA<Published>());
  });
}

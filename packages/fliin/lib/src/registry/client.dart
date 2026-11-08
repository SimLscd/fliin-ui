import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../cli_version.dart' as cli;

/// Un registre statique lu par URL. Tout remonte au pointeur signé : un
/// fragment, un manifeste ou un blob dont l'empreinte diffère de celle qui le
/// désigne lève une [IntegrityError] et n'est jamais rendu (règle 1).
abstract base class RegistryClient {
  RegistryClient(
    Uri url,
    this.verifier, {
    String? cacheRoot,
    DateTime Function()? clock,
    Version? cliVersion,
  }) : url = url.path.endsWith('/') ? url : url.replace(path: '${url.path}/'),
       _cache = cacheRoot ?? defaultCacheRoot,
       _clock = clock ?? DateTime.now,
       _cliVersion = cliVersion ?? Version.parse(cli.cliVersion);

  /// `file://` lit un dossier, tout autre schéma passe par HTTP, avec
  /// [bearer] pour l'hôte Pro.
  factory RegistryClient.forUrl(
    Uri url,
    PointerVerifier verifier, {
    String? cacheRoot,
    DateTime Function()? clock,
    Version? cliVersion,
    String? bearer,
  }) => url.isScheme('file')
      ? FileRegistry(
          url,
          verifier,
          cacheRoot: cacheRoot,
          clock: clock,
          cliVersion: cliVersion,
        )
      : HttpRegistry(
          url,
          verifier,
          cacheRoot: cacheRoot,
          clock: clock,
          cliVersion: cliVersion,
          bearer: bearer,
        );

  static String get defaultCacheRoot => p.join(
    Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path,
    '.cache',
    'fliin',
  );

  final Uri url;
  final PointerVerifier verifier;
  final String _cache;
  final DateTime Function() _clock;
  final Version _cliVersion;

  /// Les octets de [path], relatif à [url].
  Future<Uint8List> fetch(String path);

  /// Applique la règle 12 avec la plus haute version déjà acceptée pour cette
  /// URL, puis la retient ; refuse un pointeur dont `minCli` dépasse ce CLI,
  /// pour tous les chemins qui lisent le registre.
  Future<IndexPointer> fetchPointer() async {
    final signed = _parse(
      DistLayout.pointerPath,
      await fetch(DistLayout.pointerPath),
      SignedPointer.fromJson,
    );
    final seen = File(
      p.join(
        _cache,
        Sha256.ofString('$url').hex.substring(0, 16),
        'pointer.version',
      ),
    );
    final cached = _cachedVersion(seen);
    final PointerDecision decision;
    try {
      decision = await signed.open(
        verifier,
        cachedVersion: cached,
        now: _clock(),
      );
    } on ManifestError catch (e) {
      throw InvalidDocument(url.resolve(DistLayout.pointerPath), '$e');
    }
    switch (decision) {
      case PointerRejected(reason: PointerRejection.olderThanCache):
        throw PointerRefused(
          url.resolve(DistLayout.pointerPath),
          PointerRejection.olderThanCache,
          replay: (
            seen: cached!,
            received: IndexPointer.fromJson(jsonDecode(signed.payload)).version,
            cache: seen.path,
          ),
        );
      case PointerRejected(:final reason):
        throw PointerRefused(url.resolve(DistLayout.pointerPath), reason);
      case PointerAccepted(:final pointer):
        if (pointer.minCli > _cliVersion) {
          throw CliTooOld(
            url.resolve(DistLayout.pointerPath),
            pointer.minCli,
            _cliVersion,
          );
        }
        if (cached == null || pointer.version > cached) {
          try {
            seen.parent.createSync(recursive: true);
            File('${seen.path}.$pid')
              ..writeAsStringSync('${pointer.version}')
              ..renameSync(seen.path);
          } on FileSystemException catch (e) {
            throw CacheUnreadable(url, seen.path, e.osError?.message);
          }
        }
        return pointer;
    }
  }

  /// Un cache vide, illisible, sans droit de lecture ou qui est un dossier
  /// n'est pas « jamais vu » : il désactiverait l'anti-retour en silence.
  int? _cachedVersion(File seen) {
    if (FileSystemEntity.typeSync(seen.path) == FileSystemEntityType.notFound) {
      return null;
    }
    final String text;
    try {
      text = seen.readAsStringSync();
    } on FileSystemException catch (e) {
      throw CacheUnreadable(url, seen.path, e.osError?.message);
    }
    return int.tryParse(text.trim()) ??
        (throw CacheUnreadable(url, seen.path, 'not an integer'));
  }

  /// Les versions que [pointer] retire passent en [Yanked], les autres en
  /// [Published] : le pointeur est la seule source du retrait.
  Future<IndexFragment> fetchFragment(
    IndexPointer pointer,
    FragmentRef fragment,
  ) async {
    final parsed = _parse(
      fragment.path,
      await _verified(fragment.path, fragment.sha256),
      IndexFragment.fromJson,
    );
    final yanked = pointer.yanked.toSet();
    return IndexFragment([
      for (final entry in parsed.entries)
        IndexEntry(
          ref: entry.ref,
          type: entry.type,
          title: entry.title,
          description: entry.description,
          categories: entry.categories,
          meta: entry.meta,
          versions: [
            for (final release in entry.versions)
              IndexVersion(
                version: release.version,
                manifestSha256: release.manifestSha256,
                flutter: release.flutter,
                registryDependencies: release.registryDependencies,
                status: yanked.contains(entry.ref.at(release.version))
                    ? const Yanked('yanked by the registry')
                    : const Published(),
              ),
          ],
        ),
    ]);
  }

  Future<ItemManifest> fetchManifest(ItemRef ref, IndexVersion release) async {
    final path = DistLayout.manifestPath(ref, release.version);
    return _parse(
      path,
      await _verified(path, release.manifestSha256),
      ItemManifest.fromJson,
    );
  }

  /// Le cache disque, partagé entre registres puisqu'adressé par empreinte,
  /// est revérifié à chaque lecture.
  Future<Uint8List> fetchBlob(Sha256 sha256) async {
    final cached = File(p.join(_cache, DistLayout.blobPath(sha256)));
    if (cached.existsSync()) {
      final bytes = cached.readAsBytesSync();
      if (Sha256.ofBytes(bytes) == sha256) return bytes;
      cached.deleteSync();
    }
    final bytes = await _verified(DistLayout.blobPath(sha256), sha256);
    final partial = File('${cached.path}.$pid')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    partial.renameSync(cached.path);
    return bytes;
  }

  Future<Uint8List> _verified(String path, Sha256 expected) async {
    final bytes = await fetch(path);
    final actual = Sha256.ofBytes(bytes);
    if (actual != expected) {
      throw IntegrityError(url.resolve(path), expected, actual);
    }
    return bytes;
  }

  T _parse<T>(
    String path,
    Uint8List bytes,
    T Function(Object? json, String at) fromJson,
  ) {
    try {
      return fromJson(jsonDecode(utf8.decode(bytes)), r'$');
    } on FormatException catch (e) {
      throw InvalidDocument(url.resolve(path), 'unreadable JSON: ${e.message}');
    } on ManifestError catch (e) {
      throw InvalidDocument(url.resolve(path), '$e');
    }
  }
}

final class FileRegistry extends RegistryClient {
  FileRegistry(
    super.url,
    super.verifier, {
    super.cacheRoot,
    super.clock,
    super.cliVersion,
  });

  @override
  Future<Uint8List> fetch(String path) async {
    final target = url.resolve(path);
    try {
      return await File.fromUri(target).readAsBytes();
    } on FileSystemException catch (e) {
      throw RegistryUnreachable(target, e.osError?.message ?? e.message);
    }
  }
}

/// `https://`, ou `http://` sur la boucle locale. Le proxy vient de
/// `HTTPS_PROXY`, `HTTP_PROXY` et `NO_PROXY` ([environment], défaut : celui
/// du processus) ; TLS reste de bout en bout à travers lui. Aucun cookie
/// n'est envoyé, et aucun en-tête d'authentification hors [bearer] : le
/// gratuit est anonyme (règle 7, ADR 0020 §5).
final class HttpRegistry extends RegistryClient {
  HttpRegistry(
    super.url,
    super.verifier, {
    super.cacheRoot,
    super.clock,
    super.cliVersion,
    this.timeout = defaultTimeout,
    this.deadline = defaultDeadline,
    this.environment,
    this.bearer,
  });

  /// La borne de chaque étape : connexion et TLS, en-têtes, puis chaque
  /// morceau du corps. Un serveur qui se tait plus longtemps est abandonné.
  static const defaultTimeout = Duration(seconds: 30);

  /// La borne d'une requête entière, redirections comprises : un serveur qui
  /// envoie un octet par étape ne la retient pas plus longtemps.
  static const defaultDeadline = Duration(minutes: 2);

  /// Au-delà, une boucle de redirections est refusée.
  static const maxRedirects = 5;

  /// Les octets qu'un document peut faire une fois décompressé, par sorte.
  /// Un pointeur fait moins d'1 Kio ; un fragment, environ 2 Kio par
  /// élément et par version, 8 Mio laissent plus de 3 000 versions ; un
  /// manifeste, quelques Kio ; un blob est un fichier source ou un PNG de
  /// quelques centaines de Kio, 16 Mio laissent une police ou une image.
  static int maxBytes(String path) => switch (path.split('/').first) {
    DistLayout.pointerPath => 64 * 1024,
    'index' => 8 * 1024 * 1024,
    'items' => 1024 * 1024,
    _ => 16 * 1024 * 1024,
  };

  final Duration timeout;
  final Duration deadline;
  final Map<String, String>? environment;

  /// La clé de licence, envoyée en `authorization: Bearer` à l'origine de
  /// [url] seulement : jamais après une redirection vers une autre.
  final String? bearer;

  @override
  Future<Uint8List> fetch(String path) async {
    final first = url.resolve(path);
    var target = first;
    String at(Uri uri) => uri == first ? '' : ' (redirected from $first)';
    final limit = maxBytes(path);
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = (uri) =>
          HttpClient.findProxyFromEnvironment(uri, environment: environment);
    Future<Uint8List> request() async {
      for (var hops = 0; ; hops++) {
        if (transportRefusal(target, from: first) case final refusal?) {
          throw InsecureRegistry(target, '$refusal${at(target)}');
        }
        final request = await client.getUrl(target).timeout(timeout);
        request.followRedirects = false;
        if (bearer case final key? when _sameOrigin(target, first)) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
        }
        final response = await request.close().timeout(timeout);
        if (response.isRedirect) {
          await response.drain<void>();
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null || hops == maxRedirects) {
            throw RegistryUnreachable(
              target,
              location == null
                  ? 'HTTP ${response.statusCode} without Location${at(target)}'
                  : 'more than $maxRedirects redirects from $first',
            );
          }
          target = target.resolve(location);
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          final message = await _serverMessage(response);
          if (bearer != null &&
              (response.statusCode == HttpStatus.unauthorized ||
                  response.statusCode == HttpStatus.forbidden)) {
            throw LicenseRefused(target, response.statusCode, message);
          }
          throw RegistryUnreachable(
            target,
            'HTTP ${response.statusCode}${at(target)}'
            '${message == null ? '' : ': $message'}',
          );
        }
        final body = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(timeout)) {
          body.add(chunk);
          if (body.length > limit) {
            throw RegistryUnreachable(
              target,
              'response larger than $limit bytes once decompressed, '
              'dropped${at(target)}',
            );
          }
        }
        return body.takeBytes();
      }
    }

    try {
      return await request().timeout(
        deadline,
        onTimeout: () => throw RegistryUnreachable(
          target,
          'deadline exceeded: the request took more than ${deadline.inSeconds} s'
          '${at(target)}',
        ),
      );
    } on TimeoutException {
      throw RegistryUnreachable(
        target,
        'timed out: nothing received in ${timeout.inSeconds} s${at(target)}',
      );
    } on IOException catch (e) {
      throw RegistryUnreachable(
        target,
        '${withoutCredentials('$e')}${at(target)}',
      );
    } finally {
      client.close(force: true);
    }
  }
}

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

/// Le `message` d'une erreur JSON `{"error", "message"}`, comme le Worker du
/// registre Pro les rend, lu sur 4 Kio au plus ; nul pour tout autre corps.
Future<String?> _serverMessage(HttpClientResponse response) async {
  final body = BytesBuilder(copy: false);
  try {
    await for (final chunk in response) {
      body.add(chunk);
      if (body.length > 4096) return null;
    }
    if (jsonDecode(utf8.decode(body.takeBytes()))
        case {'message': final String message} when message.isNotEmpty) {
      return message;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// [text] sans les identifiants `utilisateur:mot-de-passe@` qu'une URL de
/// proxy peut porter et qu'une erreur de `dart:io` recopie.
String withoutCredentials(String text) =>
    text.replaceAll(RegExp(r'[^\s/@]+:[^\s/@]+@'), '***@');

/// Pourquoi [url] n'est pas un transport acceptable, null s'il l'est. En
/// clair hors de la boucle locale, la signature garde l'intégrité, mais
/// n'importe quel réseau voit quels éléments le projet installe et peut
/// servir un pointeur gelé jusqu'à son expiration : refusé, pas averti, car
/// un avertissement se perd dans la sortie d'un agent. Un registre distant
/// ne redirige jamais vers la boucle locale de la machine qui le lit
/// ([from] : l'URL demandée avant les redirections) (ADR 0011).
String? transportRefusal(Uri url, {Uri? from}) {
  if (from != null && isLoopbackHost(url.host) && !isLoopbackHost(from.host)) {
    return 'redirect from $from to the loopback address refused';
  }
  if (url.isScheme('https')) return null;
  if (!url.isScheme('http')) {
    return 'scheme ${url.scheme}: is not supported. Use https:// or file://';
  }
  if (isLoopbackHost(url.host)) return null;
  return 'plain http:// is refused outside localhost (use https://)';
}

sealed class RegistryError implements Exception {
  const RegistryError(this.url);

  /// Le document fautif.
  final Uri url;

  String get reason;

  @override
  String toString() => '$url: $reason';
}

final class RegistryUnreachable extends RegistryError {
  const RegistryUnreachable(super.url, this.reason);

  @override
  final String reason;
}

/// L'hôte Pro refuse la clé de licence (401 ou 403), avec son message.
final class LicenseRefused extends RegistryError {
  const LicenseRefused(super.url, this.status, this.message);

  final int status;
  final String? message;

  @override
  String get reason => 'HTTP $status${message == null ? '' : ': $message'}';
}

/// Un transport que [transportRefusal] refuse, au départ ou après une
/// redirection.
final class InsecureRegistry extends RegistryError {
  const InsecureRegistry(super.url, this.reason);

  @override
  final String reason;
}

final class InvalidDocument extends RegistryError {
  const InvalidDocument(super.url, this.reason);

  @override
  final String reason;
}

final class PointerRefused extends RegistryError {
  const PointerRefused(super.url, this.rejection, {this.replay});

  final PointerRejection rejection;

  /// Pour [PointerRejection.olderThanCache] : la version déjà vue pour cette
  /// URL, celle reçue, et le fichier du cache anti-retour qui les compare.
  final ({int seen, int received, String cache})? replay;

  @override
  String get reason => switch (rejection) {
    PointerRejection.badSignature => 'invalid signature',
    PointerRejection.expired => 'expired pointer',
    PointerRejection.olderThanCache =>
      'pointer older than the last one accepted${describeReplay(replay)}',
    PointerRejection.unknownKey => 'unknown signing key',
  };
}

String describeReplay(({int seen, int received, String cache})? replay) =>
    switch (replay) {
      null => '',
      (:final seen, :final received, :final cache) =>
        ' (received version $received, already saw $seen for this URL. '
            'The anti-replay cache is $cache)',
    };

/// Le pointeur est authentique mais exige un CLI plus récent (`minCli`).
final class CliTooOld extends RegistryError {
  const CliTooOld(super.url, this.minCli, this.cliVersion);

  final Version minCli;
  final Version cliVersion;

  @override
  String get reason =>
      'the registry requires fliin $minCli or later. This CLI is '
      '$cliVersion. Run dart pub global activate fliin';
}

/// Le cache anti-retour de cette URL ne se lit pas ou ne s'écrit pas.
final class CacheUnreadable extends RegistryError {
  const CacheUnreadable(super.url, this.path, [this.detail]);

  final String path;
  final String? detail;

  @override
  String get reason =>
      'the anti-replay cache cannot be read${detail == null ? '' : ' ($detail)'}. '
      'Delete $path, then run the command again';
}

final class IntegrityError extends RegistryError {
  const IntegrityError(super.url, this.expected, this.actual);

  final Sha256 expected;
  final Sha256 actual;

  @override
  String get reason => 'checksum ${actual.value}, expected ${expected.value}';
}

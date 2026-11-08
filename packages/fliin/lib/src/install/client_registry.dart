import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';

import '../registry/client.dart' as client;
import '../registry/signing.dart';
import '../license/license_store.dart';
import '../registry/official.dart';
import 'registry_port.dart';

/// Le port [Registry] de l'installeur, servi par le client de `lib/src/registry/`.
///
/// Le client exige le pointeur pour lire un fragment et l'[IndexVersion] pour
/// lire un manifeste : cet adaptateur retient ce qu'il a déjà lu pour que
/// l'installeur n'ait à connaître ni l'un ni l'autre.
final class ClientRegistry implements Registry {
  ClientRegistry(this._client, {this.servesPro = true});

  final client.RegistryClient _client;

  @override
  final bool servesPro;
  IndexPointer? _pointer;
  final Map<String, IndexVersion> _releases = {};

  @override
  Future<IndexPointer> fetchPointer() => _guard(() async {
    final pointer = await _client.fetchPointer();
    _pointer = pointer;
    return pointer;
  });

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) => _guard(() async {
    final pointer = _pointer ?? await fetchPointer();
    final parsed = await _client.fetchFragment(pointer, fragment);
    for (final entry in parsed.entries) {
      for (final release in entry.versions) {
        _releases[_key(entry.ref, release.version)] = release;
      }
    }
    return parsed;
  });

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) =>
      _guard(() async {
        var release = _releases[_key(ref, version)];
        if (release == null) {
          final pointer = _pointer ?? await fetchPointer();
          for (final fragment in pointer.fragments) {
            await fetchFragment(fragment);
          }
          release = _releases[_key(ref, version)];
        }
        if (release == null) {
          throw MissingArtifact(DistLayout.manifestPath(ref, version));
        }
        return _client.fetchManifest(ref, release);
      });

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) =>
      _guard(() => _client.fetchBlob(sha256));

  static String _key(ItemRef ref, Version version) => '$ref@$version';

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on client.RegistryError catch (e) {
      throw switch (e) {
        client.IntegrityError(:final url, :final expected, :final actual) =>
          IntegrityFailure(expected, actual, url: url),
        client.PointerRefused(:final url, :final rejection, :final replay) =>
          PointerRejectedFailure(rejection, replay: replay, url: url),
        client.CliTooOld(:final minCli, :final cliVersion) => CliTooOldFailure(
          minCli,
          cliVersion,
        ),
        client.CacheUnreadable(:final path, :final detail) =>
          CacheUnreadableFailure(path, detail),
        client.LicenseRefused(:final message) => ProLicenseRefused(message),
        client.InvalidDocument(:final url, :final reason) => MissingArtifact(
          '$url ($reason)',
        ),
        client.RegistryUnreachable(:final url, :final reason) ||
        client.InsecureRegistry(
          :final url,
          :final reason,
        ) => RegistryUnreachable('$url: $reason'),
      };
    }
  }
}

/// Ouvre le registre `@fliin` de `fliin.yaml`, sinon le registre officiel
/// (ADR 0020 §5) : sur son hôte Pro, avec la clé de licence de [licenses],
/// ou sur son hôte public, qui ne sert pas le code Pro.
OpenRegistry clientRegistryOpener({
  OfficialRegistry? official,
  LicenseStore? licenses,
}) => (source) async {
  final registry = official ?? OfficialRegistry.fliin;
  if (source != null) {
    return ClientRegistry(
      client.RegistryClient.forUrl(
        source.url,
        Ed25519PointerVerifier([...registry.keys, ...source.trustedKeys]),
      ),
    );
  }
  final license = (licenses ?? LicenseStore()).read();
  final url = license == null ? registry.publicUrl : registry.proUrl;
  if (registry.keys.isEmpty) throw NoOfficialKey(url);
  return ClientRegistry(
    client.RegistryClient.forUrl(
      url,
      Ed25519PointerVerifier(registry.keys),
      bearer: license?.key,
    ),
    servesPro: license != null,
  );
};

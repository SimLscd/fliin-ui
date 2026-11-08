import 'dart:convert';
import 'dart:typed_data';

import 'package:pub_semver/pub_semver.dart';

import 'item_ref.dart';
import 'json_node.dart';
import 'manifest.dart';
import 'manifest_error.dart';
import 'sha256.dart';

/// Une version publiée telle que la résolution la voit : sans télécharger le
/// manifeste, d'où les `registryDependencies` recopiées ici.
final class IndexVersion {
  const IndexVersion({
    required this.version,
    required this.manifestSha256,
    required this.flutter,
    required this.registryDependencies,
    this.status = const Published(),
  });

  factory IndexVersion.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return IndexVersion(
      version: node['version'].parse(Version.parse, InvalidVersion.new),
      manifestSha256: node['manifestSha256'].parse(
        Sha256.parse,
        InvalidSha256.new,
      ),
      flutter: node['flutter'].parse(
        VersionConstraint.parse,
        InvalidVersion.new,
      ),
      registryDependencies: [
        for (final dependency
            in node['registryDependencies'].orElse(const []).items)
          dependency.parse(ItemDependency.parse, MalformedReference.new),
      ],
      status: node['status'].read(ItemStatus.fromJson),
    );
  }

  final Version version;
  final Sha256 manifestSha256;
  final VersionConstraint flutter;
  final List<ItemDependency> registryDependencies;
  final ItemStatus status;

  Map<String, Object?> toJson() => {
    'version': '$version',
    'manifestSha256': manifestSha256.value,
    'flutter': '$flutter',
    'registryDependencies': [
      for (final dependency in registryDependencies) '$dependency',
    ],
    'status': ?status.toJson(),
  };
}

/// Le résumé d'un élément pour la recherche et la résolution.
final class IndexEntry {
  const IndexEntry({
    required this.ref,
    required this.type,
    required this.title,
    required this.description,
    required this.categories,
    required this.meta,
    required this.versions,
  });

  factory IndexEntry.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return IndexEntry(
      ref: node['ref'].parse(ItemRef.parseUnversioned, MalformedReference.new),
      type: node['type'].oneOf(ItemType.values, (type) => type.wire),
      title: node['title'].string,
      description: node['description'].string,
      categories: node['categories'].orElse(const []).strings,
      meta: node['meta'].read(ItemMeta.fromJson),
      versions: [
        for (final version in node['versions'].items)
          version.read(IndexVersion.fromJson),
      ],
    );
  }

  /// Sans version : les versions sont dans [versions].
  final ItemRef ref;
  final ItemType type;
  final String title;
  final String description;
  final List<String> categories;
  final ItemMeta meta;
  final List<IndexVersion> versions;

  Map<String, Object?> toJson() => {
    'ref': '$ref',
    'type': type.wire,
    'title': title,
    'description': description,
    'categories': categories,
    'meta': meta.toJson(),
    'versions': [for (final version in versions) version.toJson()],
  };
}

/// `index/<nom>.json`, que le pointeur désigne par son empreinte.
final class IndexFragment {
  const IndexFragment(this.entries);

  factory IndexFragment.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    node['schema'].expectFormat(schema);
    return IndexFragment([
      for (final entry in node['entries'].items)
        entry.read(IndexEntry.fromJson),
    ]);
  }

  static const schema = 1;

  final List<IndexEntry> entries;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'entries': [for (final entry in entries) entry.toJson()],
  };
}

typedef FragmentRef = ({String path, Sha256 sha256});

/// `latest.json`, écrit en dernier : rien n'est installé sans remonter à un
/// pointeur accepté par [SignedPointer.open].
final class IndexPointer {
  IndexPointer({
    required this.version,
    required DateTime publishedAt,
    DateTime? expires,
    required this.minCli,
    required this.fragments,
    required this.yanked,
  }) : publishedAt = publishedAt.toUtc(),
       expires = expires?.toUtc();

  factory IndexPointer.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    node['schema'].expectFormat(schema);
    return IndexPointer(
      version: node['version'].integer,
      publishedAt: node['publishedAt'].utc,
      expires: node['expires'].isAbsent ? null : node['expires'].utc,
      minCli: node['minCli'].parse(Version.parse, InvalidVersion.new),
      fragments: [
        for (final fragment in node['fragments'].items)
          (
            path: fragment['path'].relativePath,
            sha256: fragment['sha256'].parse(Sha256.parse, InvalidSha256.new),
          ),
      ],
      yanked: [
        for (final ref in node['yanked'].orElse(const []).items)
          ref.parse(ItemRef.parseVersioned, MalformedReference.new),
      ],
    );
  }

  static const schema = 1;

  /// Croît à chaque publication ; un pointeur plus ancien que le cache est un
  /// rejeu (règle 12).
  final int version;
  final DateTime publishedAt;

  /// Nulle : le pointeur n'expire pas. Le registre officiel n'en porte plus
  /// (ADR 0020 §11) ; un pointeur qui en porte une reste refusé passé cette
  /// date.
  final DateTime? expires;
  final Version minCli;
  final List<FragmentRef> fragments;

  /// Chaque référence porte la version retirée.
  final List<ItemRef> yanked;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'version': version,
    'publishedAt': publishedAt.toIso8601String(),
    if (expires case final expires?) 'expires': expires.toIso8601String(),
    'minCli': '$minCli',
    'fragments': [
      for (final fragment in fragments)
        {'path': fragment.path, 'sha256': fragment.sha256.value},
    ],
    'yanked': [for (final ref in yanked) '$ref'],
  };
}

/// Vérifie la signature d'un pointeur. Le CLI l'implémente en Ed25519 avec les
/// `trustedKeys` du registre ; `cryptography` ne vérifie qu'en asynchrone.
abstract interface class PointerVerifier {
  bool trusts(String keyId);

  Future<bool> verify(List<int> payload, List<int> signature, String keyId);
}

enum PointerRejection { badSignature, expired, olderThanCache, unknownKey }

sealed class PointerDecision {
  const PointerDecision();
}

final class PointerAccepted extends PointerDecision {
  const PointerAccepted(this.pointer);

  final IndexPointer pointer;
}

final class PointerRejected extends PointerDecision {
  const PointerRejected(this.reason);

  final PointerRejection reason;
}

/// Le contenu de `latest.json` : le pointeur en JSON canonique et sa signature.
final class SignedPointer {
  const SignedPointer({
    required this.payload,
    required this.signature,
    required this.keyId,
  });

  factory SignedPointer.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return SignedPointer(
      payload: node['payload'].string,
      signature: node['signature'].parse(base64Decode),
      keyId: node['keyId'].string,
    );
  }

  /// [canonicalJson] du pointeur : les octets signés sont exactement les siens.
  final String payload;
  final Uint8List signature;
  final String keyId;

  /// Applique la règle 12. La signature est vérifiée avant toute lecture du
  /// contenu ; un contenu signé mais hors schéma lève une [ManifestError].
  Future<PointerDecision> open(
    PointerVerifier verifier, {
    required int? cachedVersion,
    required DateTime now,
  }) async {
    if (!verifier.trusts(keyId)) {
      return const PointerRejected(PointerRejection.unknownKey);
    }
    if (!await verifier.verify(utf8.encode(payload), signature, keyId)) {
      return const PointerRejected(PointerRejection.badSignature);
    }
    final json = JsonNode(payload, r'$.payload').parse<Object?>(jsonDecode);
    final pointer = IndexPointer.fromJson(json, r'$.payload');
    if (pointer.expires case final expires? when !now.isBefore(expires)) {
      return const PointerRejected(PointerRejection.expired);
    }
    if (cachedVersion != null && pointer.version < cachedVersion) {
      return const PointerRejected(PointerRejection.olderThanCache);
    }
    return PointerAccepted(pointer);
  }

  Map<String, Object?> toJson() => {
    'payload': payload,
    'signature': base64Encode(signature),
    'keyId': keyId,
  };
}

import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';

import '../registry/client.dart' show describeReplay;
import '../registry/official.dart';

/// Ce que l'installeur demande à un registre. `lib/src/registry/` l'implémente
/// sur `https://` et `file://` ; les tests, en mémoire.
abstract interface class Registry {
  /// Le pointeur accepté par `SignedPointer.open` (règle 12), sinon
  /// [PointerRejectedFailure].
  Future<IndexPointer> fetchPointer();

  Future<IndexFragment> fetchFragment(FragmentRef fragment);

  Future<ItemManifest> fetchManifest(ItemRef ref, Version version);

  /// Des octets dont l'empreinte égale [sha256] (règle 1), sinon
  /// [IntegrityFailure] : un blob altéré n'est jamais retourné.
  Future<Uint8List> fetchBlob(Sha256 sha256);

  /// Faux quand ce registre ne sert pas le code des éléments Pro : le
  /// registre officiel lu sans clé de licence (ADR 0020 §4). Un registre
  /// d'équipe ou de test est cru : il le sert, ou répond par une erreur.
  bool get servesPro;
}

/// Lève [ProLicenseRequired] quand [registry] ne sert pas le code d'un
/// élément Pro de [manifests] : avant tout téléchargement, et avant de
/// demander quoi que ce soit d'autre à l'utilisateur. Le message nomme le
/// dernier dans l'ordre du plan, qui vient après ses dépendances : l'élément
/// demandé plutôt qu'un bloc qu'il exige.
void requireProAccess(Registry registry, Iterable<ItemManifest> manifests) {
  if (registry.servesPro) return;
  final pro = [
    for (final manifest in manifests)
      if (manifest.meta.tier == Tier.pro) manifest.name,
  ];
  if (pro.isNotEmpty) throw ProLicenseRequired(pro.last);
}

/// Ouvre le registre `@fliin` décrit dans `fliin.yaml`, ou le registre
/// officiel quand [source] est nul.
typedef OpenRegistry = Future<Registry> Function(RegistrySource? source);

/// Les entrées de tous les fragments du pointeur accepté : ce que la
/// résolution, la recherche et le MCP lisent du registre.
Future<List<IndexEntry>> fetchEntries(Registry registry) async {
  final pointer = await registry.fetchPointer();
  return [
    for (final fragment in pointer.fragments)
      ...(await registry.fetchFragment(fragment)).entries,
  ];
}

sealed class RegistryFailure implements Exception {
  const RegistryFailure();

  String get message;

  @override
  String toString() => message;
}

/// Un contenu dont l'empreinte ne correspond pas à celle annoncée (règle 1).
final class IntegrityFailure extends RegistryFailure {
  const IntegrityFailure(this.expected, this.actual, {this.url});

  final Sha256 expected;
  final Sha256 actual;

  /// Le document servi, quand il vient du registre.
  final Uri? url;

  @override
  String get message =>
      'Integrity check failed${url == null ? '' : ' for $url'}: expected '
      '$expected, got $actual.';
}

final class PointerRejectedFailure extends RegistryFailure {
  const PointerRejectedFailure(this.reason, {this.replay, this.url});

  final PointerRejection reason;

  /// Le `latest.json` refusé.
  final Uri? url;

  /// Pour [PointerRejection.olderThanCache] : la version déjà vue, celle
  /// reçue, et le fichier du cache anti-retour.
  final ({int seen, int received, String cache})? replay;

  @override
  String get message => '${_reason()}${url == null ? '' : ' ($url)'}.';

  String _reason() => switch (reason) {
    PointerRejection.badSignature =>
      'Registry pointer rejected: invalid signature',
    PointerRejection.expired => 'Registry pointer rejected: it has expired',
    PointerRejection.olderThanCache =>
      'Registry pointer rejected: it is older than the last one accepted, '
          'which could be a replay${describeReplay(replay)}',
    PointerRejection.unknownKey =>
      'Registry pointer rejected: signed by an unknown key',
  };
}

/// Le registre exige un CLI plus récent (`minCli` du pointeur).
final class CliTooOldFailure extends RegistryFailure {
  const CliTooOldFailure(this.minCli, this.cliVersion);

  final Version minCli;
  final Version cliVersion;

  @override
  String get message =>
      'The registry requires fliin $minCli or later. This CLI is '
      '$cliVersion. Run dart pub global activate fliin.';
}

/// Le cache anti-retour (règle 12) est illisible : le supprimer est un geste
/// de l'utilisateur, jamais du CLI.
final class CacheUnreadableFailure extends RegistryFailure {
  const CacheUnreadableFailure(this.path, [this.detail]);

  final String path;
  final String? detail;

  @override
  String get message =>
      'The anti-replay cache cannot be read'
      '${detail == null ? '' : ' ($detail)'}. Delete $path, then run the '
      'command again.';
}

/// Un manifeste, un fragment ou un blob que le registre devrait servir et
/// qu'il ne sert pas.
final class MissingArtifact extends RegistryFailure {
  const MissingArtifact(this.path);

  final String path;

  @override
  String get message => 'The registry does not serve $path.';
}

final class RegistryUnreachable extends RegistryFailure {
  const RegistryUnreachable(this.detail);

  final String detail;

  @override
  String get message => 'Registry unreachable: $detail.';
}

/// Un élément Pro demandé sans clé de licence.
final class ProLicenseRequired extends RegistryFailure {
  const ProLicenseRequired(this.item);

  final String item;

  @override
  String get message =>
      '$item is a Fliin Pro item. Get a license at '
      '${OfficialRegistry.proPage}, then run fliin login.';
}

/// L'hôte Pro refuse la clé de licence (401 ou 403) : [detail] est le
/// message du serveur.
final class ProLicenseRefused extends RegistryFailure {
  const ProLicenseRefused(this.detail);

  final String? detail;

  @override
  String get message => switch (detail) {
    null =>
      'License key refused by the Fliin Pro registry. Get a valid one at '
          '${OfficialRegistry.proPage}, then run fliin login.',
    final detail =>
      'License key refused by the Fliin Pro registry: $detail Run fliin '
          'login with a valid key.',
  };
}

/// Ce CLI n'a pas encore la clé de signature du registre officiel : il ne
/// peut pas le lire.
final class NoOfficialKey extends RegistryFailure {
  const NoOfficialKey(this.url);

  final Uri url;

  @override
  String get message =>
      'This build of fliin has no official registry key yet, so it cannot '
      'read $url. Use a team or test registry: fliin init --registry <url> '
      '--trusted-key <key>, or a registries: entry in fliin.yaml.';
}

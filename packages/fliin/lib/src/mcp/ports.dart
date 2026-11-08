import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';

import '../search/search_index.dart';

/// Les quatre interfaces de l'ADR 0001 §4.1 : ce qui diffère entre le CLI
/// (`fliin mcp`, V1) et le serveur distant (V2). `local/` les implémente pour
/// le CLI ; les contrats d'outils et le classement, eux, sont partagés.
abstract interface class IndexSource {
  /// L'index courant, relu quand il est périmé. Lève une [RegistryFailure]
  /// du port `Registry`.
  Future<IndexSnapshot> snapshot();
}

/// Les entrées d'un pointeur, et l'index de recherche construit dessus.
final class IndexSnapshot {
  IndexSnapshot(List<IndexEntry> entries)
    : index = SearchIndex.build(entries),
      _entries = {for (final entry in entries) entry.ref: entry};

  final SearchIndex index;
  final Map<ItemRef, IndexEntry> _entries;

  IndexEntry? entry(ItemRef ref) => _entries[ref];

  /// La fermeture de [ref] à [version], dépendances d'abord et l'élément en
  /// dernier, sans contrainte de Flutter : le MCP ne connaît pas le projet,
  /// `fliin add` la vérifie.
  Resolution closure(ItemRef ref, Version version) => resolve(
    roots: [ItemDependency(ref, version)],
    lookup: (ref) => switch (_entries[ref]) {
      null => null,
      final entry => IndexEntry(
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
              flutter: VersionConstraint.any,
              registryDependencies: release.registryDependencies,
              status: release.status,
            ),
        ],
      ),
    },
    flutter: Version.none,
    installed: const {},
  );
}

extension type const SelectionHandle(String value) {}

enum VariantPlatform { ios, android }

enum VariantBrightness { light, dark }

enum VariantScale {
  normal(1),
  large(2);

  const VariantScale(this.factor);

  final int factor;
}

enum VariantDirection { ltr, rtl }

/// Une des seize variantes de `fliin verify` (`variantIds`), celle dont la
/// page de choix et `previewUrl` montrent le golden de référence.
final class GoldenVariant {
  const GoldenVariant({
    this.platform = VariantPlatform.ios,
    this.brightness = VariantBrightness.light,
    this.scale = VariantScale.normal,
    this.dir = VariantDirection.ltr,
  });

  final VariantPlatform platform;
  final VariantBrightness brightness;
  final VariantScale scale;
  final VariantDirection dir;

  /// L'identifiant de `variantIds` : `ios.light.1.0.ltr`.
  String get id =>
      '${platform.name}.${brightness.name}.${scale.factor}.0.${dir.name}';

  /// Pour l'humain : « iOS, clair, texte 1,0×, gauche à droite ».
  String get label => [
    switch (platform) {
      VariantPlatform.ios => 'iOS',
      VariantPlatform.android => 'Android',
    },
    switch (brightness) {
      VariantBrightness.light => 'light',
      VariantBrightness.dark => 'dark',
    },
    'text ${scale.factor}.0×',
    switch (dir) {
      VariantDirection.ltr => 'left to right',
      VariantDirection.rtl => 'right to left',
    },
  ].join(', ');

  /// Les seize, dans l'ordre de `variantIds`.
  static final all = [
    for (final platform in VariantPlatform.values)
      for (final brightness in VariantBrightness.values)
        for (final scale in VariantScale.values)
          for (final dir in VariantDirection.values)
            GoldenVariant(
              platform: platform,
              brightness: brightness,
              scale: scale,
              dir: dir,
            ),
  ];

  @override
  bool operator ==(Object other) => other is GoldenVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// `pending` tant que l'humain n'a pas tranché, puis une [SelectionOutcome].
sealed class SelectionStatus {
  const SelectionStatus();
}

final class Pending extends SelectionStatus {
  const Pending();
}

sealed class SelectionOutcome extends SelectionStatus {
  const SelectionOutcome();
}

final class Chosen extends SelectionOutcome {
  const Chosen(this.item);

  final ItemRef item;
}

final class Declined extends SelectionOutcome {
  const Declined();
}

/// Une sélection humaine en cours (ADR §2) : en mémoire du processus en V1,
/// en base en V2.
final class Selection {
  const Selection({
    required this.handle,
    required this.candidates,
    required this.question,
    required this.variant,
    required this.formToken,
    required this.status,
    required this.expires,
  });

  final SelectionHandle handle;

  /// Chacun à la version que la page montre.
  final List<ItemRef> candidates;
  final String question;
  final GoldenVariant variant;

  /// Exigé par le POST de la page de choix, qui ne le montre qu'à elle-même :
  /// une page d'une autre origine qui connaîtrait l'URL ne peut pas trancher.
  final String formToken;
  final SelectionStatus status;
  final DateTime expires;
}

abstract interface class SelectionStore {
  /// Une sélection neuve, qui expire 30 minutes plus tard.
  Future<Selection> open({
    required List<ItemRef> candidates,
    required String question,
    required GoldenVariant variant,
  });

  /// Nulle si la poignée est inconnue ou expirée.
  Future<Selection?> find(SelectionHandle handle);

  /// Le choix de l'humain, qui ne se reprend pas : une sélection déjà
  /// tranchée est rendue telle quelle. Nulle si la poignée est inconnue ou
  /// expirée.
  Future<Selection?> settle(SelectionHandle handle, SelectionOutcome outcome);
}

enum Entitlement { granted, missing }

/// Le droit d'obtenir un élément. V1 : tout est gratuit.
abstract interface class EntitlementResolver {
  Future<Entitlement> resolve(IndexEntry entry);
}

enum QuotaScope { search, item, selection }

sealed class QuotaDecision {
  const QuotaDecision();
}

final class Admitted extends QuotaDecision {
  const Admitted();
}

final class Exceeded extends QuotaDecision {
  const Exceeded(this.retryAfter);

  final Duration retryAfter;
}

/// Les quotas de DESIGN.md §5.2. V1 : sans limite.
abstract interface class QuotaGate {
  Future<QuotaDecision> admit(QuotaScope scope);
}
// x

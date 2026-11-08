import 'package:pub_semver/pub_semver.dart';

import 'index.dart';
import 'item_ref.dart';
import 'manifest.dart';

/// Ce que rend [resolve] : un plan complet ou une erreur, jamais un plan
/// partiel (règle 4).
sealed class Resolution {
  const Resolution();
}

/// La fermeture des `registryDependencies`, dépendances d'abord. Elle contient
/// aussi les éléments déjà installés : à l'appelant de sauter ceux-là.
final class InstallPlan extends Resolution {
  const InstallPlan(this.items);

  final List<PlannedItem> items;
}

final class PlannedItem {
  const PlannedItem({
    required this.ref,
    required this.release,
    required this.dependencies,
  });

  /// Sans version, comme la clé du lockfile.
  final ItemRef ref;

  /// La version retenue ; son manifeste se télécharge par `manifestSha256`.
  final IndexVersion release;

  /// Ses dépendances, chacune à la version retenue pour elle.
  final List<ItemRef> dependencies;

  Version get version => release.version;
}

sealed class ResolutionError extends Resolution {
  const ResolutionError();
}

final class ItemNotFound extends ResolutionError {
  const ItemNotFound(this.ref);

  final ItemRef ref;
}

final class NoVersionMatches extends ResolutionError {
  const NoVersionMatches(this.ref, this.constraint, this.available);

  final ItemRef ref;

  /// L'intersection des contraintes posées sur [ref].
  final VersionConstraint constraint;

  /// Les versions publiées et non retirées.
  final List<Version> available;
}

final class DependencyCycle extends ResolutionError {
  const DependencyCycle(this.path);

  /// Commence et finit par le même élément.
  final List<ItemRef> path;
}

/// Des versions satisfont la contrainte, mais aucune ne supporte ce Flutter.
final class FlutterTooOld extends ResolutionError {
  const FlutterTooOld(this.ref, this.required, this.actual);

  final ItemRef ref;

  /// La contrainte `flutter` de la plus haute de ces versions.
  final VersionConstraint required;
  final Version actual;
}

/// Résout [roots] et leur fermeture avant toute écriture (règle 4).
///
/// Pour chaque élément : la version installée si elle satisfait les
/// contraintes et [flutter], même retirée, pour ne jamais rétrograder en
/// silence ; sinon la plus haute qui les satisfait, jamais une version retirée
/// (règle 12). Sans retour arrière : une contrainte apparue après le choix
/// d'une version, et que celle-ci ne satisfait pas, est une [NoVersionMatches].
Resolution resolve({
  required List<ItemDependency> roots,
  required IndexEntry? Function(ItemRef ref) lookup,
  required Version flutter,
  required Map<ItemRef, Version> installed,
}) {
  final constraints = <ItemRef, VersionConstraint>{};
  void constrain(ItemDependency dependency) => constraints[dependency.ref] =
      constraints[dependency.ref]?.intersect(dependency.constraint) ??
      dependency.constraint;
  roots.forEach(constrain);

  final chosen = <ItemRef, IndexVersion>{};
  final plan = <PlannedItem>[];
  final path = <ItemRef>[];

  ResolutionError? visit(ItemRef ref) {
    if (path.contains(ref)) {
      return DependencyCycle([...path.skip(path.indexOf(ref)), ref]);
    }
    final constraint = constraints[ref]!;
    if (chosen[ref] case final release?) {
      return constraint.allows(release.version)
          ? null
          : NoVersionMatches(ref, constraint, _available(lookup(ref)!));
    }
    final entry = lookup(ref);
    if (entry == null) return ItemNotFound(ref);

    bool fits(IndexVersion v) =>
        constraint.allows(v.version) && v.flutter.allows(flutter);
    final release =
        entry.versions
            .where((v) => v.version == installed[ref] && fits(v))
            .firstOrNull ??
        _highest(entry.versions.where((v) => v.status is Published && fits(v)));
    if (release == null) {
      final blocked = _highest(
        entry.versions.where(
          (v) => v.status is Published && constraint.allows(v.version),
        ),
      );
      return blocked == null
          ? NoVersionMatches(ref, constraint, _available(entry))
          : FlutterTooOld(ref, blocked.flutter, flutter);
    }

    chosen[ref] = release;
    path.add(ref);
    for (final dependency in release.registryDependencies) {
      constrain(dependency);
      if (visit(dependency.ref) case final error?) return error;
    }
    path.removeLast();
    plan.add(
      PlannedItem(
        ref: ref,
        release: release,
        dependencies: [
          for (final dependency in release.registryDependencies)
            dependency.ref.at(chosen[dependency.ref]!.version),
        ],
      ),
    );
    return null;
  }

  for (final root in roots) {
    if (visit(root.ref) case final error?) return error;
  }
  return InstallPlan(plan);
}

IndexVersion? _highest(Iterable<IndexVersion> versions) =>
    versions.fold<IndexVersion?>(
      null,
      (best, v) => best == null || v.version > best.version ? v : best,
    );

List<Version> _available(IndexEntry entry) => [
  for (final v in entry.versions)
    if (v.status is Published) v.version,
];

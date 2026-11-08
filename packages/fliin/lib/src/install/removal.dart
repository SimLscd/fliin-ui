import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'kept_raws.dart';
import 'lockfile_io.dart';
import 'status.dart';

sealed class Removal {
  const Removal();
}

final class NotInstalledItems extends Removal {
  const NotInstalledItems(this.refs);

  final List<ItemRef> refs;
}

/// Des éléments installés hors de la demande dépendent de ceux à retirer :
/// rien n'est supprimé. [together] est la demande et tous ses dépendants,
/// de proche en proche : ce qu'il faudrait retirer ensemble.
final class RequiredBy extends Removal {
  const RequiredBy(this.dependents, this.together);

  /// Par élément demandé, ceux qui en dépendent directement.
  final Map<ItemRef, List<ItemRef>> dependents;
  final List<ItemRef> together;
}

/// Des fichiers à supprimer ne sont plus ceux que fliin a écrits : rien n'est
/// supprimé sans `--force`.
final class LocallyModified extends Removal {
  const LocallyModified(this.files);

  final List<FileStatus> files;
}

final class RemovalPlan extends Removal {
  const RemovalPlan({
    required this.items,
    required this.orphans,
    required this.lockfile,
  });

  /// Par élément retiré, avec sa version installée : chacun de ses fichiers
  /// et son état avant suppression ; un fichier `deleted` n'a plus rien à
  /// supprimer.
  final Map<ItemRef, List<FileStatus>> items;

  /// Les éléments installés que plus rien ne requiert une fois [items]
  /// retirés, `core` excepté : signalés, jamais retirés d'office.
  final List<ItemRef> orphans;

  /// Le lockfile sans [items].
  final Lockfile lockfile;
}

/// Décide ce que retirer [refs] supprimerait, sans rien écrire.
Removal planRemoval(
  Directory dir,
  Lockfile lockfile,
  List<ItemRef> refs, {
  required bool force,
}) {
  final unknown = [
    for (final ref in refs)
      if (!lockfile.items.containsKey(ref)) ref,
  ];
  if (unknown.isNotEmpty) return NotInstalledItems(unknown);
  final removed = refs.toSet();
  final dependents = <ItemRef, List<ItemRef>>{
    for (final ref in refs)
      if (_dependents(lockfile, ref, removed) case final users
          when users.isNotEmpty)
        ref: users,
  };
  if (dependents.isNotEmpty) {
    return RequiredBy(dependents, _closure(lockfile, removed));
  }
  final items = {
    for (final ref in refs)
      ref.at(lockfile.items[ref]!.version): [
        for (final MapEntry(key: path, value: file)
            in lockfile.items[ref]!.files.entries)
          (path: path, item: ref, state: localState(file, onDisk(dir, path))),
      ],
  };
  final modified = [
    for (final file in items.values.expand((files) => files))
      if (file.state != InstalledState.intact &&
          file.state != InstalledState.deleted)
        file,
  ];
  if (modified.isNotEmpty && !force) return LocallyModified(modified);
  final remaining = {
    for (final MapEntry(:key, :value) in lockfile.items.entries)
      if (!removed.contains(key)) key: value,
  };
  return RemovalPlan(
    items: items,
    orphans: _orphans(lockfile, removed),
    lockfile: Lockfile(
      registries: lockfile.registries,
      config: lockfile.config,
      dartStyle: lockfile.dartStyle,
      items: remaining,
    ),
  );
}

/// Supprime les fichiers du plan, leurs `.fliin-new`, les dossiers que cela
/// vide sous `root`, puis écrit le lockfile. Interrompu, il se relance : un
/// fichier déjà supprimé est `deleted`, et le lockfile vient en dernier.
void applyRemoval(Directory dir, Lockfile before, RemovalPlan plan) {
  final root = p.join(dir.path, before.config.root);
  for (final file in plan.items.values.expand((files) => files)) {
    final locked = before.items[file.item]!.files[file.path]!;
    for (final path in [file.path, ?locked.conflicted?.sidecarPath]) {
      final target = File(p.join(dir.path, path));
      if (!target.existsSync()) continue;
      target.deleteSync();
      for (
        var parent = target.parent;
        p.isWithin(root, parent.path) && parent.listSync().isEmpty;
        parent = parent.parent
      ) {
        parent.deleteSync();
      }
    }
  }
  writeLockfile(dir, plan.lockfile);
  pruneKeptRaws(dir, plan.lockfile);
}

/// Les éléments installés hors de [removed] qui dépendent de [ref].
List<ItemRef> _dependents(
  Lockfile lockfile,
  ItemRef ref,
  Set<ItemRef> removed,
) => [
  for (final MapEntry(key: user, value: item) in lockfile.items.entries)
    if (!removed.contains(user) &&
        item.registryDependencies.any((d) => _same(d, ref)))
      user,
];

List<ItemRef> _closure(Lockfile lockfile, Set<ItemRef> removed) {
  final together = {...removed};
  for (var grew = true; grew;) {
    final before = together.length;
    together.addAll([
      for (final ref in together.toList())
        ..._dependents(lockfile, ref, together),
    ]);
    grew = together.length != before;
  }
  return together.toList();
}

/// De proche en proche : une dépendance d'un élément retiré, que seuls des
/// éléments retirés ou déjà orphelins requièrent.
List<ItemRef> _orphans(Lockfile lockfile, Set<ItemRef> removed) {
  final gone = {...removed};
  final orphans = <ItemRef>[];
  for (var grew = true; grew;) {
    grew = false;
    for (final ref in lockfile.items.keys) {
      if (gone.contains(ref) || ref == ItemRef('core')) continue;
      final wasRequired = gone.any(
        (g) =>
            lockfile.items[g]!.registryDependencies.any((d) => _same(d, ref)),
      );
      if (wasRequired && _dependents(lockfile, ref, gone).isEmpty) {
        gone.add(ref);
        orphans.add(ref);
        grew = true;
      }
    }
  }
  return orphans;
}

/// [dependency] porte sa version, la clé du lockfile non.
bool _same(ItemRef dependency, ItemRef ref) =>
    dependency.name == ref.name && dependency.namespace == ref.namespace;

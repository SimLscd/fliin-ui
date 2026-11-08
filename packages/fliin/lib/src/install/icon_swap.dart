import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'normalizer.dart';
import 'registry_port.dart';
import 'selected_registry.dart';
import 'staging.dart';
import 'status.dart';
import 'targets.dart';

/// Ce que `fliin theme --preset` écrit quand le préréglage change de jeu
/// d'icônes et que `icons` est installé : le `fl_icons.dart` du jeu, rendu
/// pour le projet, et le lockfile dont l'entrée a ce brut pour `raw` et ce
/// rendu pour `base` et `installed` (règle 3). [overwritten] : le fichier
/// sur le disque n'était plus celui que fliin avait écrit, une retouche
/// locale que le jeu remplace, comme le préréglage remplace les jetons
/// (ADR 0016 §4.4).
typedef IconSwap = ({
  String path,
  PresetIcons set,
  String text,
  Lockfile lockfile,
  bool overwritten,
});

/// Le `fl_icons.dart` de `icons` attend la résolution d'un conflit, dans
/// un `.fliin-new` ([sidecar]) ou en marqueurs dans le fichier ([sidecar]
/// nul) : le remplacer jetterait la version amont ou le conflit.
final class IconSwapBlocked implements Exception {
  const IconSwapBlocked(this.path, this.sidecar);

  final String path;
  final String? sidecar;

  @override
  String toString() =>
      '$path is waiting for '
      '${sidecar == null ? 'its conflict markers' : '$sidecar'} to be resolved. '
      'Resolve the conflict, then run fliin theme --preset again.';
}

bool _hasMarkers(String text) =>
    RegExp(r'^<<<<<<< ', multiLine: true).hasMatch(text);

/// Le remplacement de jeu d'icônes que [set] demande au projet [dir], ou
/// null quand rien n'est à changer : `icons` n'est pas installé, ou son
/// fichier est déjà celui de [set]. [registry] est lu à la version
/// installée d'`icons`, jamais au-delà : changer de jeu ne met rien à jour.
/// Lève [MissingVariant] si cette version ne sert pas [set],
/// [IconSwapBlocked] si le fichier est en conflit.
Future<IconSwap?> planIconSwap({
  required Directory dir,
  required RenderConfig render,
  required Lockfile? lockfile,
  required Future<Registry> Function() registry,
  required PresetIcons set,
}) async {
  final ref = ItemRef('icons');
  final locked = lockfile?.items[ref];
  if (lockfile == null || locked == null) return null;
  final manifest = await SelectedRegistry(
    await registry(),
    set.variant,
  ).fetchManifest(ref, locked.version);
  final files = <String, LockedFile>{...locked.files};
  String? path;
  ItemFile? chosen;
  for (final file in manifest.files) {
    final target = projectPath(render, file.target);
    if (files[target] case final installed? when installed.raw != file.sha256) {
      if (installed.conflicted case final marker?) {
        throw IconSwapBlocked(target, marker.sidecarPath);
      }
      (path, chosen) = (target, file);
    }
  }
  if (path == null || chosen == null) return null;
  final bytes = await (await registry()).fetchBlob(chosen.sha256);
  if (Sha256.ofBytes(bytes) case final actual when actual != chosen.sha256) {
    throw IntegrityFailure(chosen.sha256, actual);
  }
  final text = renderRaw(bytes, path, render);
  final rendered = Sha256.ofString(text);
  final disk = File(p.join(dir.path, path));
  if (disk.existsSync() && _hasMarkers(disk.readAsStringSync())) {
    throw IconSwapBlocked(path, null);
  }
  // Comparé à base, comme status : une retouche qu'update a fusionnée est
  // dans installed, et resterait sinon écrasée sans le dire.
  final overwritten =
      localState(files[path]!, onDisk(dir, path)) != InstalledState.intact;
  files[path] = LockedFile(
    raw: chosen.sha256,
    base: rendered,
    installed: rendered,
  );
  return (
    path: path,
    set: set,
    text: text,
    lockfile: Lockfile(
      registries: lockfile.registries,
      config: lockfile.config,
      dartStyle: dartStyleVersion,
      items: {
        ...lockfile.items,
        ref: LockedItem(
          version: locked.version,
          registryDependencies: locked.registryDependencies,
          files: files,
        ),
      },
    ),
    overwritten: overwritten,
  );
}

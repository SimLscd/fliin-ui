import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

/// Le fichier où la version amont attend, à côté du fichier local.
String sidecarOf(String path) => '$path.fliin-new';

/// Les conflits que l'utilisateur a résolus en supprimant le `.fliin-new` :
/// `raw` et `base` passent à ceux de la version visée, et `installed` à
/// cette version telle qu'elle aurait été écrite, si bien que `status` dit
/// `intact` si l'utilisateur l'a adoptée et `modified` s'il a gardé ou mêlé
/// la sienne. [resolved] liste les fichiers qui ont avancé, vide si le
/// lockfile n'a pas changé.
({Lockfile lockfile, List<String> resolved}) settleConflicts(
  Directory dir,
  Lockfile lockfile,
) {
  final resolved = <String>[];
  LockedFile settle(String path, LockedFile file) {
    final marker = file.conflicted;
    if (marker == null ||
        File(p.join(dir.path, marker.sidecarPath)).existsSync()) {
      return file;
    }
    resolved.add(path);
    return LockedFile(
      raw: marker.raw,
      base: marker.base,
      installed: marker.base,
    );
  }

  final items = {
    for (final MapEntry(key: ref, value: item) in lockfile.items.entries)
      ref: LockedItem(
        version: item.version,
        registryDependencies: item.registryDependencies,
        files: {
          for (final MapEntry(key: path, value: file) in item.files.entries)
            path: settle(path, file),
        },
      ),
  };
  return (
    lockfile: Lockfile(
      registries: lockfile.registries,
      config: lockfile.config,
      dartStyle: lockfile.dartStyle,
      items: items,
    ),
    resolved: resolved..sort(),
  );
}

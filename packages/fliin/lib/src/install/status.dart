import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import 'staging.dart';

typedef FileStatus = ({String path, ItemRef item, InstalledState state});

typedef ProjectStatus = ({List<FileStatus> files, List<String> orphans});

/// Chaque fichier du lockfile classé d'après le disque, une retouche que
/// `update` a fusionnée comptant comme modifiée ([localState]), puis les
/// orphelins :
/// les `.dart` sous `root` que le lockfile ne connaît pas, un reste de
/// transit excepté.
ProjectStatus projectStatus(Directory dir, Lockfile lockfile) {
  final files = [
    for (final MapEntry(key: item, value: locked) in lockfile.items.entries)
      for (final MapEntry(key: path, value: file) in locked.files.entries)
        (path: path, item: item, state: localState(file, onDisk(dir, path))),
  ];
  final known = {for (final file in files) file.path};
  final root = Directory(p.join(dir.path, lockfile.config.root));
  final transit = p.join(root.path, transitDirName);
  final orphans = [
    if (root.existsSync())
      for (final entity in root.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !p.isWithin(transit, entity.path))
          if (p.relative(entity.path, from: dir.path) case final path
              when !known.contains(path))
            path,
  ]..sort();
  return (files: files, orphans: orphans);
}

/// L'empreinte de [path], relatif au projet, nulle s'il est absent.
Sha256? onDisk(Directory dir, String path) {
  final file = File(p.join(dir.path, path));
  return file.existsSync() ? Sha256.ofBytes(file.readAsBytesSync()) : null;
}

/// [classify] pour une commande qui écrirait ou supprimerait le fichier : un
/// fichier `intact` qui diffère de sa `base` porte des modifications locales
/// que `update` a fusionnées, il compte donc comme modifié ; un fichier
/// supprimé dont la mise à jour attend une résolution reste en conflit, son
/// `.fliin-new` est sur le disque.
InstalledState localState(LockedFile file, Sha256? found) =>
    switch (classify(file, found)) {
      InstalledState.deleted when file.conflicted != null =>
        InstalledState.conflicted,
      InstalledState.intact when found != file.base => InstalledState.modified,
      final state => state,
    };

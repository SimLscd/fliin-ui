import 'dart:io';

import 'package:path/path.dart' as p;

/// Un seul fliin écrit dans un projet à la fois : `init`, `add` et `verify`
/// tiennent ce verrou exclusif pendant toute la commande. Deux installations
/// qui se chevauchent se supprimeraient le transit et se restaureraient le
/// pubspec l'une à l'autre.
final class ProjectLock {
  ProjectLock._(this._file);

  static const path = '.dart_tool/fliin.lock';

  final RandomAccessFile _file;

  /// Lève [ProjectBusy] si un autre processus tient le verrou.
  static ProjectLock acquire(Directory dir) {
    final file = File(p.join(dir.path, path))
      ..parent.createSync(recursive: true);
    final handle = file.openSync(mode: FileMode.append);
    try {
      handle.lockSync(FileLock.exclusive);
    } on FileSystemException {
      handle.closeSync();
      throw ProjectBusy(file.path);
    }
    return ProjectLock._(handle);
  }

  void release() {
    _file
      ..unlockSync()
      ..closeSync();
  }
}

/// Un autre fliin travaille déjà sur ce projet. Sortie 1.
final class ProjectBusy implements Exception {
  const ProjectBusy(this.path);

  final String path;

  @override
  String toString() =>
      'Another fliin is already working on this project (lock $path). '
      'Wait for it to finish, then run the command again.';
}

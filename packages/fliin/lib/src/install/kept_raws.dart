import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

/// Le brut d'un fichier Pro, gardé dans le projet et versionné (règle 3) :
/// un abonné échu, une nouvelle machine ou une CI recalculent `base` sans
/// passer par la porte du registre.
const keptRawsDir = '.fliin/base';

File _file(Directory dir, Sha256 sha256) =>
    File(p.join(dir.path, keptRawsDir, sha256.hex));

void keepRaw(Directory dir, Sha256 sha256, Uint8List bytes) {
  final file = _file(dir, sha256);
  if (file.existsSync()) return;
  File('${file.path}.tmp')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes)
    ..renameSync(file.path);
}

/// Null s'il n'est pas gardé, ou si son empreinte ne correspond plus.
Uint8List? keptRaw(Directory dir, Sha256 sha256) {
  final file = _file(dir, sha256);
  if (!file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  return Sha256.ofBytes(bytes) == sha256 ? bytes : null;
}

/// Supprime les bruts gardés que le lockfile ne désigne plus.
void pruneKeptRaws(Directory dir, Lockfile lockfile) {
  final kept = Directory(p.join(dir.path, keptRawsDir));
  if (!kept.existsSync()) return;
  final referenced = {
    for (final item in lockfile.items.values)
      for (final file in item.files.values) ...[
        file.raw.hex,
        ?file.conflicted?.raw.hex,
      ],
  };
  for (final entity in kept.listSync().whereType<File>()) {
    if (!referenced.contains(p.basename(entity.path))) entity.deleteSync();
  }
}

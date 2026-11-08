import 'dart:convert';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;

import 'analyze.dart';
import 'normalizer.dart';
import 'targets.dart';

/// Le dossier de transit, sous `root` pour que l'analyse le voie comme le
/// projet. Nom fixe : un reste d'installation ou de mise à jour interrompue
/// est supprimé à l'entrée de la suivante, et ni `status` ni l'installeur
/// ne le comptent parmi les fichiers de `root`.
const transitDirName = '.fliin-transit';

/// Le texte installé pour un brut publié : réécrit avec la config, puis
/// normalisé par le `dart_style` embarqué s'il est en Dart (règle 3).
String renderRaw(Uint8List bytes, String path, RenderConfig config) {
  final rewritten = applyRewrites(utf8.decode(bytes), config);
  return path.endsWith('.dart') ? normalize(rewritten) : rewritten;
}

/// Où [path], relatif au projet, est écrit dans le transit.
String transitPath(RenderConfig config, String path) =>
    p.join(config.root, transitDirName, p.relative(path, from: config.root));

/// Pour l'analyse, les imports entre fichiers de [paths] pointent vers le
/// transit, afin qu'elle voie le graphe qu'on va écrire ; le texte vrai est
/// remis avant le déplacement.
String Function(String text) redirectImports(
  RenderConfig config,
  Iterable<String> paths,
) {
  final redirect = {
    for (final path in paths)
      "'${importUri(config, path)}'":
          "'${importUri(config, transitPath(config, path))}'",
  };
  return (text) =>
      redirect.entries.fold(text, (text, e) => text.replaceAll(e.key, e.value));
}

/// [d] situé sur le fichier qu'il concerne, hors du transit.
Diagnostic outOfTransit(Diagnostic d) => (
  severity: d.severity,
  code: d.code,
  file: d.file.replaceFirst('/$transitDirName/', '/'),
  line: d.line,
  column: d.column,
  message: d.message,
);

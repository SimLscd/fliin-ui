import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;

import 'build.dart';
import 'public_api.dart';

/// La première ligne de chaque fichier Dart d'un élément Pro, dans la source :
/// le brut la porte, et `base` reste une fonction pure (règle 3).
const proLicenseLine =
    '// Part of Fliin Pro. Licensed under the Fliin Pro License: '
    'https://fliin.dev/pro/license';

/// Le fichier, à la racine de la source, des éléments publiés hors d'elle
/// vers lesquels un `notFor` peut renvoyer : un nom par ligne, `#` en tête
/// d'un commentaire. L'export public l'écrit pour les éléments Pro qu'il n'a
/// pas (ADR 0020 §12).
const externalItemsFile = 'external_items.txt';

/// DESIGN.md §6.5 sur toute la source : les métadonnées, puis la doc de
/// chaque symbole public des fichiers Dart publiés, et la ligne de la licence
/// Pro en tête des fichiers Pro. Un `notFor` peut aussi renvoyer à un élément
/// déjà publié dans [out], ou nommé dans [externalItemsFile] sous [root].
List<LintFinding> lintSource(
  SourceRegistry source, {
  required String out,
  String? root,
}) {
  final published = Directory(p.join(out, 'items', Namespace.fliin.bare));
  final external = File(p.join(root ?? '', externalItemsFile));
  return [
    ...lintMetadata(
      source.manifests,
      known: {
        if (published.existsSync())
          for (final dir in published.listSync().whereType<Directory>())
            p.basename(dir.path),
        if (root != null && external.existsSync())
          for (final line in external.readAsLinesSync())
            if (line.trim() case final name
                when name.isNotEmpty && !name.startsWith('#'))
              name,
      },
    ),
    for (final manifest in source.manifests)
      for (final file in manifest.files)
        if (file.path.endsWith('.dart'))
          for (final symbol in undocumentedSymbols(
            utf8.decode(source.blobs[file.sha256]!),
          ))
            LintFinding(
              manifest.name,
              LintRule.undocumentedSymbol,
              '${file.path}: $symbol has no /// comment',
            ),
    for (final manifest in source.manifests)
      if (manifest.meta.tier == Tier.pro)
        for (final file in manifest.files)
          if (file.path.endsWith('.dart') &&
              !utf8
                  .decode(source.blobs[file.sha256]!)
                  .startsWith('$proLicenseLine\n'))
            LintFinding(
              manifest.name,
              LintRule.proLicenseHeader,
              '${file.path}: a Pro file must start with the line '
              '"$proLicenseLine"',
            ),
  ];
}

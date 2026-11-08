import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// La version de [item] dans la source [root] (`flutter/registry` du dépôt
/// par défaut), lue dans son manifeste : un test qui installe ou publie un
/// élément du dépôt suit ainsi sa version au lieu de l'écrire en dur, et la
/// prochaine montée de version ne le casse pas.
String sourceVersion(String item, {String? root}) {
  final manifest = File(
    p.join(
      root ?? p.normalize(p.absolute('../../flutter/registry')),
      'items',
      '$item.json',
    ),
  );
  return (jsonDecode(manifest.readAsStringSync())
          as Map<String, Object?>)['version']!
      as String;
}

/// Nul quand la source a les éléments Pro, sinon la raison de sauter un test
/// qui en a besoin : l'export public du gratuit n'en a aucun (ADR 0020 §12).
final String? withoutPro =
    Directory(
      p.normalize(p.absolute('../../flutter/registry/lib/screens')),
    ).existsSync()
    ? null
    : 'needs the Pro items, absent from the public repository';

/// [version] plus un correctif : `0.1.1` donne `0.1.2`.
String nextPatch(String version) {
  final [major, minor, patch] = version.split('.');
  return '$major.$minor.${int.parse(patch) + 1}';
}

/// [version] plus une mineure : `0.2.1` donne `0.3.0`.
String nextMinor(String version) {
  final [major, minor, _] = version.split('.');
  return '$major.${int.parse(minor) + 1}.0';
}

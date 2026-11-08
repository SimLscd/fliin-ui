import 'dart:convert';

/// [manifest], le texte d'un manifeste source, passé à [version].
String withVersion(String manifest, String version) => manifest.replaceFirst(
  RegExp(r'"version": "[^"]+"'),
  '"version": "$version"',
);

/// [manifest] avec [changelog] pour changelog : il remplace celui que le
/// manifeste a déjà, ou s'ajoute après `l10n`. Ajouté à côté d'un changelog
/// existant, il ferait une clé en double, dont `jsonDecode` garde la
/// dernière.
String withChangelog(String manifest, String changelog) {
  final entry = '"changelog": ${jsonEncode(changelog)}';
  final existing = RegExp(r'"changelog": "(?:[^"\\]|\\.)*"');
  return existing.hasMatch(manifest)
      ? manifest.replaceFirst(existing, entry)
      : manifest.replaceFirst('"l10n": {},', '"l10n": {},\n  $entry,');
}

/// [manifest] avec [entry], un fichier du manifeste écrit sur une ligne,
/// ajouté juste après le fichier de cible [target], quelle que soit la mise
/// en forme du manifeste. [entry] se retire en ôtant `,\n    ` suivi de lui.
String withFileAfter(String manifest, String target, String entry) {
  final file = RegExp('"target": "${RegExp.escape(target)}"\\s*\\}');
  if (!file.hasMatch(manifest)) throw StateError('aucun fichier de cible $target');
  return manifest.replaceFirstMapped(file, (m) => '${m[0]},\n    $entry');
}

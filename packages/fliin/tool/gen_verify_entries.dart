// Génère flutter/registry/test/reference/verify_entries.g.dart depuis
// flutter/registry/items/*.json : pour chaque élément qui a un `verify`, la
// fonction d'entrée que `fliin verify` écrit dans l'app (préfixe Fl, mêmes
// imports, même `canvas`, même `settleMs`). `reference_goldens_test.dart` la
// rend pour produire les goldens de référence que `registry build` publie
// (ADR 0011). Le catalogue du site en reçoit une copie, qui prend `FlVariant`
// chez lui : le harnais importe dart:io et ne compile pas pour le web
// (ADR 0013). `--check` : sortie 1 si un fichier commité dérive. Lancer
// depuis la racine du dépôt :
// dart run packages/fliin/tool/gen_verify_entries.dart
import 'dart:io';

import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/verify/test_source.dart';
import 'package:fliin_schema/fliin_schema.dart';

const source = 'flutter/registry';

/// Chaque fichier écrit, et la bibliothèque qui lui donne `FlVariant`.
const targets = {
  '$source/test/reference/verify_entries.g.dart':
      'package:fliin_harness/fliin_harness.dart',
  'flutter/catalog/lib/reference_entries.g.dart':
      'package:fliin_catalog/variant.dart',
};

void main(List<String> args) {
  final registry = SourceRegistry.read(source);
  var drifted = false;
  for (final MapEntry(key: target, value: variant) in targets.entries) {
    // L'export public (ADR 0020 §12) n'a pas le catalogue du site.
    if (!Directory(target.split('/').take(2).join('/')).existsSync()) continue;
    final generated = normalize(entriesSource(registry, variant: variant));
    final file = File(target);
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == generated) {
      stdout.writeln('gen_verify_entries: $target à jour');
    } else if (args.contains('--check')) {
      stderr.writeln(
        'gen_verify_entries: $target dérive de items/*.json, '
        'lancez dart run packages/fliin/tool/gen_verify_entries.dart',
      );
      drifted = true;
    } else {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(generated);
      stdout.writeln('gen_verify_entries: $target écrit');
    }
  }
  if (drifted) exit(1);
}

String entriesSource(SourceRegistry registry, {required String variant}) {
  final specs = {
    for (final manifest in registry.manifests) manifest: ?manifest.verify,
  };
  final imports = {
    'package:fliin_ui/core/fliin.dart',
    for (final verify in specs.values)
      for (final target in verify.imports)
        'package:fliin_ui/${target.alias.name}/${target.path}',
  }.toList()..sort();
  return '''
// Généré par packages/fliin/tool/gen_verify_entries.dart depuis items/*.json.
// Ne pas éditer : modifier verify dans le manifeste puis relancer.
// Les entrées sont le Dart des manifestes, tel que fliin verify l'écrit.
// ignore_for_file: type=lint
import '$variant';
${[for (final uri in imports) "import '$uri';"].join('\n')}
import 'package:flutter/widgets.dart';

/// Ce que `fliin verify` rend pour un élément aux jetons par défaut.
typedef FlReferenceEntry = ({
  String version,
  Size? canvas,
  Map<TargetPlatform, Size> platformCanvas,
  Duration? settle,
  Widget Function(BuildContext context, FlVariant variant) entry,
});

/// Par nom d'élément.
final Map<String, FlReferenceEntry> verifyEntries = {
${[for (final MapEntry(key: manifest, value: verify) in specs.entries) """  '${manifest.name}': (
    version: '${manifest.version}',
    canvas: ${switch (verify.canvas?.ios) {
      null => 'null',
      (:final width, :final height) => 'const Size($width, $height)',
    }},
    platformCanvas: ${switch (verify.canvas) {
      PlatformCanvas(android: (:final width, :final height)) => 'const {TargetPlatform.android: Size($width, $height)}',
      _ => 'const {}',
    }},
    settle: ${verify.settleMs == null ? 'null' : 'const Duration(milliseconds: ${verify.settleMs})'},
    entry: ${verifyEntryClosure('Fl', verify.entry.replaceAll('{prefix}', 'Fl'))},
  ),"""].join('\n')}
};
''';
}

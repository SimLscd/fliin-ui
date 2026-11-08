// Copie flutter/harness/lib/fliin_harness.dart dans le CLI, qui l'écrit dans
// test/.fliin/ du projet de l'utilisateur (ADR §4.1 : un seul harnais).
// `--check` : sortie 1 si la copie dérive de la source. Lancer depuis la racine.
import 'dart:io';

const source = 'flutter/harness/lib/fliin_harness.dart';
const target = 'packages/fliin/lib/src/verify/harness_source.g.dart';

void main(List<String> args) {
  final harness = File(source).readAsStringSync();
  if (harness.contains("'''")) {
    stderr.writeln(
      "embed_harness: $source contient ''', impossible en chaîne brute",
    );
    exit(2);
  }
  final generated =
      '// Généré par tool/embed_harness.dart depuis $source. Ne pas éditer.\n'
      "const harnessSource = r'''\n$harness''';\n";
  final file = File(target);
  if (args.contains('--check')) {
    if (!file.existsSync() || file.readAsStringSync() != generated) {
      stderr.writeln(
        'embed_harness: $target dérive de $source, lancez dart run tool/embed_harness.dart',
      );
      exit(1);
    }
    stdout.writeln('embed_harness: copie à jour');
    return;
  }
  file.writeAsStringSync(generated);
  stdout.writeln('embed_harness: $target écrit');
}

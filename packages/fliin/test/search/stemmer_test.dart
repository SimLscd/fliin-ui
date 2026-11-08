import 'dart:io';
import 'dart:isolate';

import 'package:fliin/src/search/analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart';

/// Une ligne sur 416 de `french/voc.txt` et `french/output.txt`, dépôt
/// snowballstem/snowball-data au commit 1d45f4696c91 : l'algorithme français
/// de Snowball 2.1.0, qui a généré le code vendorisé.
const _reference = [
  ('a', 'a'),
  ('adonnent', 'adonnent'),
  ('altéra', 'alter'),
  ('appris', 'appris'),
  ('attelé', 'attel'),
  ('banquettes', 'banquet'),
  ('bouffe', 'bouff'),
  ('camarilla', 'camarill'),
  ('chapons', 'chapon'),
  ('coffre', 'coffr'),
  ('conduisit', 'conduis'),
  ('conversation', 'convers'),
  ('crotte', 'crott'),
  ('dégrader', 'dégrad'),
  ('desquels', 'desquel'),
  ('dissent', 'dissent'),
  ('échelon', 'échelon'),
  ('émigrants', 'émigr'),
  ('entiché', 'entich'),
  ('établissant', 'établ'),
  ('exposé', 'expos'),
  ('finie', 'fin'),
  ('fuirais', 'fuir'),
  ('granitoïdes', 'granitoïd'),
  ('his', 'his'),
  ('inaccoutumée', 'inaccoutum'),
  ('institutions', 'institu'),
  ('joue', 'jou'),
  ('libres', 'libr'),
  ('maniable', 'maniabl'),
  ('mériter', 'mérit'),
  ('motrices', 'motric'),
  ('numéros', 'numéros'),
  ('oublierez', 'oubli'),
  ('parviendras', 'parviendr'),
  ('pétition', 'pétit'),
  ('port', 'port'),
  ('prétoire', 'prétoir'),
  ('punit', 'pun'),
  ('recherchés', 'recherch'),
  ('remarquâtes', 'remarqu'),
  ('rescousse', 'rescouss'),
  ('rigoureux', 'rigour'),
  ('sauvera', 'sauv'),
  ('significatif', 'signif'),
  ('spectateur', 'spectateur'),
  ('tachetée', 'tachet'),
  ('tordre', 'tordr'),
  ('trouverions', 'trouv'),
  ('victoire', 'victoir'),
];

/// Des mots en -ment de `french/voc.txt` et leur sortie Snowball : le cas 15
/// de r_standard_suffix les raccourcit puis échoue, et r_residual_suffix
/// relit le curseur ; « suivent » d'abord, comme dans le scénario rapporté.
const _ment = [
  ('suivent', 'suivent'),
  ('document', 'docu'),
  ('documents', 'docu'),
  ('absolument', 'absolu'),
  ('apparemment', 'apparent'),
  ('évidemment', 'évident'),
  ('monuments', 'monu'),
  ('vraiment', 'vrai'),
];

void main() {
  test('devrait raciniser comme Snowball quand on lui donne les mots de référence français', () {
    expect(_reference, hasLength(50));
    for (final (word, stem) in _reference) {
      expect(frenchStem(word), stem, reason: word);
    }
  });

  test('devrait ramener le pluriel au singulier quand le mot est anglais', () {
    expect(englishStem('buttons'), englishStem('button'));
    expect(englishStem('forms'), englishStem('form'));
  });

  // Compilé AOT, parce que le JIT n'optimise stem() qu'après des milliers
  // d'appels, et seul le code optimisé relisait `limit` périmé après un catch.
  test('devrait raciniser les mots en -ment comme Snowball quand le stemmer partagé tourne compilé AOT', () async {
    final dir = tempDir().path;
    final main = File(p.join(dir, 'stem.dart'))
      ..writeAsStringSync(
        "import 'package:fliin/src/search/analyzer.dart';\n"
        'void main(List<String> words) {\n'
        '  for (final word in words) {\n'
        '    print(frenchStem(word));\n'
        '  }\n'
        '}\n',
      );
    final exe = p.join(dir, 'stem');
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--packages',
      (await Isolate.packageConfig)!.toFilePath(),
      main.path,
      '-o',
      exe,
    ]);
    expect(compiled.exitCode, 0, reason: '${compiled.stderr}');
    final run = await Process.run(exe, [for (final (word, _) in _ment) word]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect('${run.stdout}'.trimRight().split('\n'), [
      for (final (_, stem) in _ment) stem,
    ]);
  });
}

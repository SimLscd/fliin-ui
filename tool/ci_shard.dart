// Les fichiers de test d'un shard de la CI, un par ligne : `<paquet> <chemin dans le paquet>`, suivi de
// `<partie> <parties>` pour une partie d'un fichier coupé.
//
//   dart tool/ci_shard.dart <index> <total> <paquet>...
//
// Le découpage se fait par fichier, jamais par test : `--total-shards` de package:test coupe chaque fichier en
// tranches de tests contiguës, ce qui sépare les rendus de `fliinVerify` du verdict qui les lit dans la même
// exécution, et refait dans chaque shard les `setUpAll` qui créent une app Flutter. Les fichiers vont, du plus
// lourd au plus léger, au shard le moins chargé, d'après les secondes de tool/ci_weights.tsv (mesurées sur un
// runner GitHub à deux cœurs) ; un fichier qu'il ne nomme pas pèse [_unknown]. La répartition ne dépend que de
// la liste des fichiers et des poids : chaque job la recalcule seul, et l'union des shards est la liste entière.
//
// Une troisième colonne de tool/ci_weights.tsv coupe un fichier trop long pour un shard en autant de parties,
// lancées par `--total-shards <parties> --shard-index <partie>` : seulement pour un fichier dont chaque test est
// indépendant des autres (update_test.dart fourche son scénario à chaque test), jamais pour `fliinVerify`.
import 'dart:io';

/// Le poids d'un fichier que tool/ci_weights.tsv ne nomme pas encore : environ la médiane des fichiers mesurés.
const _unknown = 5;

void main(List<String> args) {
  final (index, total) = switch (args) {
    [final i, final n, _, ...] => (int.tryParse(i), int.tryParse(n)),
    _ => (null, null),
  };
  if (index == null || total == null || total < 1 || index < 0 || index >= total) {
    stderr.writeln('usage : dart tool/ci_shard.dart <index> <total> <paquet>...  (0 <= index < total)');
    exit(64);
  }
  final root = File(Platform.script.toFilePath()).parent.parent.path;
  final weights = <String, (int, int)>{};
  for (final line in File('$root/tool/ci_weights.tsv').readAsLinesSync()) {
    switch (line.split('\t')) {
      case [final seconds, final path]:
        weights[path] = (int.parse(seconds), 1);
      case [final seconds, final path, final parts]:
        // Sans shards (la CI locale), le fichier reste entier, en parallèle avec les autres.
        weights[path] = (int.parse(seconds), total == 1 ? 1 : int.parse(parts));
      default:
        throw FormatException('tool/ci_weights.tsv : ligne illisible', line);
    }
  }
  // (paquet, chemin, partie, parties, poids)
  final pieces = <(String, String, int, int, int)>[
    for (final package in args.skip(2))
      for (final entity in Directory('$root/$package/test').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('_test.dart'))
          if (entity.path.substring('$root/$package/'.length) case final path)
            if (weights['$package/$path'] ?? (_unknown, 1) case (final seconds, final parts))
              for (var part = 0; part < parts; part++) (package, path, part, parts, (seconds / parts).ceil()),
  ];
  String name((String, String, int, int, int) piece) => '${piece.$1}/${piece.$2} ${piece.$3}';
  pieces.sort((a, b) {
    final byWeight = b.$5.compareTo(a.$5);
    return byWeight != 0 ? byWeight : name(a).compareTo(name(b));
  });
  final loads = List.filled(total, 0);
  final mine = <(String, String, int, int, int)>[];
  for (final piece in pieces) {
    var lightest = 0;
    for (var shard = 1; shard < total; shard++) {
      if (loads[shard] < loads[lightest]) lightest = shard;
    }
    loads[lightest] += piece.$5;
    if (lightest == index) mine.add(piece);
  }
  mine.sort((a, b) => name(a).compareTo(name(b)));
  for (final (package, path, part, parts, _) in mine) {
    stdout.writeln(parts == 1 ? '$package $path' : '$package $path $part $parts');
  }
}

import 'dart:io';
import 'dart:math';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

void main() {
  test('devrait rendre une chaîne vide quand les deux textes sont égaux', () {
    expect(unifiedDiff('a\nb\n', 'a\r\nb\r\n', path: 'x.dart'), '');
  });

  test('devrait écrire /dev/null et tout le texte quand le fichier est ajouté ou retiré', () {
    expect(
      unifiedDiff(null, 'a\nb\n', path: 'lib/x.dart'),
      '--- /dev/null\n+++ b/lib/x.dart\n@@ -0,0 +1,2 @@\n+a\n+b\n',
    );
    expect(
      unifiedDiff('a\n', null, path: 'lib/x.dart'),
      '--- a/lib/x.dart\n+++ /dev/null\n@@ -1 +0,0 @@\n-a\n',
    );
  });

  test('devrait séparer deux changements distants de plus de six lignes, et les réunir sinon', () {
    final base = [for (var i = 0; i < 20; i++) 'l$i\n'];
    String edited(List<int> at) =>
        [for (final (i, line) in base.indexed) at.contains(i) ? 'X$i\n' : line]
            .join();
    final apart = unifiedDiff(base.join(), edited([2, 10]), path: 'f');
    expect(RegExp('^@@', multiLine: true).allMatches(apart), hasLength(2));
    final near = unifiedDiff(base.join(), edited([2, 9]), path: 'f');
    expect(RegExp('^@@', multiLine: true).allMatches(near), hasLength(1));
  });

  group('oracle git diff --no-index', () {
    final git = _gitAvailable();
    for (final (name, repeated) in [
      ('à lignes uniques', 0),
      ('où 30 % des lignes se répètent comme dans du Dart formaté', 3),
    ]) {
      test(
        'devrait produire les mêmes lignes que git sur un corpus $name (300 graines fixes)',
        () {
          final work = Directory.systemTemp.createTempSync('fliin_unified_');
          addTearDown(() => work.deleteSync(recursive: true));
          for (var seed = 0; seed < 300; seed++) {
            final (before, after) = _case(Random(seed), repeated: repeated);
            expect(
              unifiedDiff(before, after, path: 'f'),
              _git(work, before, after),
              reason: 'graine $seed\n--- avant\n$before--- après\n$after',
            );
          }
        },
        skip: git ? false : 'git absent : l’oracle ne peut pas tourner',
      );
    }
  });
}

bool _gitAvailable() {
  try {
    return Process.runSync('git', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Le diff de git, ses en-têtes ramenés à `a/f` et `b/f` et l'en-tête de
/// fonction retiré des lignes `@@`.
String _git(Directory work, String before, String after) {
  File('${work.path}/a').writeAsStringSync(before);
  File('${work.path}/b').writeAsStringSync(after);
  final run = Process.runSync('git', [
    '-c',
    'core.quotePath=false',
    'diff',
    '--no-index',
    '--no-color',
    '--no-indent-heuristic',
    '-U3',
    'a',
    'b',
  ], workingDirectory: work.path);
  if (run.exitCode > 1) throw StateError('git diff : ${run.stderr}');
  final lines = (run.stdout as String).split('\n');
  final start = lines.indexWhere((l) => l.startsWith('--- '));
  if (start < 0) return '';
  return [
    '--- a/f',
    '+++ b/f',
    for (final line in lines.skip(start + 2))
      line.startsWith('@@')
          ? line.substring(0, line.indexOf('@@', 2) + 2)
          : line,
  ].join('\n');
}

const _common = ['}\n', '\n', '  @override\n', '    );\n', '  }\n'];

/// Un texte, puis une copie modifiée par suppressions, insertions et
/// remplacements ; parfois sans LF final.
(String, String) _case(Random random, {required int repeated}) {
  var fresh = 0;
  String line() => random.nextInt(10) < repeated
      ? _common[random.nextInt(_common.length)]
      : 'n${fresh++}\n';
  final base = [
    for (var i = 0; i < 1 + random.nextInt(30); i++)
      random.nextInt(10) < repeated
          ? _common[random.nextInt(_common.length)]
          : 'b$i\n',
  ];
  final lines = List.of(base);
  for (var e = 1 + random.nextInt(4); e > 0; e--) {
    final at = random.nextInt(lines.length + 1);
    final remove = min(random.nextInt(3), lines.length - at);
    lines.replaceRange(at, at + remove, [
      for (var k = random.nextInt(3); k > 0; k--) line(),
    ]);
  }
  String text(List<String> lines) {
    final joined = lines.join();
    return joined.isNotEmpty && random.nextInt(6) == 0
        ? joined.substring(0, joined.length - 1)
        : joined;
  }

  return (text(base), text(lines));
}

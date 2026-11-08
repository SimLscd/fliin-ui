import 'dart:io';
import 'dart:math';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

MergeResult merge(String local, String base, String upstream) => diff3(
  local: local,
  base: base,
  upstream: upstream,
  upstreamLabel: 'button@0.2.0',
);

String lines(String letters) =>
    [for (final c in letters.split('')) '$c\n'].join();

void main() {
  group('cas classiques', () {
    test('devrait prendre les deux côtés quand leurs modifications sont disjointes', () {
      final result = merge(
        lines('aXcdefg'),
        lines('abcdefg'),
        lines('abcdeYg'),
      );
      expect(result.clean, isTrue);
      expect(result.text, lines('aXcdeYg'));
    });

    test('devrait rendre une seule fois une modification faite à l’identique des deux côtés', () {
      final result = merge(lines('aXcd'), lines('abcd'), lines('aXcd'));
      expect(result.clean, isTrue);
      expect(result.text, lines('aXcd'));
    });

    test('devrait écrire un conflit diff3 étiqueté quand les deux côtés changent la même ligne', () {
      final result = merge(lines('aXc'), lines('abc'), lines('aYc'));
      expect(result.conflicts, 1);
      expect(
        result.text,
        'a\n'
        '<<<<<<< local\nX\n'
        '||||||| base\nb\n'
        '=======\nY\n'
        '>>>>>>> button@0.2.0\n'
        'c\n',
      );
    });

    test('devrait mettre en conflit deux modifications qui se touchent sans ligne commune entre elles, comme git', () {
      final result = merge(lines('aXcd'), lines('abcd'), lines('abYd'));
      expect(result.conflicts, 1);
      expect(
        result.text,
        contains('<<<<<<< local\nX\nc\n||||||| base\nb\nc\n=======\nb\nY\n'),
      );
    });

    test('devrait garder les deux ajouts quand chaque côté ajoute en fin de fichier un texte différent, en conflit', () {
      final result = merge(lines('abX'), lines('ab'), lines('abY'));
      expect(result.conflicts, 1);
      expect(
        result.text,
        'a\nb\n<<<<<<< local\nX\n||||||| base\n=======\nY\n>>>>>>> button@0.2.0\n',
      );
    });

    test('devrait rendre l’amont quand le local est la base, et le local quand l’amont est la base', () {
      expect(merge(lines('ab'), lines('ab'), lines('aZ')).text, lines('aZ'));
      expect(merge(lines('aZ'), lines('ab'), lines('ab')).text, lines('aZ'));
    });

    test('devrait fusionner depuis une base vide', () {
      expect(merge('', '', lines('ab')).text, lines('ab'));
      final both = merge(lines('x'), '', lines('y'));
      expect(both.conflicts, 1);
      expect(
        both.text,
        '<<<<<<< local\nx\n||||||| base\n=======\ny\n>>>>>>> button@0.2.0\n',
      );
    });

    test('devrait garder l’absence de LF final hors conflit et l’ajouter devant un marqueur', () {
      expect(merge('a\nX\nc', 'a\nb\nc', 'a\nb\nc').text, 'a\nX\nc');
      expect(merge('X\nb\nc', 'a\nb\nc', 'a\nb\nZ').text, 'X\nb\nZ');
      final result = merge('a\nX', 'a\nb', 'a\nY');
      expect(
        result.text,
        'a\n<<<<<<< local\nX\n||||||| base\nb\n=======\nY\n>>>>>>> button@0.2.0\n',
      );
    });

    test('devrait ramener CRLF à LF', () {
      final result = merge('a\r\nX\r\nc\r\n', 'a\nb\nc\n', 'a\r\nb\r\nc\r\n');
      expect(result.text, 'a\nX\nc\n');
    });
  });

  test('devrait fusionner 10 000 lignes réécrites en moins de 2 s sans grossir de plus de 200 Mo (M1)', () {
    final random = Random(1);
    final base = [
      for (var i = 0; i < 10000; i++) 'line $i ${random.nextInt(1 << 30)}\n',
    ];
    String side(int seed, double rate) {
      final r = Random(seed);
      return [
        for (final line in base)
          r.nextDouble() < rate ? 'chg ${r.nextInt(1 << 30)}\n' : line,
      ].join();
    }

    final rss = ProcessInfo.currentRss;
    for (final rate in [0.1, 0.5, 1.0]) {
      final watch = Stopwatch()..start();
      final result = merge(side(2, rate), base.join(), side(3, rate));
      expect(watch.elapsedMilliseconds, lessThan(2000), reason: 'taux $rate');
      expect(result.text, isNotEmpty);
    }
    expect(ProcessInfo.maxRss - rss, lessThan(200 << 20));
  });

  group('oracle git merge-file --diff3', () {
    final git = _gitAvailable();
    for (final (name, repeated) in [
      ('à lignes uniques', 0),
      ('où 30 % des lignes se répètent comme dans du Dart formaté', 3),
      ('fait des 5 seules lignes qui se répètent', 10),
    ]) {
      test(
        'devrait produire le même texte et le même nombre de conflits que git sur un corpus $name (400 graines fixes)',
        () {
          final work = Directory.systemTemp.createTempSync('fliin_diff3_');
          addTearDown(() => work.deleteSync(recursive: true));
          var conflicted = 0;
          for (var seed = 0; seed < 400; seed++) {
            final c = _case(Random(seed), repeated: repeated);
            final expected = _git(work, c);
            final actual = merge(c.local, c.base, c.upstream);
            if (!expected.clean) conflicted++;
            expect(
              (actual.text, actual.conflicts),
              (expected.text, expected.conflicts),
              reason:
                  'graine $seed\n--- base\n${c.base}--- local\n${c.local}--- amont\n${c.upstream}',
            );
          }
          expect(
            conflicted,
            inInclusiveRange(100, 300),
            reason: 'le corpus doit mêler fusions propres et conflits',
          );
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

typedef _Case = ({String local, String base, String upstream});

MergeResult _git(Directory work, _Case c) {
  File('${work.path}/o').writeAsStringSync(c.local);
  File('${work.path}/b').writeAsStringSync(c.base);
  File('${work.path}/t').writeAsStringSync(c.upstream);
  final run = Process.runSync('git', [
    'merge-file',
    '-p',
    '--diff3',
    '-L',
    'local',
    '-L',
    'base',
    '-L',
    'button@0.2.0',
    'o',
    'b',
    't',
  ], workingDirectory: work.path);
  if (run.exitCode < 0) throw StateError('git merge-file : ${run.stderr}');
  return MergeResult(run.stdout as String, run.exitCode);
}

/// Les lignes qui se répètent dans du Dart formaté.
const _common = ['}\n', '\n', '  @override\n', '    );\n', '  }\n'];

/// Une base, puis deux côtés obtenus par suppressions, insertions et
/// remplacements ; parfois la même modification des deux côtés, parfois sans
/// LF final.
/// [repeated] sur 10 lignes sont tirées de [_common].
_Case _case(Random random, {required int repeated}) {
  var fresh = 0;
  String line() => random.nextInt(10) < repeated
      ? _common[random.nextInt(_common.length)]
      : 'n${fresh++}\n';
  final base = [
    for (var i = 0; i < random.nextInt(16); i++)
      random.nextInt(10) < repeated
          ? _common[random.nextInt(_common.length)]
          : 'b$i\n',
  ];

  List<String> edit(List<String> from) {
    final lines = List.of(from);
    for (var e = random.nextInt(4); e > 0; e--) {
      final at = lines.isEmpty ? 0 : random.nextInt(lines.length + 1);
      final remove = min(random.nextInt(3), lines.length - at);
      lines.replaceRange(at, at + remove, [
        for (var k = random.nextInt(3); k > 0; k--) line(),
      ]);
    }
    return lines;
  }

  final local = edit(base);
  final upstream = random.nextInt(5) == 0 ? List.of(local) : edit(base);
  String text(List<String> lines) {
    final joined = lines.join();
    return joined.isNotEmpty && random.nextInt(6) == 0
        ? joined.substring(0, joined.length - 1)
        : joined;
  }

  return (local: text(local), base: text(base), upstream: text(upstream));
}

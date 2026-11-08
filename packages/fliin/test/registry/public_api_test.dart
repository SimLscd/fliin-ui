import 'dart:io';

import 'package:fliin/src/registry/public_api.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

List<BreakingChange> breaks(String before, String after) =>
    apiBreaks(publicApi([before]), publicApi([after]));

void main() {
  group('relecture', relectureTests);
  test('devrait ne rien signaler quand la source ne change pas, sur chaque fichier Dart du registre', () {
    final sources = [
      for (final file in Directory(
        p.join(sourceRoot, 'lib'),
      ).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.readAsStringSync(),
    ];
    final api = publicApi(sources);
    expect(
      api.keys,
      containsAll(['FlButton', 'FlButton.new', 'FlButton.label', 'FlScope.of']),
    );
    expect(apiBreaks(api, publicApi(sources)), isEmpty);
  });

  test('devrait signaler une classe, un membre et une valeur d’énumération retirés', () {
    expect(
      breaks(
        'class FlA { final int x = 0; void go() {} }\nenum FlV { a, b }\nclass FlB {}',
        'class FlA { final int x = 0; }\nenum FlV { a }',
      ),
      [
        const RemovedDeclaration('FlA.go'),
        const RemovedDeclaration('FlB'),
        const RemovedDeclaration('FlB.new'),
        const ChangedSignature('FlV', before: 'enum {a, b}', after: 'enum {a}'),
        const RemovedDeclaration('FlV.b'),
      ],
    );
  });

  test('devrait signaler un paramètre nommé requis ajouté et un paramètre devenu requis', () {
    expect(
      breaks(
        'class FlA { FlA({String? a, int? b}); }',
        'class FlA { FlA({String? a, required int? b, required bool c}); }',
      ),
      [
        const RequiredParameterAdded('FlA.new', parameter: 'b'),
        const RequiredParameterAdded('FlA.new', parameter: 'c'),
      ],
    );
    expect(breaks('void flGo(int a) {}', 'void flGo(int a, int b) {}'), [
      const RequiredParameterAdded('flGo', parameter: 'b'),
    ]);
  });

  test('devrait signaler un type changé, un paramètre retiré et un constructeur qui perd const', () {
    expect(
      breaks(
        'class FlA { const FlA({this.label = ""}); final String label; int size(int a, [int b = 0]) => a; }',
        'class FlA { FlA({this.label = ""}); final Object label; int size(int a) => a; }',
      ),
      [
        const ChangedSignature(
          'FlA.label',
          before: 'get String',
          after: 'get Object',
        ),
        const ChangedSignature(
          'FlA.new',
          before: 'const new({String label})',
          after: 'new({Object label})',
        ),
        const ChangedSignature(
          'FlA.size',
          before: 'int(int a, [int b])',
          after: 'int(int a)',
        ),
      ],
    );
  });

  test('ne devrait rien signaler pour un ajout facultatif, un membre privé, un champ devenu accesseur ou un paramètre positionnel renommé', () {
    expect(
      breaks(
        'class FlA { FlA({int? a}); final int x = 0; void _hidden() {} void go(int a) {} }\nclass _P {}',
        'class FlA { FlA({int? a, int? b}); int get x => 0; void go(int renamed, [int? more]) {} void added() {} }',
      ),
      isEmpty,
    );
  });

  test('devrait signaler le setter perdu quand un champ devient final', () {
    expect(
      breaks('class FlA { int x = 0; }', 'class FlA { final int x = 0; }'),
      [const RemovedDeclaration('FlA.x=')],
    );
  });
}

List<String> symbols(String before, String after) => [
  for (final change in breaks(before, after))
    '${change.kind.name} ${change.toJson()['symbol']}',
];

void relectureTests() {
  test('devrait signaler un modificateur ajouté à une classe, avec le texte de la déclaration et non une fermeture (H6)', () {
    for (final modifier in ['final', 'sealed', 'abstract']) {
      expect(breaks('class FlA {}', '$modifier class FlA {}'), [
        ChangedSignature(
          'FlA',
          before: 'class',
          after: modifier == 'sealed'
              ? 'sealed class permits {}'
              : '$modifier class',
        ),
      ], reason: modifier);
    }
    expect(breaks('class FlA {}', 'class FlA<T> {}'), [
      const ChangedSignature('FlA', before: 'class', after: 'class<T>'),
    ]);
  });

  test('devrait signaler extends, implements et with changés', () {
    expect(symbols('class FlA {}', 'class FlA extends FlB {}\nclass FlB {}'), [
      'signatureChanged FlA',
    ]);
    expect(
      symbols(
        'class FlA implements FlI {}\nclass FlI {}',
        'class FlA {}\nclass FlI {}',
      ),
      ['signatureChanged FlA'],
    );
    expect(
      symbols(
        'mixin FlM {}\nclass FlA {}',
        'mixin FlM {}\nclass FlA with FlM {}',
      ),
      ['signatureChanged FlA'],
    );
  });

  test('devrait signaler une valeur d’énumération ajoutée, qui casse un switch exhaustif', () {
    expect(symbols('enum FlV { a }', 'enum FlV { a, b }'), [
      'signatureChanged FlV',
    ]);
  });

  test('devrait signaler une sous-classe ajoutée à une classe sealed', () {
    expect(
      symbols(
        'sealed class FlS {}\nclass FlA extends FlS {}',
        'sealed class FlS {}\nclass FlA extends FlS {}\nclass FlB extends FlS {}',
      ),
      ['signatureChanged FlS'],
    );
  });

  test('devrait signaler un constructeur devenu factory', () {
    expect(
      symbols(
        'class FlA { FlA(); }',
        'class FlA { FlA._(); factory FlA() => FlA._(); }',
      ),
      ['signatureChanged FlA.new'],
    );
  });

  test('devrait signaler un opérateur retiré', () {
    expect(
      symbols('class FlA { FlA operator +(FlA o) => this; }', 'class FlA {}'),
      ['removed FlA.operator +'],
    );
  });

  test('devrait signaler un membre abstrait ajouté à une classe qu’on peut étendre, pas à une classe final', () {
    expect(
      symbols('abstract class FlA {}', 'abstract class FlA { void go(); }'),
      ['signatureChanged FlA.go'],
    );
    expect(
      symbols(
        'abstract final class FlA {}',
        'abstract final class FlA { void go(); }',
      ),
      isEmpty,
    );
  });

  test('devrait signaler le setter implicite perdu quand un late final sans initialiseur devient final initialisé', () {
    expect(
      symbols(
        'class FlA { late final int x; }',
        'class FlA { final int x = 0; }',
      ),
      ['removed FlA.x='],
    );
  });

  test('ne devrait rien signaler pour des extensions anonymes inchangées, dans un autre ordre', () {
    const a = 'extension on int { int get flA => 1; }';
    const b = 'extension on int { int get flB => 2; }';
    expect(breaks('$a\n$b', '$b\n$a'), isEmpty);
  });

  test('devrait signaler un fichier Dart retiré ou renommé', () {
    expect(
      fileBreaks(
        ['@components/a/fl_a.dart', '@components/a/fl_b.dart', '@core/x.json'],
        ['@components/a/fl_a.dart', '@components/a/fl_c.dart'],
      ),
      [const RemovedDeclaration('@components/a/fl_b.dart')],
    );
  });
}

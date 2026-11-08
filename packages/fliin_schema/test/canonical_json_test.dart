import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

void main() {
  test('devrait trier les clés à tous les niveaux quand elles arrivent dans le désordre', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {'z': true, 'y': null},
        'A': [
          {'d': 'x', 'c': 'y'},
        ],
      }),
      '{"A":[{"c":"y","d":"x"}],"a":{"y":null,"z":true},"b":1}',
    );
  });

  test(
    "devrait produire la même chaîne quand seul l'ordre d'insertion change",
    () {
      expect(canonicalJson({'x': 1, 'y': 2}), canonicalJson({'y': 2, 'x': 1}));
    },
  );

  test(
    'devrait écrire les nombres sans exposant quand Dart en utiliserait un',
    () {
      expect(canonicalJson(1e21), '1000000000000000000000');
      expect(canonicalJson(1.5e-7), '0.00000015');
      expect(canonicalJson(1e-7), '0.0000001');
      expect(canonicalJson(-2.5e-3), '-0.0025');
    },
  );

  test(
    'devrait écrire un flottant entier comme un entier quand il est rond',
    () {
      expect(canonicalJson(100.0), '100');
      expect(canonicalJson(-0.0), '0');
      expect(canonicalJson([1.0, 1]), '[1,1]');
      expect(canonicalJson(123.456), '123.456');
    },
  );

  test('devrait échapper les chaînes comme JSON quand elles contiennent des guillemets', () {
    expect(canonicalJson('a"b\\c\n'), r'"a\"b\\c\n"');
    expect(canonicalJson('é'), '"é"');
  });

  test('devrait refuser une valeur quand JSON ne peut pas la représenter', () {
    expect(() => canonicalJson(double.nan), throwsArgumentError);
    expect(() => canonicalJson({1: 'a'}), throwsArgumentError);
    expect(() => canonicalJson(DateTime(2026)), throwsArgumentError);
  });
}

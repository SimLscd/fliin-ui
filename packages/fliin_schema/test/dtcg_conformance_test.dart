import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

/// La suite officielle `design-tokens/community-group`, dossier
/// `test-suite/tests/2025.10/format`, vendorisée sous `fixtures/dtcg/`
/// (voir `fixtures/dtcg/ORIGIN.md`). Chaque cas positif doit se parser et se
/// résoudre ; chaque cas négatif doit lever la [TokenError] que donne
/// `fixtures/dtcg/format-expected-errors.json`, la raison de son refus.
void main() {
  const root = 'test/fixtures/dtcg/format';
  final manifest = jsonDecode(
    File('$root/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final cases = (manifest['tests']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final expectedErrors = (jsonDecode(
    File('test/fixtures/dtcg/format-expected-errors.json').readAsStringSync(),
  ) as Map<String, Object?>).cast<String, String>();
  final errorTypes = <String, Matcher>{
    'InvalidTokenName': isA<InvalidTokenName>(),
    'UnknownTokenProperty': isA<UnknownTokenProperty>(),
    'AmbiguousNode': isA<AmbiguousNode>(),
    'UnknownTokenType': isA<UnknownTokenType>(),
    'UndeterminedTokenType': isA<UndeterminedTokenType>(),
    'InvalidTokenValue': isA<InvalidTokenValue>(),
    'MalformedTokenReference': isA<MalformedTokenReference>(),
    'UnresolvedReference': isA<UnresolvedReference>(),
    'ReferenceCycle': isA<ReferenceCycle>(),
    'ReferenceTypeMismatch': isA<ReferenceTypeMismatch>(),
  };

  test(
    'devrait couvrir les 220 cas du manifeste quand la suite est vendorisée',
    () {
      expect(cases, hasLength(220));
    },
  );

  test(
    'devrait donner une erreur attendue à chaque cas négatif, et à eux seuls',
    () {
      expect(expectedErrors.keys.toSet(), {
        for (final testCase in cases)
          if (testCase['type'] == 'NegativeEvaluationTest') testCase['id'],
      });
      expect(errorTypes.keys, containsAll(expectedErrors.values.toSet()));
    },
  );

  for (final testCase in cases) {
    final id = testCase['id']! as String;
    final input = File('$root/${testCase['input']}');
    Object? json() => jsonDecode(input.readAsStringSync());
    switch (testCase['type']) {
      case 'PositiveEvaluationTest':
        test('devrait accepter $id (${testCase['name']})', () {
          final document = TokenDocument.fromJson(json());
          resolveTokens(document);
          expect(
            TokenDocument.fromJson(document.toJson()).toJson(),
            document.toJson(),
            reason: 'la sérialisation doit être stable',
          );
          expect(
            jsonEncode(document.toJson()),
            jsonEncode(json()),
            reason: 'aller-retour sans perte, clés dans l’ordre lu',
          );
        });
      case 'NegativeEvaluationTest':
        final expected = expectedErrors[id];
        test('devrait refuser $id par $expected (${testCase['name']})', () {
          expect(
            () => resolveTokens(TokenDocument.fromJson(json())),
            throwsA(errorTypes[expected] ?? isA<Never>()),
          );
        });
      default:
        fail('type de cas inconnu : ${testCase['type']}');
    }
  }
}

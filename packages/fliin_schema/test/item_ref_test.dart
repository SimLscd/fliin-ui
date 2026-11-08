import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('ItemRef', () {
    test("devrait prendre l'espace @fliin quand la référence n'en a pas", () {
      final ref = ItemRef.parse('button');
      expect(ref.namespace, Namespace.fliin);
      expect(ref.name, 'button');
      expect(ref.version, isNull);
    });

    test(
      'devrait lire espace, nom et version quand la référence est complète',
      () {
        final ref = ItemRef.parse('@pro/confirm-sheet@1.2.0');
        expect(ref.namespace, Namespace.parse('@pro'));
        expect(ref.name, 'confirm-sheet');
        expect(ref.version, Version(1, 2, 0));
      },
    );

    test('devrait omettre @fliin quand il écrit la forme canonique', () {
      expect('${ItemRef.parse('@fliin/button@1.0.0')}', 'button@1.0.0');
      expect('${ItemRef.parse('@pro/confirm-sheet')}', '@pro/confirm-sheet');
    });

    test('devrait égaler une autre référence quand seule la graphie de @fliin diffère', () {
      expect(ItemRef.parse('@fliin/button'), ItemRef.parse('button'));
      expect(ItemRef.parse('button@1.0.0'), isNot(ItemRef.parse('button')));
    });

    test(
      "devrait refuser une référence quand le nom n'est pas en kebab-case",
      () {
        for (final text in [
          'Button',
          'my_button',
          'button-',
          '-button',
          '@Pro/x',
          'a/b',
        ]) {
          expect(
            () => ItemRef.parse(text),
            throwsFormatException,
            reason: text,
          );
        }
      },
    );

    test(
      'devrait refuser une contrainte quand une version exacte est attendue',
      () {
        expect(() => ItemRef.parse('button@^1.0.0'), throwsFormatException);
      },
    );

    test(
      'devrait exiger ou refuser la version quand le contexte le demande',
      () {
        expect(() => ItemRef.parseVersioned('button'), throwsFormatException);
        expect(
          () => ItemRef.parseUnversioned('button@1.0.0'),
          throwsFormatException,
        );
        expect(ItemRef.parseVersioned('core@0.1.0').version, Version(0, 1, 0));
      },
    );
  });

  group('ItemDependency', () {
    test('devrait lire la contrainte quand elle suit le nom', () {
      final dependency = ItemDependency.parse('@pro/confirm-sheet@^1.0.0');
      expect(dependency.ref, ItemRef.parse('@pro/confirm-sheet'));
      expect(dependency.constraint.allows(Version(1, 9, 0)), isTrue);
      expect(dependency.constraint.allows(Version(2, 0, 0)), isFalse);
    });

    test('devrait accepter toute version quand la contrainte est absente', () {
      expect(ItemDependency.parse('core').constraint.isAny, isTrue);
    });

    test('devrait réécrire la même chaîne quand elle est canonique', () {
      for (final text in ['core@^1.0.0', '@pro/x@>=1.0.0 <2.0.0', 'core']) {
        expect('${ItemDependency.parse(text)}', text);
      }
    });

    test('devrait refuser une dépendance quand la contrainte est invalide', () {
      expect(() => ItemDependency.parse('core@^banane'), throwsFormatException);
    });
  });
}

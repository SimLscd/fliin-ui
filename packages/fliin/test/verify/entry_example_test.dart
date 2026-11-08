import 'package:fliin/src/verify/entry_example.dart';
import 'package:test/test.dart';

void main() {
  group('entryExpression', () {
    test('devrait rendre l’expression seule, au préfixe Fl, quand elle tient sur une ligne', () {
      expect(
        entryExpression("{prefix}Button(label: 'Go', onPressed: () {})"),
        "FlButton(label: 'Go', onPressed: () {})",
      );
    });

    test('devrait garder la branche de gauche à droite quand l’entrée dépend de variant.dir', () {
      expect(
        entryExpression(
          "{prefix}Spinner(label: (variant.dir == TextDirection.rtl ? 'مرحبا' : 'Hello'))",
        ),
        "FlSpinner(label: 'Hello')",
      );
    });

    test('devrait rendre une expression sur plusieurs lignes sans final ni point-virgule quand elle est longue', () {
      final expression = entryExpression(
        "{prefix}ListRow(title: 'A fairly long title', subtitle: 'And a subtitle', trailing: const {prefix}Badge(label: 'New'))",
      );
      expect(expression, startsWith('FlListRow(\n  title:'));
      expect(expression, endsWith('\n)'));
      expect(expression, isNot(contains('final example')));
    });

    test('devrait désindenter l’expression quand le formateur la coupe après le signe égal', () {
      final expression = entryExpression(
        'someVeryLongIdentifierNameThatFillsTheLine.anotherLongMember.yetAnotherOne',
      );
      expect(expression, isNot(startsWith(' ')));
      expect(expression, isNot(contains('final example')));
      expect(expression, isNot(endsWith(';')));
    });

    test('devrait rendre le code tel quel quand il ne se met pas en forme', () {
      expect(entryExpression('{prefix}Button('), 'FlButton(');
    });
  });

  test('devrait rendre une déclaration pour le site quand l’entrée se met en forme', () {
    expect(
      readableEntry("{prefix}Button(label: 'Go')"),
      "final example = FlButton(label: 'Go');",
    );
  });
}

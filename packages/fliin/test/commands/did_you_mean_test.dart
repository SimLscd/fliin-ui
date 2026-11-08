import 'package:fliin/src/commands/project_command.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

void main() {
  final known = [
    for (final name in ['button', 'close-button', 'badge', 'tabs', 'text'])
      ItemRef(name),
  ];

  test('devrait proposer le nom à une lettre près quand une lettre manque', () {
    expect(
      didYouMean(ItemRef('buton'), known),
      ' Did you mean button?',
    );
  });

  test('devrait compter une inversion de deux lettres comme une faute', () {
    expect(
      didYouMean(ItemRef('buttno'), known),
      ' Did you mean button?',
    );
  });

  test('devrait proposer les plus proches d’abord quand plusieurs noms sont proches', () {
    expect(
      didYouMean(ItemRef('carx'), [
        for (final name in ['chart', 'cart', 'card']) ItemRef(name),
      ]),
      ' Did you mean card, cart?',
    );
  });

  test('ne devrait rien proposer quand aucun nom n’est proche, ni dans un autre espace de noms', () {
    expect(didYouMean(ItemRef('carousel'), known), '');
    expect(
      didYouMean(ItemRef('buton'), [
        ItemRef('button', namespace: Namespace.parse('@acme')),
      ]),
      '',
    );
  });
}

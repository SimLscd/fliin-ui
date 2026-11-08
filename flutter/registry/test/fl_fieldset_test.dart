import 'package:fliin_ui/components/fieldset/fl_fieldset.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

Widget _fieldset({String? error, List<Widget> actions = const []}) => SizedBox(
  width: 320,
  child: FlFieldset(
    legend: 'Livraison',
    description: 'Où envoyer la commande.',
    error: error,
    actions: actions,
    children: const [
      SizedBox(key: ValueKey('rue'), height: 48),
      SizedBox(key: ValueKey('ville'), height: 48),
    ],
  ),
);

void main() {
  testWidgets('devrait lire la légende comme un titre quand le lecteur d’écran passe', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(_fieldset()));
    expect(tester.getSemantics(find.text('Livraison')), isSemantics(label: 'Livraison', isHeader: true));
    semantics.dispose();
  });

  testWidgets('devrait remplacer la description par l’erreur, en danger, quand le groupe est en erreur', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(_fieldset()));
    expect(find.text('Où envoyer la commande.'), findsOneWidget);
    await tester.pumpWidget(toggleApp(_fieldset(error: 'Indiquez une adresse.')));
    expect(find.text('Où envoyer la commande.'), findsNothing);
    final error = tester.widget<Text>(find.text('Indiquez une adresse.'));
    expect(error.textSpan?.style?.color ?? error.style?.color, FlTokens.defaults.light.danger);
  });

  testWidgets('devrait espacer les champs de space.lg, à space.xl sous le titre, puis poser les actions', (
    tester,
  ) async {
    final space = FlTokens.defaults.space;
    await tester.pumpWidget(
      toggleApp(_fieldset(actions: const [SizedBox(key: ValueKey('save'), width: 80, height: 48)])),
    );
    final description = tester.getRect(find.text('Où envoyer la commande.'));
    final first = tester.getRect(find.byKey(const ValueKey('rue')));
    final second = tester.getRect(find.byKey(const ValueKey('ville')));
    final save = tester.getRect(find.byKey(const ValueKey('save')));
    expect(first.top - description.bottom, space.xl);
    expect(second.top - first.bottom, space.lg);
    expect(save.top - second.bottom, space.xl + space.xs);
    expect(first.width, 320, reason: 'les champs prennent la largeur du groupe');
  });

  testWidgets('devrait poser trailing au bout de la ligne du titre et ranger les actions selon actionsAlignment', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        const SizedBox(
          width: 320,
          child: FlFieldset(
            legend: 'Adresse',
            trailing: SizedBox(key: Key('reset'), width: 20, height: 20),
            actionsAlignment: WrapAlignment.end,
            actions: [SizedBox(key: Key('save'), width: 40, height: 20)],
            children: [SizedBox(height: 10)],
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(FlFieldset));
    expect(tester.getTopRight(find.byKey(const Key('reset'))).dx, box.right);
    expect(tester.getTopRight(find.byKey(const Key('save'))).dx, box.right);
    expect(tester.getCenter(find.byKey(const Key('reset'))).dy, closeTo(tester.getCenter(find.text('Adresse')).dy, 1));
  });
}

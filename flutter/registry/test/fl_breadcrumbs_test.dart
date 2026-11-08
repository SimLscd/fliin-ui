import 'package:fliin_ui/components/breadcrumbs/fl_breadcrumbs.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

List<FlBreadcrumb> _levels(List<String> names, List<String> opened) => [
  for (final name in names) FlBreadcrumb(label: name, onPressed: () => opened.add(name)),
];

Widget _trail(List<FlBreadcrumb> items, {double width = 360, int? maxItems}) => SizedBox(
  width: width,
  child: FlBreadcrumbs(items: items, maxItems: maxItems, expandLabel: maxItems == null ? null : 'Tout le chemin'),
);

void main() {
  testWidgets('devrait ouvrir un niveau touché, et laisser la page courante inerte', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(toggleApp(_trail(_levels(['Accueil', 'Produits', 'Ordinateur'], opened))));
    await tester.tap(find.text('Produits'));
    await tester.tap(find.text('Ordinateur'), warnIfMissed: false);
    expect(opened, ['Produits']);
    expect(find.ancestor(of: find.text('Ordinateur'), matching: find.byType(FlPressable)), findsNothing);
    expect(find.byType(FlIcon), findsNWidgets(2), reason: 'un chevron entre deux niveaux');
  });

  testWidgets('devrait commencer au début quand le fil tient sur la ligne', (tester) async {
    await tester.pumpWidget(toggleApp(_trail(_levels(['Accueil', 'Compte'], []))));
    final trail = tester.getRect(find.byType(FlBreadcrumbs));
    expect(tester.getRect(find.text('Accueil')).left, trail.left);
  });

  testWidgets('devrait montrer la page courante et couper les noms longs quand le fil ne tient pas', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        _trail(
          _levels([
            'Accueil',
            'Maison et jardin, mobilier et décoration',
            'Mobilier d’extérieur',
            'Salon de jardin en teck massif huilé',
          ], []),
          width: 300,
        ),
      ),
    );
    final trail = tester.getRect(find.byType(FlBreadcrumbs));
    final current = tester.getRect(find.text('Salon de jardin en teck massif huilé'));
    expect(current.right, closeTo(trail.right, 0.5), reason: 'ouvert à la fin');
    expect(current.width, lessThanOrEqualTo(150), reason: 'au plus la moitié de la largeur');
    expect(tester.getRect(find.text('Accueil')).right, lessThan(trail.left), reason: 'le début défile hors de vue');
  });

  testWidgets('devrait replier les niveaux du milieu derrière « … », puis les déplier quand on le touche', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final names = ['Accueil', 'Documents', 'Projets', '2026', 'Devis', 'Client A'];
    await tester.pumpWidget(toggleApp(_trail(_levels(names, []), maxItems: 3)));
    expect(find.text('Documents'), findsNothing);
    expect(find.text('Devis'), findsOneWidget);
    expect(find.text('Client A'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tout le chemin'));
    await tester.pump();
    for (final name in names) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    semantics.dispose();
  });

  testWidgets('devrait poser l’icône leading avant le nom et le séparateur donné entre les niveaux', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 360,
          child: FlBreadcrumbs(
            separator: const Text('/'),
            items: [
              FlBreadcrumb(
                label: 'Accueil',
                leading: const SizedBox(key: Key('house'), width: 4),
                onPressed: () {},
              ),
              const FlBreadcrumb(label: 'Réglages'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('/'), findsOneWidget);
    expect(find.byType(FlIcon), findsNothing, reason: 'plus de chevron');
    expect(tester.getTopLeft(find.byKey(const Key('house'))).dx, lessThan(tester.getTopLeft(find.text('Accueil')).dx));
  });
}

import 'package:fliin_ui/components/pagination/fl_pagination.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

Widget _pagination(
  int page,
  int count, {
  ValueChanged<int>? onChanged,
  double width = 360,
  bool labels = false,
  int siblings = 1,
}) => SizedBox(
  width: width,
  child: FlPagination(
    page: page,
    pageCount: count,
    onChanged: onChanged ?? (_) {},
    previousLabel: 'Précédent',
    nextLabel: 'Suivant',
    pageLabel: (n) => 'Page $n',
    showNavLabels: labels,
    siblings: siblings,
  ),
);

/// Ce que montre la rangée, dans l'ordre : les numéros et les ellipses.
List<String> _shown(WidgetTester tester) {
  final shown = [
    for (final element in find.byType(Text).evaluate())
      if ((element.widget as Text).data case final text? when text != 'Précédent' && text != 'Suivant')
        (text, (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (text, _) in shown) text];
}

void main() {
  testWidgets('devrait encadrer la page courante de ses voisines entre deux ellipses quand les pages sont nombreuses', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(_pagination(6, 20)));
    expect(_shown(tester), ['1', '…', '5', '6', '7', '…', '20']);
    await tester.pumpWidget(toggleApp(_pagination(2, 20)));
    expect(_shown(tester), ['1', '2', '3', '4', '5', '…', '20'], reason: 'autant de cases près du début');
    await tester.pumpWidget(toggleApp(_pagination(4, 5)));
    expect(_shown(tester), ['1', '2', '3', '4', '5']);
  });

  testWidgets('devrait aller à la page touchée, puis à la suivante et à la précédente', (tester) async {
    final semantics = tester.ensureSemantics();
    final pages = <int>[];
    await tester.pumpWidget(toggleApp(_pagination(6, 20, onChanged: pages.add)));
    await tester.tap(find.text('20'));
    await tester.tap(find.bySemanticsLabel('Suivant'));
    await tester.tap(find.bySemanticsLabel('Précédent'));
    expect(pages, [20, 7, 5]);
    semantics.dispose();
  });

  testWidgets('devrait éteindre précédent à la première page et suivant à la dernière', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(_pagination(1, 3)));
    expect(tester.getSemantics(find.bySemanticsLabel('Précédent')), isSemantics(isEnabled: false));
    expect(tester.getSemantics(find.bySemanticsLabel('Suivant')), isSemantics(isEnabled: true));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Page 1')),
      isSemantics(isSelected: true, isEnabled: true),
      reason: 'la page courante reste un bouton actif, choisi',
    );
    await tester.pumpWidget(toggleApp(_pagination(3, 3)));
    expect(tester.getSemantics(find.bySemanticsLabel('Suivant')), isSemantics(isEnabled: false));
    semantics.dispose();
  });

  testWidgets('devrait quitter les libellés puis les voisines quand la rangée manque de place', (tester) async {
    await tester.pumpWidget(toggleApp(_pagination(6, 20, labels: true, width: 600)));
    expect(find.text('Précédent'), findsOneWidget);
    await tester.pumpWidget(toggleApp(_pagination(6, 20, labels: true)));
    expect(find.text('Précédent'), findsNothing, reason: 'les chevrons seuls');
    expect(_shown(tester), ['1', '…', '5', '6', '7', '…', '20']);
    await tester.pumpWidget(toggleApp(_pagination(6, 20, labels: true, width: 300)));
    expect(_shown(tester), ['1', '…', '6', '…', '20'], reason: 'sans voisines');
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait remplacer les chevrons par previousIcon et nextIcon', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 360,
          child: FlPagination(
            page: 2,
            pageCount: 3,
            onChanged: (_) {},
            previousLabel: 'Précédent',
            nextLabel: 'Suivant',
            previousIcon: const SizedBox(key: Key('back')),
            nextIcon: const SizedBox(key: Key('forward')),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('back')), findsOneWidget);
    expect(find.byKey(const Key('forward')), findsOneWidget);
    expect(find.byType(FlIcon), findsNothing);
  });
}

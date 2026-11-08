import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/button_group/fl_button_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

List<FlButtonGroupItem> _items(List<String> pressed, {bool lastEnabled = true}) => [
  for (final label in ['Copier', 'Coller', 'Couper'])
    FlButtonGroupItem(label: label, onPressed: label == 'Couper' && !lastEnabled ? null : () => pressed.add(label)),
];

/// Les coins de chaque bouton, dans l'ordre du groupe.
List<BorderRadiusGeometry> _corners(WidgetTester tester) => [
  for (final pressable in tester.widgetList<FlPressable>(find.byType(FlPressable))) pressable.borderRadius,
];

void main() {
  testWidgets('devrait appeler l’action du bouton touché, et d’aucun autre', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(toggleApp(FlButtonGroup(items: _items(pressed))));
    await tester.tap(find.text('Coller'));
    expect(pressed, ['Coller']);
  });

  testWidgets('devrait n’arrondir que les deux bouts du groupe, de début et de fin, quand il est en ligne', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(FlButtonGroup(items: _items([]))));
    final corners = _corners(tester).cast<BorderRadiusDirectional>();
    expect(corners.first.topStart, isNot(Radius.zero));
    expect(corners.first.topEnd, Radius.zero);
    expect(corners[1], BorderRadiusDirectional.zero);
    expect(corners.last.topStart, Radius.zero);
    expect(corners.last.bottomEnd, isNot(Radius.zero));
  });

  testWidgets('devrait arrondir le haut du premier et le bas du dernier quand il est vertical', (tester) async {
    await tester.pumpWidget(toggleApp(FlButtonGroup(axis: Axis.vertical, items: _items([]))));
    final corners = _corners(tester).cast<BorderRadiusDirectional>();
    expect(corners.first.topStart, isNot(Radius.zero));
    expect(corners.first.bottomStart, Radius.zero);
    expect(corners.last.bottomEnd, isNot(Radius.zero));
    final rects = [
      for (final label in ['Copier', 'Coller', 'Couper']) tester.getRect(find.text(label)),
    ];
    expect(rects[0].top, lessThan(rects[1].top));
    expect(rects[1].top, lessThan(rects[2].top));
  });

  testWidgets('devrait poser un filet entre deux boutons, et aucun quand separated est faux', (tester) async {
    Finder hairlines() => find.byType(FractionallySizedBox);
    await tester.pumpWidget(toggleApp(FlButtonGroup(items: _items([]))));
    expect(hairlines(), findsNWidgets(2));
    await tester.pumpWidget(toggleApp(FlButtonGroup(separated: false, items: _items([]))));
    expect(hairlines(), findsNothing);
  });

  testWidgets('devrait partager la largeur également quand il est étendu', (tester) async {
    await tester.pumpWidget(
      toggleApp(SizedBox(width: 360, child: FlButtonGroup(expanded: true, separated: false, items: _items([])))),
    );
    final widths = {
      for (final pressable in tester.elementList(find.byType(FlPressable)))
        (pressable.renderObject! as RenderBox).size.width,
    };
    expect(widths, {120});
  });

  testWidgets('devrait désactiver un bouton seul, puis tout le groupe quand enabled est faux', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(FlButtonGroup(items: _items([], lastEnabled: false))));
    expect(tester.getSemantics(find.bySemanticsLabel('Couper')), isSemantics(isEnabled: false));
    expect(tester.getSemantics(find.bySemanticsLabel('Copier')), isSemantics(isEnabled: true));
    await tester.pumpWidget(toggleApp(FlButtonGroup(enabled: false, items: _items([]))));
    expect(tester.getSemantics(find.bySemanticsLabel('Copier')), isSemantics(isEnabled: false));
    semantics.dispose();
  });

  testWidgets('devrait remplir la bascule choisie en selected, l’écrire en onSelected et l’annoncer choisie', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        FlButtonGroup(
          items: [
            FlButtonGroupItem(label: 'Jour', selected: false, onPressed: () {}),
            FlButtonGroupItem(label: 'Semaine', selected: true, onPressed: () {}),
            FlButtonGroupItem(label: 'Mois', selected: false, onPressed: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final colors = FlTokens.defaults.light;
    expect(tester.widget<Text>(find.text('Semaine')).style?.color, colors.onSelected);
    expect(tester.widget<Text>(find.text('Jour')).style?.color, colors.onControl);
    final fills = [
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(of: find.byType(FlPressable), matching: find.byType(DecoratedBox)),
      ))
        if (box.decoration case ShapeDecoration(:final color?) when color.a > 0) color,
    ];
    expect(fills, [colors.selected]);
    expect(
      tester.getSemantics(find.text('Semaine')),
      matchesSemantics(
        label: 'Semaine',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait garder chaque libellé sur une ligne quand le groupe tient, même aux libellés inégaux', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        Center(
          child: SizedBox(
            width: 320,
            child: Align(
              child: FlButtonGroup(
                size: FlButtonSize.lg,
                items: [
                  FlButtonGroupItem(label: 'Un', onPressed: () {}),
                  FlButtonGroupItem(label: 'Deuxième choix', onPressed: () {}),
                  FlButtonGroupItem(label: 'Trois', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final line = tester.getSize(find.text('Un')).height;
    expect(tester.getSize(find.text('Deuxième choix')).height, line);
  });
}

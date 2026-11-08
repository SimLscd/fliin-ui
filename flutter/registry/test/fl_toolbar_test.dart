import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/toolbar/fl_toolbar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

const _names = ['Gras', 'Italique', 'Lien'];

/// Un bouton avant la barre, la barre, un bouton après.
Widget _page({TextDirection direction = TextDirection.ltr, Axis axis = Axis.horizontal}) => toggleApp(
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FlButton(label: 'Avant', onPressed: () {}),
      FlToolbar(
        axis: axis,
        children: [
          FlButton(label: _names[0], onPressed: () {}),
          FlButton(label: _names[1], onPressed: () {}),
          const FlSeparator(),
          FlButton(label: _names[2], onPressed: () {}),
        ],
      ),
      FlButton(label: 'Après', onPressed: () {}),
    ],
  ),
  direction: direction,
);

/// Le libellé du bouton qui a le focus.
String? _focused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  return context.findAncestorWidgetOfExactType<FlButton>()?.label;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.pump();
}

void main() {
  testWidgets('devrait passer d’un contrôle à l’autre aux flèches, sans boucler, et aux bouts par Début et Fin', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'Gras');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'Italique');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'Lien', reason: 'le filet ne prend pas le focus');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'Lien');
    await _press(tester, LogicalKeyboardKey.home);
    expect(_focused(), 'Gras');
    await _press(tester, LogicalKeyboardKey.end);
    expect(_focused(), 'Lien');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused(), 'Italique');
  });

  testWidgets('devrait inverser les flèches quand le texte va de droite à gauche', (tester) async {
    await tester.pumpWidget(_page(direction: TextDirection.rtl));
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'Gras');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused(), 'Italique');
  });

  testWidgets('devrait suivre les flèches haut et bas quand la barre est verticale', (tester) async {
    await tester.pumpWidget(_page(axis: Axis.vertical));
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused(), 'Italique');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused(), 'Gras');
  });

  testWidgets('devrait ne compter qu’un arrêt de tabulation, à l’aller comme au retour', (tester) async {
    await tester.pumpWidget(_page());
    await _press(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'Avant');
    await _press(tester, LogicalKeyboardKey.tab);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'Italique');
    await _press(tester, LogicalKeyboardKey.tab);
    expect(_focused(), 'Après', reason: 'Tab quitte la barre');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(_focused(), 'Italique', reason: 'on rentre par le contrôle quitté');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(_focused(), 'Avant');
  });

  testWidgets('devrait tracer le filet en travers de la barre, à la moitié d’un contrôle', (tester) async {
    await tester.pumpWidget(_page());
    final line = tester.getSize(find.byType(FlSeparator));
    expect(line.height, FlTokens.defaults.size.controlComfortable / 2);
    expect(line.width, lessThan(2));
  });

  testWidgets('devrait écarter les contrôles de spacing et peindre la barre attached de color', (tester) async {
    const fill = Color(0xFF123456);
    await tester.pumpWidget(
      toggleApp(
        const FlToolbar(
          variant: FlToolbarVariant.attached,
          spacing: 2,
          color: fill,
          children: [
            SizedBox(key: Key('a'), width: 10, height: 10),
            SizedBox(key: Key('b'), width: 10, height: 10),
          ],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const Key('b'))).dx - tester.getTopRight(find.byKey(const Key('a'))).dx, 2);
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(FlToolbar), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as ShapeDecoration).color, fill);
  });
}

import 'package:fliin_ui/components/kbd/fl_kbd.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

void main() {
  testWidgets('devrait dessiner le symbole ⌘ sur iOS et écrire Ctrl sur Android quand la touche est command', (
    tester,
  ) async {
    const shortcut = FlKbd(keys: [FlKbdKey.command, FlKbdKey.shift], text: 'K');
    await tester.pumpWidget(toggleApp(shortcut, platform: TargetPlatform.iOS));
    expect(find.text('Ctrl'), findsNothing);
    expect(find.byType(FlIcon), findsNWidgets(2), reason: '⌘ et ⇧ dessinés');
    expect(find.text('K'), findsOneWidget);

    await tester.pumpWidget(toggleApp(shortcut));
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
    expect(find.byType(FlIcon), findsNothing);
  });

  testWidgets('devrait dessiner les flèches sur toutes les plateformes, sans les retourner en RTL', (tester) async {
    await tester.pumpWidget(toggleApp(const FlKbd(keys: [FlKbdKey.right]), direction: TextDirection.rtl));
    final arrow = find.byType(FlIcon);
    expect(arrow, findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.ancestor(of: arrow, matching: find.byType(Directionality)).first)
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('devrait lire semanticLabel, ou les mots des touches et le texte, quand le lecteur d’écran passe', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlKbd(keys: [FlKbdKey.command], text: 'K', semanticLabel: 'Commande K'),
            FlKbd(keys: [FlKbdKey.escape]),
          ],
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    expect(find.bySemanticsLabel('Commande K'), findsOneWidget);
    expect(find.bySemanticsLabel('Esc'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('devrait poser la touche sur le fond control seulement quand la variante est filled', (tester) async {
    Color? fill(WidgetTester tester) =>
        (tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as ShapeDecoration).color;
    await tester.pumpWidget(toggleApp(const FlKbd(text: 'K')));
    expect(fill(tester), FlTokens.defaults.light.control);
    await tester.pumpWidget(toggleApp(const FlKbd(text: 'K', variant: FlKbdVariant.light)));
    expect(fill(tester), isNull);
  });

  testWidgets('devrait peindre la touche et ses symboles des couleurs données quand color et foregroundColor sont là', (
    tester,
  ) async {
    const fill = Color(0xFF123456);
    const ink = Color(0xFFFEDCBA);
    await tester.pumpWidget(
      toggleApp(
        const FlKbd(keys: [FlKbdKey.command], text: 'K', color: fill, foregroundColor: ink),
        platform: TargetPlatform.iOS,
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(FlKbd), matching: find.byType(DecoratedBox)).first,
    );
    expect((box.decoration as ShapeDecoration).color, fill);
    expect(tester.widget<FlIcon>(find.byType(FlIcon)).color, ink);
    expect(tester.widget<Text>(find.text('K')).style?.color, ink);
  });
}

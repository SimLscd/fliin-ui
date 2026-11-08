import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('devrait s’annoncer comme un bouton nommé et fermer au toucher', (tester) async {
    final semantics = tester.ensureSemantics();
    var closed = 0;
    await tester.pumpWidget(_app(FlCloseButton(label: 'Fermer', onPressed: () => closed++)));
    expect(
      tester.getSemantics(find.byType(FlCloseButton)),
      matchesSemantics(
        label: 'Fermer',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byType(FlCloseButton));
    expect(closed, 1);
    semantics.dispose();
  });

  testWidgets('devrait occuper un rond de size.closeButton et annoncer la cible tactile de la plateforme', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlCloseButton(label: 'Fermer', onPressed: () {})));
    final theme = FlTokens.defaults.size;
    // Le disque, `control` au repos ou sous le doigt.
    expect(
      tester.getSize(find.descendant(of: find.byType(FlCloseButton), matching: find.byType(ClipRRect))),
      Size.square(theme.closeButton),
    );
    expect(tester.getSize(find.byType(FlCloseButton)), Size.square(theme.closeButton));
    expect(tester.getSemantics(find.byType(FlCloseButton)).rect.size, Size.square(theme.hitTargetIos));
    semantics.dispose();
  });

  testWidgets('devrait ignorer le toucher quand onPressed est nul', (tester) async {
    await tester.pumpWidget(_app(const FlCloseButton(label: 'Fermer', onPressed: null)));
    await tester.tap(find.byType(FlCloseButton), warnIfMissed: false);
    expect(find.byType(FlCloseButton), findsOneWidget);
  });

  testWidgets('devrait poser la croix sur un disque control quand filled, et la laisser nue sinon', (tester) async {
    final colors = FlTokens.defaults.light;
    Color rest() => tester
        .widget<ColoredBox>(find.descendant(of: find.byType(ClipRRect), matching: find.byType(ColoredBox)).first)
        .color;
    await tester.pumpWidget(_app(FlCloseButton(label: 'Fermer', onPressed: () {})));
    expect(rest(), colors.control);
    await tester.pumpWidget(_app(FlCloseButton(label: 'Fermer', onPressed: () {}, filled: false)));
    await tester.pumpAndSettle();
    expect(rest().a, 0);
  });

  testWidgets('devrait poser icon à la place de la croix, à sa taille et dans sa couleur', (tester) async {
    IconThemeData? seen;
    final icon = Builder(
      builder: (context) {
        seen = IconTheme.of(context);
        return const SizedBox.square(dimension: 1);
      },
    );
    await tester.pumpWidget(_app(FlCloseButton(label: 'Baisser', icon: icon, onPressed: () {})));
    expect(find.byType(FlIcon), findsNothing);
    expect(seen?.color, FlTokens.defaults.light.onControl);
    expect(seen?.size, FlTokens.defaults.size.closeIcon);
    await tester.pumpWidget(_app(FlCloseButton(label: 'Baisser', icon: icon, filled: false, onPressed: () {})));
    expect(seen?.color, FlTokens.defaults.light.onSurfaceMuted);
  });
}

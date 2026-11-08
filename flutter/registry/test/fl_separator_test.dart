import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    brightness: Brightness.light,
    child: Center(child: child),
  ),
);

void main() {
  testWidgets('devrait tracer un pixel physique sur toute la largeur offerte quand il est fin', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const SizedBox(width: 200, child: FlSeparator())));
    expect(tester.getSize(find.byType(FlSeparator)), const Size(200, 1 / 3));
  });

  testWidgets('devrait prendre size.separatorThick quand il est épais, et la hauteur offerte quand il est vertical', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SizedBox(width: 200, child: FlSeparator(variant: FlSeparatorVariant.thick))));
    expect(tester.getSize(find.byType(FlSeparator)).height, FlTokens.defaults.size.separatorThick);
    await tester.pumpWidget(_app(const SizedBox(height: 40, child: FlSeparator(axis: Axis.vertical, thickness: 2))));
    expect(tester.getSize(find.byType(FlSeparator)), const Size(2, 40));
  });

  testWidgets('ne devrait rien occuper quand la longueur offerte est infinie', (tester) async {
    await tester.pumpWidget(_app(const Row(mainAxisSize: MainAxisSize.min, children: [FlSeparator()])));
    expect(tester.getSize(find.byType(FlSeparator)).width, 0);
  });

  testWidgets('devrait rester hors de l’arbre sémantique', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(const SizedBox(width: 200, child: FlSeparator())));
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait prendre la couleur, la longueur et les retraits donnés', (tester) async {
    final light = FlTokens.defaults.light;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 200,
          height: 100,
          // A Wrap leaves the height unbounded, as a row of links does.
          child: Wrap(
            children: [
              FlSeparator(axis: Axis.vertical, length: 16, indent: 4, endIndent: 2, color: light.separatorTertiary),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlSeparator)).height, 22);
    final line = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(FlSeparator), matching: find.byType(ColoredBox)),
    );
    expect(line.color, light.separatorTertiary);
    expect(tester.getSize(find.byType(ColoredBox)).height, 16);
    expect(tester.getTopLeft(find.byType(ColoredBox)).dy - tester.getTopLeft(find.byType(FlSeparator)).dy, 4);
  });

  testWidgets('devrait retirer indent au début de la ligne, dans le sens de lecture', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: const FlScope(
            child: Center(child: SizedBox(width: 200, child: FlSeparator(indent: 40))),
          ),
        ),
      );
      final outer = tester.getRect(find.byType(FlSeparator));
      final line = tester.getRect(find.byType(ColoredBox));
      expect(line.width, 160, reason: direction.name);
      expect(direction == TextDirection.ltr ? line.left - outer.left : outer.right - line.right, 40);
    }
  });
}

import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presets/presets.g.dart';
import 'torture/torture.g.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light, FlTokens? tokens}) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    tokens: tokens ?? FlTokens.defaults,
    brightness: brightness,
    child: Center(child: child),
  ),
);

const _content = SizedBox(key: Key('content'), width: 100, height: 40);

void main() {
  final light = FlTokens.defaults.light;

  testWidgets('devrait poser le fond de chaque variante sous son contenu', (tester) async {
    for (final (variant, color) in [
      (FlSurfaceVariant.primary, light.surfaceRaised),
      (FlSurfaceVariant.secondary, light.surfaceSecondary),
      (FlSurfaceVariant.tertiary, light.surfaceTertiary),
    ]) {
      await tester.pumpWidget(_app(FlSurface(variant: variant, child: _content)));
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FlSurface), matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as ShapeDecoration).color, color, reason: variant.name);
    }
  });

  testWidgets(
    'devrait lire l’ombre surface des jetons : très douce en clair, aucune en sombre, celle d’un thème qui la remet',
    (tester) async {
      Finder shadow() => find.descendant(of: find.byType(FlSurface), matching: find.byType(CustomPaint));
      await tester.pumpWidget(_app(const FlSurface(child: _content)));
      expect(shadow(), findsWidgets, reason: 'défaut clair, l’ombre de HeroUI v3');
      await tester.pumpWidget(_app(const FlSurface(child: _content), brightness: Brightness.dark));
      expect(shadow(), findsNothing, reason: 'défaut sombre');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            tokens: tortureA,
            child: const Center(child: FlSurface(child: _content)),
          ),
        ),
      );
      expect(shadow(), findsWidgets, reason: 'torture A remet l’ombre');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FlScope(
            tokens: tortureA,
            child: const Center(
              child: FlSurface(variant: FlSurfaceVariant.transparent, child: _content),
            ),
          ),
        ),
      );
      expect(shadow(), findsNothing, reason: 'transparente');
    },
  );

  testWidgets('devrait entourer son contenu de size.surfacePadding', (tester) async {
    await tester.pumpWidget(_app(const FlSurface(child: _content)));
    final padding = FlTokens.defaults.size.surfacePadding;
    expect(tester.getSize(find.byType(FlSurface)), Size(100 + 2 * padding, 40 + 2 * padding));
    expect(
      tester.getTopLeft(find.byKey(const Key('content'))) - tester.getTopLeft(find.byType(FlSurface)),
      Offset(padding, padding),
    );
  });

  testWidgets(
    'devrait tracer size.surfaceBorder en couleur border par-dessus le contenu, et rien quand le jeton est nul',
    (tester) async {
      BorderSide side() =>
          ((tester
                              .widget<DecoratedBox>(
                                find.descendant(of: find.byType(FlSurface), matching: find.byType(DecoratedBox)).last,
                              )
                              .decoration
                          as ShapeDecoration)
                      .shape
                  as FlContinuousBorder)
              .side;
      await tester.pumpWidget(_app(const FlSurface(child: _content)));
      expect(side(), BorderSide.none);
      await tester.pumpWidget(_app(const FlSurface(child: _content), tokens: presetOutlined));
      expect(side().width, presetOutlined.size.surfaceBorder);
      expect(side().color, presetOutlined.light.border);
      final foreground = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FlSurface), matching: find.byType(DecoratedBox)).last,
      );
      expect(foreground.position, DecorationPosition.foreground);
      await tester.pumpWidget(
        _app(
          const FlSurface(variant: FlSurfaceVariant.transparent, child: _content),
          tokens: presetOutlined,
        ),
      );
      expect(side(), BorderSide.none);
    },
  );

  testWidgets('devrait prendre radius, color, gradient et un filet outlined sans toucher au thème', (tester) async {
    const gradient = LinearGradient(colors: [Color(0x00000000), Color(0x00000001)]);
    await tester.pumpWidget(
      _app(
        FlSurface(
          variant: FlSurfaceVariant.transparent,
          radius: 6,
          color: light.surfaceSecondary,
          gradient: gradient,
          outlined: true,
          child: _content,
        ),
      ),
    );
    final boxes = tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(FlSurface), matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .toList();
    final fill = boxes.whereType<ShapeDecoration>().firstWhere((d) => d.color != null);
    expect(fill.color, light.surfaceSecondary);
    expect((fill.shape as FlContinuousBorder).radius, 6);
    expect(boxes.whereType<BoxDecoration>().single.gradient, gradient);
    final stroke = boxes.whereType<ShapeDecoration>().map((d) => (d.shape as FlContinuousBorder).side);
    expect(stroke, contains(BorderSide(color: light.border, width: FlTokens.defaults.size.border)));
  });

  testWidgets('devrait garder le rendu par défaut sans filet quand outlined est faux', (tester) async {
    await tester.pumpWidget(_app(const FlSurface(child: _content)));
    final boxes = tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(FlSurface), matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration);
    expect(boxes.whereType<BoxDecoration>(), isEmpty);
    for (final shape in boxes.whereType<ShapeDecoration>()) {
      expect((shape.shape as FlContinuousBorder).radius, FlTokens.defaults.shape.radiusCard);
    }
  });
}

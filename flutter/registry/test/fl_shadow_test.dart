import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));

Widget _shadow(List<FlShadowLayer> layers) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: FlShadow(
      layers: layers,
      shape: _shape,
      child: const SizedBox(width: 100, height: 60, child: ColoredBox(color: Color(0xFFFFFFFF))),
    ),
  ),
);

FlShadowLayer _layer(Color color, {bool inset = false}) =>
    FlShadowLayer(color: color, offset: const Offset(0, 2), blur: 4, spread: 0, inset: inset);

void main() {
  testWidgets('devrait peindre l’ombre extérieure sous le contenu, la plus basse couche d’abord', (tester) async {
    await tester.pumpWidget(_shadow([_layer(const Color(0x0F000000)), _layer(const Color(0x0A000000))]));
    expect(
      find.byType(FlShadow),
      paints
        ..path(color: const Color(0x0A000000))
        ..path(color: const Color(0x0F000000))
        ..rect(color: const Color(0xFFFFFFFF)),
    );
  });

  testWidgets('devrait peindre l’ombre intérieure par-dessus le contenu', (tester) async {
    await tester.pumpWidget(_shadow([_layer(const Color(0x33FFFFFF), inset: true)]));
    expect(
      find.byType(FlShadow),
      paints
        ..rect(color: const Color(0xFFFFFFFF))
        ..path(color: const Color(0x33FFFFFF)),
    );
  });

  testWidgets('ne devrait rien ajouter au contenu quand toutes les couches sont transparentes', (tester) async {
    await tester.pumpWidget(_shadow(FlTokens.defaults.shadow.dark.surface));
    expect(find.byType(CustomPaint), findsNothing);
  });

  test('devrait cerner et lever les cartes blanches sous surface, garder les trois couches de HeroUI v3 sous field en clair, aucune en sombre, et les trois de --overlay-shadow sous ce qui flotte', () {
    final shadow = FlTokens.defaults.shadow;
    expect(shadow.light.surface.map((l) => (l.offset.dy, l.blur, l.spread, (l.color.a * 100).round())), [
      (0.0, 0.0, 1.0, 4),
      (2.0, 8.0, 0.0, 6),
      (8.0, 24.0, 0.0, 4),
    ]);
    expect(shadow.light.field.map((l) => (l.offset.dy, l.blur, (l.color.a * 100).round())), [
      (2.0, 4.0, 4),
      (1.0, 2.0, 6),
      (0.0, 1.0, 6),
    ]);
    expect(shadow.dark.surface.every((l) => l.color.a == 0), isTrue);
    expect(shadow.dark.field.every((l) => l.color.a == 0), isTrue);
    final layers = FlTokens.defaults.shadow.light.overlay;
    expect(layers.map((l) => (l.offset.dy, l.blur, (l.color.a * 100).round())), [
      (2.0, 8.0, 6),
      (-6.0, 12.0, 3),
      (14.0, 28.0, 8),
    ]);
  });
}

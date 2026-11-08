import 'package:fliin_ui/components/chip/fl_chip.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: FlScope(
    platform: TargetPlatform.iOS,
    child: Center(child: child),
  ),
);

Color? _fill(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(find.descendant(of: find.byType(FlChip), matching: find.byType(DecoratedBox)))
                .decoration
            as ShapeDecoration)
        .color;

final _box = find.descendant(of: find.byType(FlChip), matching: find.byType(DecoratedBox));

void main() {
  final tokens = FlTokens.defaults;
  final light = tokens.light;

  testWidgets('devrait peindre le fond et le libellé de chaque remplissage dans sa couleur', (tester) async {
    for (final (variant, color, fill, ink) in [
      (FlChipVariant.primary, FlChipColor.accent, light.selected, light.onSelected),
      (FlChipVariant.soft, FlChipColor.accent, light.accentSoft, light.onAccentSoft),
      (FlChipVariant.primary, FlChipColor.neutral, light.control, light.onControl),
      (FlChipVariant.primary, FlChipColor.danger, light.dangerFill, light.onDanger),
      (FlChipVariant.secondary, FlChipColor.danger, light.control, light.danger),
      (FlChipVariant.soft, FlChipColor.danger, light.dangerSoft, light.onDangerSoft),
      (FlChipVariant.primary, FlChipColor.success, light.success, light.onSuccess),
      (FlChipVariant.secondary, FlChipColor.success, light.control, light.onSuccessSoft),
      (FlChipVariant.tertiary, FlChipColor.warning, null, light.onWarningSoft),
      (FlChipVariant.soft, FlChipColor.warning, light.warningSoft, light.onWarningSoft),
      (FlChipVariant.soft, FlChipColor.neutral, light.control, light.onControl),
    ]) {
      await tester.pumpWidget(_app(FlChip(label: 'Nouveau', variant: variant, color: color)));
      final reason = '${variant.name} ${color.name}';
      expect(_fill(tester), fill, reason: reason);
      final style = tester.widget<Text>(find.text('Nouveau')).style!;
      expect(style.color, ink, reason: reason);
      expect(style.fontWeight, tokens.typography.weight.medium, reason: reason);
    }
  });

  testWidgets('devrait faire 20, 28 et 36 de haut, avec les marges de 8, 12 et 16 de HeroUI', (tester) async {
    for (final (size, height, inset) in [
      (FlChipSize.sm, 20.0, 8.0),
      (FlChipSize.md, 28.0, 12.0),
      (FlChipSize.lg, 36.0, 16.0),
    ]) {
      await tester.pumpWidget(_app(FlChip(label: 'Nouveau', size: size)));
      expect(tester.getSize(_box).height, height, reason: size.name);
      expect(tester.getTopLeft(find.text('Nouveau')).dx - tester.getTopLeft(_box).dx, inset, reason: size.name);
    }
  });

  testWidgets('devrait garder sa largeur au début de la ligne quand une colonne l’étire', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: FlScope(
          child: const Center(
            child: SizedBox(
              key: Key('column'),
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [FlChip(label: 'Nouveau')],
              ),
            ),
          ),
        ),
      ),
    );
    final chip = tester.getRect(_box);
    expect(chip.width, lessThan(150));
    expect(chip.right, tester.getRect(find.byKey(const Key('column'))).right);
  });

  testWidgets('devrait se presser comme un bouton quand onPressed est donné, et rester un texte sinon', (tester) async {
    final handle = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(_app(FlChip(label: 'Filtre', onPressed: () => pressed++)));
    await tester.tap(find.text('Filtre'));
    expect(pressed, 1);
    expect(tester.getSemantics(find.text('Filtre')).flagsCollection.isButton, isTrue);
    await tester.pumpWidget(_app(const FlChip(label: 'Filtre')));
    expect(tester.getSemantics(find.text('Filtre')).flagsCollection.isButton, isFalse);
    handle.dispose();
  });

  testWidgets('devrait poser un point de 6 dans la couleur du libellé avant lui quand dot est vrai', (tester) async {
    await tester.pumpWidget(_app(const FlChip(label: 'Actif', color: FlChipColor.success, dot: true)));
    final dot = find.descendant(
      of: find.byType(FlChip),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).shape is CircleBorder,
      ),
    );
    expect(dot, findsOneWidget);
    expect(tester.getSize(dot), const Size.square(6));
    final ink = tester.widget<Text>(find.text('Actif')).style!.color;
    expect((tester.widget<DecoratedBox>(dot).decoration as ShapeDecoration).color, ink);
    expect(tester.getRect(dot).right, lessThan(tester.getRect(find.text('Actif')).left));
    await tester.pumpWidget(_app(const FlChip(label: 'Actif', color: FlChipColor.success)));
    expect(dot, findsNothing);
  });
}

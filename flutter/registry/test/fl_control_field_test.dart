import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pixels.dart';
import 'support/toggles.dart';

/// Une ligne que le parent tient à jour.
class _Host extends StatefulWidget {
  const _Host({super.key, this.indicator = FlControlFieldIndicator.toggle, this.initial = false});

  final FlControlFieldIndicator indicator;
  final bool initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool value = widget.initial;
  final changes = <bool>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: FlControlField(
      value: value,
      label: 'Notifications',
      description: 'Push',
      indicator: widget.indicator,
      onChanged: (next) => setState(() {
        changes.add(next);
        value = next;
      }),
    ),
  );
}

List<bool> _changes(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).changes;

/// The row's node: the one above its gesture detector, under the card.
final Finder _node = find.descendant(of: find.byType(FlControlField), matching: find.byType(GestureDetector)).first;

void main() {
  testWidgets(
    "devrait s'annoncer comme un seul interrupteur, libellé et description compris, quand l'indicateur est un switch",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(initial: true)));
      expect(
        tester.getSemantics(_node),
        matchesSemantics(
          label: 'Notifications',
          hint: 'Push',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      // Un seul nœud : ni enfant (ExcludeSemantics), ni libellés fusionnés
      // des textes et du contrôle (MergeSemantics).
      final node = tester.getSemantics(_node);
      expect(node.hasChildren, isFalse);
      expect(node.label, 'Notifications');
      semantics.dispose();
    },
  );

  testWidgets(
    "devrait s'annoncer cochée quand l'indicateur est une case, et comme une option exclusive pour un radio",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(indicator: FlControlFieldIndicator.checkbox, initial: true)));
      expect(
        tester.getSemantics(_node),
        matchesSemantics(
          label: 'Notifications',
          hint: 'Push',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.pumpWidget(toggleApp(const _Host(key: ValueKey(1), indicator: FlControlFieldIndicator.radio)));
      expect(
        tester.getSemantics(_node),
        matchesSemantics(
          label: 'Notifications',
          hint: 'Push',
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets('devrait basculer une fois quand on touche le libellé, et une fois quand on touche le contrôle', (
    tester,
  ) async {
    for (final indicator in FlControlFieldIndicator.values) {
      await tester.pumpWidget(toggleApp(_Host(key: ValueKey(indicator), indicator: indicator)));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      final control = switch (indicator) {
        FlControlFieldIndicator.toggle => find.byType(FlSwitch),
        FlControlFieldIndicator.checkbox => find.byType(FlCheckbox),
        FlControlFieldIndicator.radio => find.byType(FlRadio<bool>),
      };
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(
        _changes(tester),
        indicator == FlControlFieldIndicator.radio ? [true] : [true, false],
        reason: indicator.name,
      );
    }
  });

  testWidgets('devrait rétrécir le contrôle pendant que le doigt appuie sur la ligne', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    double scale() => tester
        .widget<Transform>(find.descendant(of: find.byType(FlSwitch), matching: find.byType(Transform)).first)
        .transform
        .storage[0];
    final gesture = await tester.startGesture(tester.getCenter(find.text('Notifications')));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(scale(), closeTo(0.96, 0.001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  testWidgets('devrait ignorer le toucher, pâlir ses textes et s’annoncer désactivée quand onChanged est nul', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(
        const SizedBox(
          width: 320,
          child: FlControlField(value: false, label: 'Notifications', description: 'Push', onChanged: null),
        ),
      ),
    );
    await tester.tap(find.text('Notifications'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final faded = find.ancestor(of: find.text('Notifications'), matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(faded).opacity, FlTokens.defaults.size.disabledOpacity);
    expect(
      tester.getSemantics(_node),
      matchesSemantics(label: 'Notifications', hint: 'Push', hasToggledState: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets(
    'devrait cerner la carte et la case de danger, garder le libellé onSurface et montrer l’erreur quand elle est invalide',
    (tester) async {
      Widget field({required bool invalid}) => SizedBox(
        width: 320,
        child: FlControlField(
          value: false,
          label: 'Conditions',
          error: 'Obligatoire',
          indicator: FlControlFieldIndicator.checkbox,
          invalid: invalid,
          onChanged: (_) {},
        ),
      );
      await tester.pumpWidget(toggleApp(field(invalid: false)));
      expect(find.text('Obligatoire'), findsNothing);
      await tester.pumpWidget(toggleApp(field(invalid: true)));
      await tester.pumpAndSettle();
      expect(find.text('Obligatoire'), findsOneWidget);
      final colors = FlTokens.defaults.light;
      final label = tester.widget<RichText>(
        find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText() == 'Conditions'),
      );
      expect(label.text.style?.color, colors.onSurface);
      final card = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FlControlField), matching: find.byType(DecoratedBox)).first,
      );
      expect(
        ((card.decoration as ShapeDecoration).shape as FlContinuousBorder).side,
        BorderSide(color: colors.danger, width: FlTokens.defaults.size.border),
      );
    },
  );

  testWidgets('devrait poser une ligne de 44 dans sa carte et offrir la cible de la plateforme', (tester) async {
    for (final (platform, guideline, target) in [
      (TargetPlatform.android, androidTapTargetGuideline, 48.0),
      (TargetPlatform.iOS, iOSTapTargetGuideline, 44.0),
    ]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlControlField(
              value: true,
              label: 'Notifications',
              indicator: FlControlFieldIndicator.checkbox,
              onChanged: (_) {},
            ),
          ),
          platform: platform,
        ),
      );
      final space = FlTokens.defaults.space;
      expect(tester.getSize(find.byType(FlControlField)).height, 44 + 2 * space.md, reason: platform.name);
      expect(tester.getSemantics(_node).rect.height, target, reason: platform.name);
      await expectLater(tester, meetsGuideline(guideline), reason: platform.name);
      semantics.dispose();
    }
  });

  testWidgets('devrait laisser le radio choisi quand on touche la ligne ou que le lecteur d’écran la touche', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(indicator: FlControlFieldIndicator.radio, initial: true)));
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    tester.semantics.tap(find.semantics.byLabel('Notifications'));
    await tester.pumpAndSettle();
    expect(_changes(tester), [true, true]);
    expect(tester.getSemantics(_node), isSemantics(isChecked: true));
    semantics.dispose();
  });

  testWidgets('devrait détacher la case et le radio non cochés de la surface sombre par leur contour fieldBorder', (
    tester,
  ) async {
    final dark = FlTokens.defaults.dark;
    for (final variant in FlControlFieldVariant.values) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: pixelsBoundary,
          child: WidgetsApp(
            color: const Color(0xFF000000),
            builder: (context, _) => FlScope(
              brightness: Brightness.dark,
              platform: TargetPlatform.iOS,
              child: ColoredBox(
                color: dark.surfaceOverlay,
                child: Center(
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final indicator in [FlControlFieldIndicator.checkbox, FlControlFieldIndicator.radio])
                          FlControlField(
                            value: false,
                            label: indicator.name,
                            indicator: indicator,
                            variant: variant,
                            onChanged: (_) {},
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = await paintedColor(tester, find.byType(FlCheckbox));
      final disc = await paintedColor(tester, radioDisc(find.byType(FlRadio<bool>)));
      final expected = variant == FlControlFieldVariant.secondary ? dark.control : dark.field;
      expect(box, expected, reason: '${variant.name} : case');
      expect(disc, expected, reason: '${variant.name} : radio');
      expect(
        find.descendant(of: find.byType(FlCheckbox), matching: find.byType(ClipPath)),
        paints..something(
          (method, arguments) =>
              method == #drawPath && (arguments[1] as Paint).color.toARGB32() == dark.fieldBorder.toARGB32(),
        ),
        reason: '${variant.name} : contour de la case',
      );
      final ring = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: find.byType(FlRadio<bool>), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .map((decoration) => decoration.shape)
          .whereType<CircleBorder>()
          .map((shape) => shape.side.color);
      expect(ring, contains(dark.fieldBorder), reason: '${variant.name} : contour du radio');
    }
    expect(dark.fieldBorder, isNot(dark.surfaceOverlay));
  });

  testWidgets('devrait poser le contrôle du côté que dit indicatorSide, quel qu’il soit', (tester) async {
    for (final (indicator, side, before) in [
      (FlControlFieldIndicator.toggle, null, false),
      (FlControlFieldIndicator.toggle, FlControlFieldSide.start, true),
      (FlControlFieldIndicator.checkbox, null, true),
      (FlControlFieldIndicator.checkbox, FlControlFieldSide.end, false),
    ]) {
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 320,
            child: FlControlField(
              value: false,
              label: 'Profil public',
              indicator: indicator,
              indicatorSide: side,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final control = tester.getRect(find.byType(indicator == FlControlFieldIndicator.toggle ? FlSwitch : FlCheckbox));
      final label = tester.getRect(find.text('Profil public'));
      expect(control.right <= label.left, before, reason: '$indicator $side');
    }
  });

  testWidgets(
    'devrait cerner de selected la carte cochée quand outlineSelected, et garder danger si elle est invalide',
    (tester) async {
      BorderSide side() =>
          ((tester
                              .widget<DecoratedBox>(
                                find
                                    .descendant(of: find.byType(FlControlField), matching: find.byType(DecoratedBox))
                                    .first,
                              )
                              .decoration
                          as ShapeDecoration)
                      .shape
                  as FlContinuousBorder)
              .side;
      Widget field({required bool value, bool invalid = false}) => SizedBox(
        width: 320,
        child: FlControlField(
          value: value,
          label: 'Express',
          indicator: FlControlFieldIndicator.radio,
          outlineSelected: true,
          invalid: invalid,
          onChanged: (_) {},
        ),
      );
      final colors = FlTokens.defaults.light;
      final border = FlTokens.defaults.size.border;
      await tester.pumpWidget(toggleApp(field(value: false)));
      expect(side(), BorderSide.none);
      await tester.pumpWidget(toggleApp(field(value: true)));
      expect(side(), BorderSide(color: colors.selected, width: border));
      await tester.pumpWidget(toggleApp(field(value: true, invalid: true)));
      expect(side(), BorderSide(color: colors.danger, width: border));
    },
  );
}

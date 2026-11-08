import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';
import 'torture/torture.g.dart';

class _Host extends StatefulWidget {
  const _Host({this.tristate = false});

  final bool tristate;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool? value = false;
  final changes = <bool?>[];

  @override
  Widget build(BuildContext context) => FlCheckbox(
    value: value,
    tristate: widget.tristate,
    label: 'Conditions',
    onChanged: (next) => setState(() {
      changes.add(next);
      value = next;
    }),
  );
}

List<bool?> _changes(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host)).changes;

/// La case de 24, découpée à sa forme.
Finder get _box => find.descendant(of: find.byType(FlCheckbox), matching: find.byType(ClipPath));

/// Le dessin de la coche ou du tiret, présent quand la case est cochée.
Finder get _mark => find.descendant(of: find.byType(FlCheckbox), matching: find.byType(CustomPaint)).last;

/// Les traits de la coche ou du tiret.
List<Path> _marks(WidgetTester tester) {
  final paths = <Path>[];
  expect(
    _mark,
    paints..everything((method, arguments) {
      if (method == #drawPath) paths.add(arguments[0] as Path);
      return true;
    }),
  );
  return paths;
}

/// La longueur dessinée de la marque, 0 avant qu'elle commence.
double _drawn(WidgetTester tester) => [
  for (final path in _marks(tester))
    for (final metric in path.computeMetrics()) metric.length,
].fold(0.0, (sum, length) => sum + length);

/// Le fond de la case, puis celui de l'indicateur quand il est entré.
List<Color?> _fills(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: find.byType(FlCheckbox), matching: find.byType(DecoratedBox)),
  ))
    switch (box.decoration) {
      final BoxDecoration d => d.color,
      final ShapeDecoration d => d.color,
      _ => null,
    },
];

List<Opacity> _opacities(WidgetTester tester) =>
    tester.widgetList<Opacity>(find.descendant(of: find.byType(FlCheckbox), matching: find.byType(Opacity))).toList();

double _scale(WidgetTester tester) => tester
    .widget<Transform>(find.descendant(of: find.byType(FlCheckbox), matching: find.byType(Transform)).first)
    .transform
    .storage[0];

void main() {
  testWidgets("devrait s'annoncer coché, activé et étiqueté quand value est vrai", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(FlCheckbox(value: true, label: 'Conditions', onChanged: (_) {})));
    expect(
      tester.getSemantics(controlOf(find.byType(FlCheckbox))),
      matchesSemantics(
        label: 'Conditions',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer mixte, ni coché ni décoché, quand tristate est vrai et value nul", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(FlCheckbox(value: null, tristate: true, label: 'Tout', onChanged: (_) {})));
    expect(
      tester.getSemantics(controlOf(find.byType(FlCheckbox))),
      matchesSemantics(
        label: 'Tout',
        hasCheckedState: true,
        isCheckStateMixed: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer désactivé, sans action, et ignorer le toucher quand onChanged est nul", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const FlCheckbox(value: false, label: 'Conditions', onChanged: null)));
    await tester.tap(find.byType(FlCheckbox), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(controlOf(find.byType(FlCheckbox))),
      matchesSemantics(label: 'Conditions', hasCheckedState: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets('devrait alterner coché et décoché au toucher quand tristate est faux', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.byType(FlCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FlCheckbox));
    await tester.pumpAndSettle();
    expect(_changes(tester), [true, false]);
  });

  testWidgets('devrait passer de décoché à coché, puis mixte, puis décoché quand tristate est vrai', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(tristate: true)));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FlCheckbox));
      await tester.pumpAndSettle();
    }
    expect(_changes(tester), [true, null, false]);
  });

  testWidgets('devrait dessiner une coche quand value est vrai, un tiret quand il est nul, rien quand il est faux', (
    tester,
  ) async {
    for (final value in [true, null, false]) {
      await tester.pumpWidget(toggleApp(FlCheckbox(value: value, tristate: true, label: 'Tout', onChanged: (_) {})));
      await tester.pumpAndSettle();
      if (value == false) {
        expect(_fills(tester), [FlTokens.defaults.light.field], reason: '$value');
        continue;
      }
      final marks = _marks(tester);
      expect(marks, hasLength(1), reason: '$value');
      expect(marks.single.getBounds().height == 0, value == null, reason: '$value');
    }
  });

  testWidgets("devrait prendre le focus à Tab, montrer l'anneau et basculer avec Espace puis Entrée", (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(find.byType(FlCheckbox), isNot(focusRingPainted));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(FlCheckbox), focusRingPainted);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_changes(tester), [true, false]);
  });

  testWidgets('devrait basculer quand on touche la marge de la cible hors de la case', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final box = tester.getRect(_box);
    await tester.tapAt(box.topCenter - const Offset(0, 8));
    await tester.pumpAndSettle();
    expect(_changes(tester), [true]);
  });

  testWidgets(
    "devrait faire entrer le fond selected en 100 ms puis dessiner la coche en 150 ms quand le mouvement n'est pas réduit",
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host()));
      await tester.tap(find.byType(FlCheckbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_opacities(tester).last.opacity, inExclusiveRange(0, 1));
      expect(_drawn(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      final drawn = _drawn(tester);
      expect(drawn, greaterThan(0));
      await tester.pumpAndSettle();
      expect(_drawn(tester), greaterThan(drawn));
      expect(_fills(tester).last, FlTokens.defaults.light.selected);
    },
  );

  testWidgets(
    'devrait faire apparaître la case cochée en fondu de 150 ms, sans échelle ni décalage, quand Reduce Motion iOS est actif',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
      await tester.tap(find.byType(FlCheckbox));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(_opacities(tester).last.opacity, closeTo(0.5, 0.05));
      final transforms = tester.widgetList<Transform>(
        find.descendant(of: find.byType(FlCheckbox), matching: find.byType(Transform)),
      );
      for (final transform in transforms) {
        expect(transform.transform.isIdentity(), isTrue);
      }
      await tester.pump(const Duration(milliseconds: 80));
      expect(_opacities(tester).last.opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'devrait garder la case de 24 au rayon radiusLg de HeroUI, et la cible de la plateforme, dans chaque densité',
    (tester) async {
      for (final tokens in [FlTokens.defaults, tortureB]) {
        for (final (platform, guideline, target) in [
          (TargetPlatform.android, androidTapTargetGuideline, tokens.size.hitTargetAndroid),
          (TargetPlatform.iOS, iOSTapTargetGuideline, tokens.size.hitTargetIos),
        ]) {
          for (final density in FlDensity.values) {
            final reason = '${platform.name} ${density.name}';
            final semantics = tester.ensureSemantics();
            await tester.pumpWidget(
              toggleApp(
                FlCheckbox(value: false, label: 'Conditions', onChanged: (_) {}),
                platform: platform,
                density: density,
                tokens: tokens,
              ),
            );
            expect(tester.getSize(_box), const Size.square(24), reason: reason);
            final clip = tester.widget<ClipPath>(_box).clipper! as ShapeBorderClipper;
            expect(clip.shape, FlContinuousBorder(radius: tokens.shape.radiusLg), reason: reason);
            final rect = tester.getSemantics(controlOf(find.byType(FlCheckbox))).rect;
            expect(rect.width, greaterThanOrEqualTo(target), reason: reason);
            expect(rect.height, greaterThanOrEqualTo(target), reason: reason);
            await expectLater(tester, meetsGuideline(guideline), reason: reason);
            semantics.dispose();
          }
        }
      }
    },
  );

  testWidgets('devrait peindre le fond field en primary et control en secondary, et selected une fois cochée', (
    tester,
  ) async {
    final colors = FlTokens.defaults.light;
    for (final (variant, value, fills) in [
      (FlCheckboxVariant.primary, false, [colors.field]),
      (FlCheckboxVariant.secondary, false, [colors.control]),
      (FlCheckboxVariant.primary, true, [colors.field, colors.selected]),
      (FlCheckboxVariant.primary, null, [colors.field, colors.selected]),
    ]) {
      await tester.pumpWidget(
        toggleApp(FlCheckbox(value: value, tristate: true, variant: variant, label: 'Conditions', onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(_fills(tester), fills, reason: '${variant.name} $value');
      if (value != false) expect(_mark, paints..path(color: colors.onSelected), reason: '${variant.name} $value');
    }
  });

  testWidgets('devrait cerner la case vide d’un filet border sous l’ombre field, et de fieldBorder sans ombre', (
    tester,
  ) async {
    final colors = FlTokens.defaults.light;
    PaintPattern contour(Color color) => paints
      ..something(
        (method, arguments) => method == #drawPath && (arguments[1] as Paint).color.toARGB32() == color.toARGB32(),
      );
    await tester.pumpWidget(toggleApp(FlCheckbox(value: false, label: 'Conditions', onChanged: (_) {})));
    expect(_box, contour(colors.border));
    await tester.pumpWidget(
      toggleApp(FlCheckbox(value: false, variant: FlCheckboxVariant.secondary, label: 'Conditions', onChanged: (_) {})),
    );
    expect(_box, contour(colors.fieldBorder));
    final contourOff = contour(colors.border);
    await tester.pumpWidget(toggleApp(FlCheckbox(value: false, invalid: true, label: 'Conditions', onChanged: (_) {})));
    expect(_box, isNot(contourOff));
  });

  testWidgets(
    'devrait se cerner de danger sur son fond décochée et se remplir de danger cochée, quand elle est invalide ou dans un champ invalide',
    (tester) async {
      final colors = FlTokens.defaults.light;
      final ring = paints
        ..something(
          (method, arguments) =>
              method == #drawPath && (arguments[1] as Paint).color.toARGB32() == colors.danger.toARGB32(),
        );
      for (final (value, fills) in [
        (false, <Color?>[colors.field]),
        (true, [colors.field, colors.danger]),
      ]) {
        for (final scoped in [false, true]) {
          final box = FlCheckbox(value: value, invalid: scoped ? null : true, label: 'Conditions', onChanged: (_) {});
          await tester.pumpWidget(toggleApp(scoped ? FlFieldScope(invalid: true, child: box) : box));
          await tester.pumpAndSettle();
          expect(_fills(tester), fills, reason: '$value $scoped');
          expect(find.descendant(of: find.byType(FlCheckbox), matching: find.byType(CustomPaint)).first, ring);
        }
      }
    },
  );

  testWidgets('devrait passer à disabledOpacity quand elle est désactivée, ou dans un champ désactivé', (tester) async {
    final disabled = FlTokens.defaults.size.disabledOpacity;
    await tester.pumpWidget(toggleApp(const FlCheckbox(value: true, label: 'Conditions', onChanged: null)));
    expect(_opacities(tester).first.opacity, disabled);
    await tester.pumpWidget(
      toggleApp(
        FlFieldScope(
          disabled: true,
          child: FlCheckbox(value: true, label: 'Conditions', onChanged: (_) {}),
        ),
      ),
    );
    expect(_opacities(tester).first.opacity, disabled);
    await tester.pumpWidget(toggleApp(FlCheckbox(value: true, label: 'Conditions', onChanged: (_) {})));
    expect(_opacities(tester).first.opacity, 1);
  });

  testWidgets('devrait rétrécir à 0,96 pendant que le doigt appuie, ou que son statesController est pressé', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final gesture = await tester.startGesture(tester.getCenter(_box));
    await tester.pump(kPressTimeout);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(0.96, 0.001));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);

    final states = WidgetStatesController();
    addTearDown(states.dispose);
    await tester.pumpWidget(
      toggleApp(FlCheckbox(value: false, label: 'Conditions', onChanged: (_) {}, statesController: states)),
    );
    states.update(WidgetState.pressed, true);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(0.96, 0.001));
  });

  testWidgets('devrait garder sa place de 24, la cible hors de la mise en page, quand un FlFieldScope l’entoure', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        FlFieldScope(
          child: FlCheckbox(value: false, label: 'Conditions', onChanged: (_) {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlCheckbox)), const Size.square(24));
  });

  testWidgets('devrait focaliser le nœud fourni sans le libérer quand la case disparaît', (tester) async {
    final node = FocusNode(debugLabel: 'conditions');
    var toggles = 0;
    await tester.pumpWidget(
      toggleApp(FlCheckbox(value: false, label: 'Conditions', focusNode: node, onChanged: (_) => toggles++)),
    );
    node.requestFocus();
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(toggles, 1, reason: 'la case focalisée par son nœud bascule à Espace');

    await tester.pumpWidget(toggleApp(const SizedBox()));
    // Un nœud libéré lève à son prochain usage : celui-ci reste à l'appelant.
    node.addListener(() {});
    node.dispose();
  });

  testWidgets('devrait lire l’indice donné après le nom, sur le nœud de la case', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(FlCheckbox(value: false, label: 'Conditions', hint: 'Acceptez les conditions.', onChanged: (_) {})),
    );
    final data = tester.getSemantics(controlOf(find.byType(FlCheckbox))).getSemanticsData();
    expect(data.label, 'Conditions');
    expect(data.hint, 'Acceptez les conditions.');
    semantics.dispose();
  });
}

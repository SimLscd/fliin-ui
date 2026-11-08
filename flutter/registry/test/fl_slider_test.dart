import 'package:fliin_ui/components/slider/fl_slider.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

/// Un curseur que le parent tient à jour, comme dans une vraie app.
class _Host extends StatefulWidget {
  const _Host({this.initial = 0.4, this.divisions, this.enabled = true, this.axis = Axis.horizontal});

  final double initial;
  final int? divisions;
  final bool enabled;
  final Axis axis;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double value = widget.initial;
  final changes = <double>[];
  final ends = <double>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.axis == Axis.horizontal ? 300 : null,
    height: widget.axis == Axis.vertical ? 300 : null,
    child: FlSlider(
      value: value,
      label: 'Volume',
      divisions: widget.divisions,
      axis: widget.axis,
      onChangeEnd: ends.add,
      onChanged: widget.enabled
          ? (next) {
              changes.add(next);
              setState(() => value = next);
            }
          : null,
    ),
  );
}

/// Un curseur de plage tenu par le parent.
class _RangeHost extends StatefulWidget {
  const _RangeHost();

  @override
  State<_RangeHost> createState() => _RangeHostState();
}

class _RangeHostState extends State<_RangeHost> {
  FlSliderRange values = (start: 0.2, end: 0.7);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: FlRangeSlider(
      values: values,
      label: 'Prix',
      startLabel: 'Prix minimum',
      endLabel: 'Prix maximum',
      onChanged: (next) => setState(() => values = next),
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

_RangeHostState _range(WidgetTester tester) => tester.state<_RangeHostState>(find.byType(_RangeHost));

/// Le pouce de 28 sur 20 (horizontal) : les conteneurs `selected`, dans l'ordre.
List<Rect> _thumbs(WidgetTester tester) => [
  for (final element in find.byType(FocusableActionDetector).evaluate())
    tester.getRect(find.descendant(of: find.byWidget(element.widget), matching: find.byType(SizedBox)).first),
];

/// La longueur du pouce (28) : il reste dans la piste, son centre court de
/// la moitié de sa longueur à l'autre bout moins autant (HeroUI v3).
const double _thumbLength = 28;

/// Le point de la piste à la fraction [t] de la course du centre du pouce,
/// décalé de [across] perpendiculairement.
Offset _at(WidgetTester tester, double t, {TextDirection direction = TextDirection.ltr, double across = 0}) {
  final slider = find.byType(FlSlider).evaluate().isEmpty ? find.byType(FlRangeSlider) : find.byType(FlSlider);
  final rect = tester.getRect(slider);
  final along = _thumbLength / 2 + t * (rect.width - _thumbLength);
  return Offset(direction == TextDirection.ltr ? rect.left + along : rect.right - along, rect.center.dy + across);
}

void main() {
  testWidgets("devrait s'annoncer comme un curseur avec sa valeur, les valeurs voisines et les actions d'ajustement", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Volume')),
      matchesSemantics(
        label: 'Volume',
        isSlider: true,
        value: '40%',
        increasedValue: '41%',
        decreasedValue: '39%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    tester.semantics.performAction(find.semantics.byLabel('Volume'), SemanticsAction.increase);
    await tester.pump();
    expect(_host(tester).changes.single, closeTo(0.41, 1e-9));
    expect(_host(tester).ends.single, closeTo(0.41, 1e-9));
    semantics.dispose();
  });

  testWidgets(
    "devrait s'annoncer désactivé, passer à demi opaque et ignorer toucher et clavier quand onChanged est nul",
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(toggleApp(const _Host(enabled: false)));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Volume')),
        matchesSemantics(label: 'Volume', isSlider: true, value: '40%', hasEnabledState: true),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, FlTokens.defaults.size.disabledOpacity);
      await tester.tapAt(_at(tester, 0.9));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_host(tester).changes, isEmpty);
      semantics.dispose();
    },
  );

  testWidgets('devrait occuper sa ligne de 24 seule, et prendre le toucher jusqu’à la cible de la plateforme', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    expect(tester.getSize(find.byType(FlSlider)).height, 24);
    final slop = (FlTokens.defaults.size.hitTargetIos - 24) / 2;
    await tester.tapAt(_at(tester, 0.8, across: -12 - slop + 1));
    await tester.pump();
    expect(_host(tester).value, closeTo(0.8, 0.01));
    await tester.tapAt(_at(tester, 0.2, across: 12 + slop - 1));
    await tester.pump();
    expect(_host(tester).value, closeTo(0.2, 0.01));
    await tester.tapAt(_at(tester, 0.6, across: 10 + slop + 2));
    await tester.pump();
    expect(_host(tester).value, closeTo(0.2, 0.01));
  });

  testWidgets('devrait poser le pouce au point touché, sans transition', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tapAt(_at(tester, 0.8));
    await tester.pump();
    expect(_host(tester).changes.single, closeTo(0.8, 0.01));
    expect(_host(tester).ends.single, closeTo(0.8, 0.01));
    expect(_thumbs(tester).single.center.dx, closeTo(_at(tester, _host(tester).value).dx, 0.01));
  });

  testWidgets('devrait garder l’écart du doigt au pouce saisi, sans saut, et suivre le glisser en RTL', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    final thumb = _thumbs(tester).single;
    final gesture = await tester.startGesture(thumb.center + const Offset(-8, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(_host(tester).changes.first, closeTo(0.4 + 30 / (300 - _thumbLength), 0.01));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(_host(tester).value, greaterThan(0.5));
    expect(_thumbs(tester).single.center.dx, closeTo(thumb.center.dx - 60, 1));
    await gesture.up();
    await tester.pump();
    expect(_host(tester).ends.single, _host(tester).value);
  });

  testWidgets('devrait rétrécir le pouce à 0,9 pendant le glisser, puis le rendre', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final gesture = await tester.startGesture(_thumbs(tester).single.center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, closeTo(0.9, 0.001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, closeTo(1, 0.001));
  });

  testWidgets('devrait rendre le pouce sans ressort quand le mouvement est réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host()));
    final gesture = await tester.startGesture(_thumbs(tester).single.center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, 0.9);
    await gesture.up();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('devrait tomber sur un cran quand divisions est donné, au toucher comme au clavier', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(initial: 0.5, divisions: 4)));
    await tester.tapAt(_at(tester, 0.3));
    await tester.pump();
    expect(_host(tester).value, 0.25);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_host(tester).value, 0.5);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(_host(tester).value, 0.75);
  });

  testWidgets(
    "devrait montrer l'anneau au focus et répondre aux flèches, à Page, Début et Fin quand il a le focus clavier",
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host()));
      expect(tester.widget<FlFocusRing>(find.byType(FlFocusRing)).visible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<FlFocusRing>(find.byType(FlFocusRing)).visible, isTrue);

      final expected = <(LogicalKeyboardKey, double)>[
        (LogicalKeyboardKey.arrowRight, 0.41),
        (LogicalKeyboardKey.arrowUp, 0.42),
        (LogicalKeyboardKey.arrowLeft, 0.41),
        (LogicalKeyboardKey.arrowDown, 0.40),
        (LogicalKeyboardKey.pageUp, 0.50),
        (LogicalKeyboardKey.pageDown, 0.40),
        (LogicalKeyboardKey.end, 1),
        (LogicalKeyboardKey.home, 0),
      ];
      for (final (key, value) in expected) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(_host(tester).value, closeTo(value, 1e-9), reason: key.keyLabel);
      }
      expect(_host(tester).ends, hasLength(expected.length));
    },
  );

  testWidgets(
    'devrait avancer de step aux flèches et aux gestes du lecteur d’écran, et rester continu au toucher, quand step est donné',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var value = 65.0;
      final ends = <double>[];
      await tester.pumpWidget(
        toggleApp(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 300,
              child: FlSlider(
                value: value,
                label: 'Position',
                max: 211,
                step: 10,
                valueLabel: (v) => '${v.round()} s',
                onChangeEnd: ends.add,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Position')),
        matchesSemantics(
          label: 'Position',
          isSlider: true,
          value: '65 s',
          increasedValue: '75 s',
          decreasedValue: '55 s',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      tester.semantics.performAction(find.semantics.byLabel('Position'), SemanticsAction.decrease);
      await tester.pump();
      expect(value, closeTo(55, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(65, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(value, closeTo(65 + 21.1, 1e-9));
      await tester.tapAt(_at(tester, 0.5));
      await tester.pump();
      expect(value, closeTo(105.5, 1e-9));
      expect(ends, hasLength(4));
      semantics.dispose();
    },
  );

  testWidgets('devrait augmenter avec la flèche gauche quand le sens est RTL', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_host(tester).value, closeTo(0.41, 1e-9));
  });

  testWidgets('devrait monter vers le haut quand il est vertical', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(axis: Axis.vertical)));
    expect(tester.getSize(find.byType(FlSlider)), const Size(24, 300));
    final thumb = _thumbs(tester).single;
    expect(thumb.size, const Size(20, 28));
    expect(thumb.bottom, closeTo(300 - 0.4 * (300 - _thumbLength) + tester.getRect(find.byType(FlSlider)).top, 0.01));
    final gesture = await tester.startGesture(thumb.center);
    await gesture.moveBy(const Offset(0, -40));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(_host(tester).value, closeTo(0.4 + 80 / (300 - _thumbLength), 0.01));
    await gesture.up();
  });

  testWidgets('devrait afficher le libellé et la valeur au-dessus de la piste quand showLabel est vrai', (
    tester,
  ) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 300,
          child: FlRangeSlider(
            values: (start: 20, end: 70),
            min: 0,
            max: 100,
            label: 'Prix',
            startLabel: 'Prix minimum',
            endLabel: 'Prix maximum',
            showLabel: true,
            valueLabel: (value) => '${value.round()} €',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Prix'), findsOneWidget);
    expect(find.text('20 € – 70 €'), findsOneWidget);
    // 4 sous le libellé (`gap-1` de HeroUI v3), la ligne de 24 où le pouce de
    // 20 est centré.
    expect(tester.getRect(find.text('Prix')).bottom + 4 + 2, closeTo(_thumbs(tester).first.top, 0.01));
  });

  testWidgets('devrait annoncer deux curseurs et déplacer le pouce le plus proche du toucher', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _RangeHost()));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Prix minimum')),
      matchesSemantics(
        label: 'Prix minimum',
        isSlider: true,
        value: '20%',
        increasedValue: '21%',
        decreasedValue: '19%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Prix maximum')),
      matchesSemantics(
        label: 'Prix maximum',
        value: '70%',
        isSlider: true,
        increasedValue: '71%',
        decreasedValue: '69%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tapAt(_at(tester, 0.6));
    await tester.pump();
    expect(_range(tester).values.start, 0.2);
    expect(_range(tester).values.end, closeTo(0.6, 0.01));
    await tester.tapAt(_at(tester, 0.3));
    await tester.pump();
    expect(_range(tester).values.start, closeTo(0.3, 0.01));
    semantics.dispose();
  });

  testWidgets('devrait arrêter un pouce sur l’autre, au glisser comme au clavier', (tester) async {
    await tester.pumpWidget(toggleApp(const _RangeHost()));
    final gesture = await tester.startGesture(_thumbs(tester).first.center);
    await gesture.moveBy(const Offset(150, 0));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    expect(_range(tester).values, (start: 0.7, end: 0.7));
    await gesture.up();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(_range(tester).values, (start: 0.7, end: 0.7));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(_range(tester).values, (start: 0.7, end: 1.0));
  });

  testWidgets('devrait remplir la piste control de selected du centre d’un pouce à l’autre, sous des pouces selected', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _RangeHost()));
    final colors = FlTokens.defaults.light;
    Finder painted(Color color) => find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration as ShapeDecoration).color == color,
    );
    final thumbs = _thumbs(tester);
    final fill = tester.getRect(painted(colors.selected).first);
    expect(fill.left, thumbs.first.center.dx);
    expect(fill.right, thumbs.last.center.dx);
    // Le remplissage et les deux pouces en `selected`, chacun portant un
    // bouton `onSelected` soulevé par l'ombre `field`, sur la piste `control`.
    expect(painted(colors.selected), findsNWidgets(3));
    expect(painted(colors.onSelected), findsNWidgets(2));
    expect(painted(colors.control), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is FlShadow && widget.layers == FlTokens.defaults.shadow.light.field),
      findsNWidgets(2),
    );
  });

  testWidgets('devrait marquer d’un point onSelected chaque cran intérieur que couvre le remplissage', (tester) async {
    await tester.pumpWidget(
      toggleApp(
        SizedBox(
          width: 300,
          child: FlSlider(value: 0.75, divisions: 4, label: 'Luminosité', onChanged: (_) {}),
        ),
      ),
    );
    final dot = FlTokens.defaults.light.onSelected;
    final dots = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration as ShapeDecoration).color?.toARGB32() == dot.withValues(alpha: dot.a * 0.7).toARGB32(),
    );
    expect(dots, findsNWidgets(3), reason: '25, 50 et 75 % ; le pouce couvre le dernier');
  });

  testWidgets("devrait dire de l'envelopper dans un Expanded quand sa largeur n'est pas bornée", (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      toggleApp(
        Row(
          children: [FlSlider(value: 0.5, label: 'Volume', onChanged: (_) {})],
        ),
      ),
    );
    FlutterError.onError = previous;
    expect(errors.first.exception, isAssertionError);
    expect('${errors.first.exception}', contains('Expanded'));
  });

  testWidgets('devrait rendre le pouce quand un glisser est interrompu par la désactivation', (tester) async {
    Widget slider({required bool enabled}) => toggleApp(
      SizedBox(
        width: 300,
        child: FlSlider(value: 0.4, label: 'Volume', onChanged: enabled ? (_) {} : null),
      ),
    );
    await tester.pumpWidget(slider(enabled: true));
    final gesture = await tester.startGesture(_thumbs(tester).single.center);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(slider(enabled: false));
    await tester.pumpAndSettle();
    expect(tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value, closeTo(1, 0.001));
    await gesture.up();
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'devrait poser les repères sous la piste, centrés sur le pouce et tenus dans sa longueur, en ${direction.name}',
      (tester) async {
        await tester.pumpWidget(
          toggleApp(
            direction: direction,
            SizedBox(
              width: 300,
              child: FlSlider(
                value: 50,
                max: 100,
                label: 'Volume',
                marks: const [FlSliderMark(0, 'Muet'), FlSliderMark(50), FlSliderMark(100, 'Max')],
                onChanged: (_) {},
              ),
            ),
          ),
        );
        final slider = tester.getRect(find.byType(FlSlider));
        final thumb = _thumbs(tester).single;
        final middle = tester.getRect(find.text('50%').last);
        expect(middle.top, greaterThan(thumb.bottom), reason: 'sous la piste');
        expect(middle.center.dx, closeTo(thumb.center.dx, 0.5), reason: 'centré sur le pouce à 50');
        final (start, end) = direction == TextDirection.ltr ? ('Muet', 'Max') : ('Max', 'Muet');
        expect(tester.getRect(find.text(start).last).left, closeTo(slider.left, 0.01), reason: 'tenu dans la piste');
        expect(tester.getRect(find.text(end).last).right, closeTo(slider.right, 0.01));
        expect(
          tester.widget<Text>(find.text('Muet').last).style?.color,
          FlScope.of(tester.element(find.text('Muet').last)).colors.onSurface,
          reason: 'dans le remplissage',
        );
      },
    );
  }
}

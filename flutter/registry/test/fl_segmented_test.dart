import 'package:fliin_ui/components/segmented/fl_segmented.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

enum _Period { day, week, month }

const _labels = {_Period.day: 'Jour', _Period.week: 'Semaine', _Period.month: 'Mois'};

final _light = FlTokens.defaults.light;

class _Host extends StatefulWidget {
  const _Host({this.width = 360, this.labels = _labels, this.disabled = const {}, this.enabled = true});

  final double width;
  final Map<_Period, String> labels;
  final Set<_Period> disabled;
  final bool enabled;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  _Period value = _Period.day;
  final List<_Period> changes = [];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: FlSegmented<_Period>(
      semanticLabel: 'Période',
      value: value,
      enabled: widget.enabled,
      onChanged: (next) => setState(() {
        changes.add(next);
        value = next;
      }),
      segments: [
        for (final MapEntry(key: period, value: label) in widget.labels.entries)
          FlSegment(value: period, label: label, disabled: widget.disabled.contains(period)),
      ],
    ),
  );
}

_HostState _host(WidgetTester tester) => tester.state<_HostState>(find.byType(_Host));

Finder get _group => find
    .descendant(
      of: find.byType(FlSegmented<_Period>),
      matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter != null),
    )
    .first;

/// Le segment [label] dans le repère du groupe.
Rect _segment(WidgetTester tester, String label) => tester
    .getRect(find.ancestor(of: find.text(label), matching: find.byType(FlHitTarget)).first)
    .shift(-tester.getTopLeft(_group));

/// Le pouce `segment` du segment choisi, tel qu'il est peint, sans ses
/// ombres.
Rect _pill(WidgetTester tester) {
  final found = <Rect>[];
  expect(
    _group,
    paints..everything((method, arguments) {
      final paint = arguments.isEmpty ? null : arguments.last;
      if (method == #drawRRect &&
          paint is Paint &&
          paint.maskFilter == null &&
          paint.color.toARGB32() == _light.segment.toARGB32()) {
        found.add((arguments.first as RRect).outerRect);
      }
      return true;
    }),
  );
  return found.single;
}

void main() {
  testWidgets(
    'devrait peindre le choix en couleur primaire sans ombre, texte onSelected, sur la piste demandée, en variante inverse',
    (tester) async {
      await tester.pumpWidget(
        toggleApp(
          SizedBox(
            width: 360,
            child: FlSegmented<_Period>(
              value: _Period.week,
              onChanged: (_) {},
              variant: FlSegmentedVariant.inverse,
              trackColor: _light.surfaceRaised,
              segments: [for (final MapEntry(key: p, value: l) in _labels.entries) FlSegment(value: p, label: l)],
            ),
          ),
        ),
      );
      final track = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FlSegmented<_Period>), matching: find.byType(DecoratedBox)).first,
      );
      expect((track.decoration as BoxDecoration).color, _light.surfaceRaised);
      final fills = <int>[];
      var blurred = 0;
      expect(
        _group,
        paints..everything((method, arguments) {
          final paint = arguments.isEmpty ? null : arguments.last;
          if (method == #drawRRect && paint is Paint) {
            if (paint.maskFilter != null) blurred++;
            fills.add(paint.color.toARGB32());
          }
          return true;
        }),
      );
      expect(fills, [_light.selected.toARGB32()]);
      expect(blurred, 0, reason: 'pas d\'ombre sous un pouce en couleur primaire');
      Color ink(String label) => tester.widget<Text>(find.text(label)).style!.color!;
      expect(ink('Semaine'), _light.onSelected);
      expect(ink('Jour'), _light.onSurfaceMuted);
    },
  );

  testWidgets('devrait se lire comme un groupe de boutons radio nommé, le segment choisi coché', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host()));
    expect(
      tester.getSemantics(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.role == SemanticsRole.radioGroup),
      ),
      matchesSemantics(
        label: 'Période',
        role: SemanticsRole.radioGroup,
        children: [
          for (final (i, label) in _labels.values.indexed)
            matchesSemantics(
              label: label,
              hasCheckedState: true,
              isChecked: i == 0,
              isInMutuallyExclusiveGroup: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
              hasFocusAction: true,
              isFocusable: true,
            ),
        ],
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait partager la largeur en parts égales, aux bords posés sur les pixels', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    // 451 dans la capsule, retirée de 4 de chaque côté.
    await tester.pumpWidget(toggleApp(const _Host(width: 459)));
    final rects = [for (final label in _labels.values) _segment(tester, label)];
    expect(rects.first.left, 0);
    expect(rects.last.right, 451);
    for (final rect in rects) {
      expect(rect.width, closeTo(451 / 3, 1 / 3));
      expect((rect.left * 3 - (rect.left * 3).roundToDouble()).abs(), lessThan(1e-6));
      expect(rect.height, FlTokens.defaults.space.xs * 10 - 8);
    }
  });

  testWidgets('devrait donner à un segment la largeur de son plus long mot, et partager le reste', (tester) async {
    // Police de test : un glyphe par em, 14 de haut. « Semaine » fait 98,
    // plus 2 × 12 de marge : 122, plus que le tiers des 330 de la capsule.
    await tester.pumpWidget(toggleApp(const _Host(width: 338)));
    expect(_segment(tester, 'Semaine').width, 122);
    expect(_segment(tester, 'Jour').width, 104);
    expect(_segment(tester, 'Mois').width, 104);
    expect(tester.getSize(find.text('Semaine')).height, 20);
  });

  testWidgets('devrait passer le libellé à la ligne entre deux mots, sans couper un mot, à 2,0', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: toggleApp(
          const _Host(width: 396, labels: {_Period.day: 'Ce jour', _Period.week: 'Un mois', _Period.month: 'An'}),
        ),
      ),
    );
    // Police de test à 2,0 : 28 par glyphe. « jour » et « mois » font 112,
    // plus 2 × 12 de marge : 136 chacun, et « An » garde les 116 qui restent.
    final text = tester.renderObject<RenderParagraph>(find.text('Ce jour'));
    expect(text.size.height, greaterThan(28 * 1.5), reason: 'deux lignes');
    final word = text.getBoxesForSelection(const TextSelection(baseOffset: 3, extentOffset: 7));
    expect(word.map((box) => box.top).toSet(), hasLength(1), reason: '« jour » sur une seule ligne');
    expect(_segment(tester, 'An').width, 116);
    final heights = {
      for (final label in ['Ce jour', 'Un mois', 'An']) _segment(tester, label).height,
    };
    expect(heights, hasLength(1), reason: 'tous les segments ont la hauteur du plus haut');
    expect(tester.takeException(), isNull);
  });

  testWidgets('devrait resserrer les marges pour que le plus long mot de chaque segment tienne, à 2,0', (tester) async {
    const labels = ['Jour', 'Sem.', 'Mois', 'Trim.', 'An'];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: toggleApp(
          SizedBox(
            width: 606,
            child: FlSegmented<String>(
              value: 'Jour',
              onChanged: (_) {},
              segments: [for (final label in labels) FlSegment(value: label, label: label)],
            ),
          ),
        ),
      ),
    );
    // 28 par glyphe : 532 de mots, il reste 66 pour dix marges, 6 chacune
    // au lieu de 12.
    for (final label in labels) {
      final text = tester.getRect(find.text(label));
      final segment = tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(FlHitTarget)).first);
      expect(text.height, 40, reason: '« $label » sur une ligne');
      expect(text.left - segment.left, greaterThanOrEqualTo(6), reason: label);
    }
  });

  testWidgets('devrait choisir le segment touché et faire glisser le fond par le ressort', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    final start = _pill(tester);
    expect(start, _segment(tester, 'Jour'));
    await tester.tap(find.text('Mois'));
    await tester.pump();
    expect(_host(tester).changes, [_Period.month]);
    await tester.pump(const Duration(milliseconds: 16));
    final moving = _pill(tester);
    expect(moving.left, greaterThan(start.left));
    await tester.pumpAndSettle();
    expect(moving.left, lessThan(_pill(tester).left));
    expect(_pill(tester), _segment(tester, 'Mois'));
  });

  testWidgets('devrait poser le fond sur le nouveau segment, sans glisser, sous mouvement réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.tap(find.text('Mois'));
    await tester.pump();
    expect(_pill(tester), _segment(tester, 'Mois'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_pill(tester), _segment(tester, 'Mois'));
  });

  testWidgets('devrait offrir la cible tactile de la plateforme à chaque segment', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(toggleApp(const _Host(), platform: TargetPlatform.iOS));
    final target = find.ancestor(of: find.text('Semaine'), matching: find.byType(FlHitTarget)).first;
    expect(tester.getSemantics(target).rect.height, FlTokens.defaults.size.hitTargetIos);
    semantics.dispose();
  });

  testWidgets('devrait être un seul arrêt de Tab, et choisir le voisin aux flèches en revenant au début', (
    tester,
  ) async {
    await tester.pumpWidget(toggleApp(const _Host()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Jour'))).hasPrimaryFocus, isTrue);
    for (final (key, expected) in [
      (LogicalKeyboardKey.arrowRight, _Period.week),
      (LogicalKeyboardKey.arrowDown, _Period.month),
      (LogicalKeyboardKey.arrowRight, _Period.day),
      (LogicalKeyboardKey.arrowLeft, _Period.month),
      (LogicalKeyboardKey.arrowUp, _Period.week),
      (LogicalKeyboardKey.home, _Period.day),
      (LogicalKeyboardKey.end, _Period.month),
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(_host(tester).value, expected, reason: '$key');
      expect(Focus.of(tester.element(find.text(_labels[expected]!))).hasPrimaryFocus, isTrue);
    }
    final scope = FocusScope.of(tester.element(find.text('Mois')));
    expect(scope.traversalDescendants.map((node) => node.debugLabel), ['FlSegment 2']);
  });

  testWidgets('devrait retourner les flèches gauche et droite en RTL', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(), direction: TextDirection.rtl));
    expect(_segment(tester, 'Jour').right, 352, reason: 'au début en RTL, dans la capsule');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_host(tester).value, _Period.week);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_host(tester).value, _Period.day);
  });

  testWidgets('devrait sauter un segment désactivé, au toucher comme aux flèches', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(disabled: {_Period.week})));
    await tester.tap(find.text('Semaine'));
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_host(tester).value, _Period.month);
  });

  testWidgets('devrait ignorer le toucher et le focus quand le groupe est désactivé', (tester) async {
    await tester.pumpWidget(toggleApp(const _Host(enabled: false)));
    await tester.tap(find.text('Mois'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_host(tester).changes, isEmpty);
    expect(Focus.of(tester.element(find.text('Jour'))).hasFocus, isFalse);
  });

  testWidgets(
    'devrait peindre le segment pressé en capsule controlPressed, et le pouce choisi pressé du voile pressHighlight',
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host()));
      final week = await tester.startGesture(tester.getCenter(find.text('Semaine')));
      await tester.pump();
      expect(
        _group,
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            _segment(tester, 'Semaine'),
            Radius.circular(FlTokens.defaults.shape.radiusButton - 4),
          ),
          color: _light.controlPressed,
        ),
      );
      expect(_pill(tester), _segment(tester, 'Jour'));
      await week.up();
      await tester.pumpAndSettle();
      final chosen = await tester.startGesture(tester.getCenter(find.text('Semaine')));
      await tester.pump();
      final pressed = Color.alphaBlend(
        _light.pressHighlight.withValues(alpha: FlTokens.defaults.size.pressHighlightOpacity),
        _light.segment,
      );
      expect(
        _group,
        paints..something(
          (method, arguments) =>
              method == #drawRRect && (arguments.last as Paint).color.toARGB32() == pressed.toARGB32(),
        ),
      );
      await chosen.up();
    },
  );

  testWidgets(
    'devrait poser les segments dans une capsule control, le texte choisi en onSegment et les autres en onSurfaceMuted',
    (tester) async {
      await tester.pumpWidget(toggleApp(const _Host(width: 336)));
      final track = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(FlSegmented<_Period>), matching: find.byType(DecoratedBox)).first,
      );
      expect((track.decoration as BoxDecoration).color, _light.control);
      expect(tester.getSize(find.byType(FlSegmented<_Period>)).height, FlTokens.defaults.space.xs * 10);
      expect(tester.getTopLeft(_group) - tester.getTopLeft(find.byType(FlSegmented<_Period>)), const Offset(4, 4));
      expect(tester.widget<Text>(find.text('Jour')).style?.color, _light.onSegment);
      expect(tester.widget<Text>(find.text('Semaine')).style?.color, _light.onSurfaceMuted);
    },
  );
}

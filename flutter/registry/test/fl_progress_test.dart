import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:fliin_ui/components/progress/fl_progress.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/toggles.dart';

final _light = FlTokens.defaults.light;

Finder get _paint => find.descendant(of: find.byType(FlProgress), matching: find.byType(CustomPaint)).last;

Widget _bar(Widget progress, {TextDirection direction = TextDirection.ltr}) =>
    toggleApp(SizedBox(width: 200, child: progress), direction: direction);

/// Le remplissage que dessine la barre dans [color] (`selected` par défaut).
Rect _fill(WidgetTester tester, [Color? color]) {
  final rects = <Rect>[];
  expect(
    _paint,
    paints..everything((method, arguments) {
      if (method == #drawRRect && (arguments[1] as Paint).color.toARGB32() == (color ?? _light.selected).toARGB32()) {
        rects.add((arguments[0] as RRect).outerRect);
      }
      return true;
    }),
  );
  return rects.single;
}

/// L'angle de départ et le balayage de l'arc plein de l'anneau.
(double, double) _arc(WidgetTester tester) {
  (double, double)? arc;
  expect(
    _paint,
    paints..everything((method, arguments) {
      if (method == #drawArc && (arguments[4] as Paint).color.toARGB32() == _light.selected.toARGB32()) {
        arc = (arguments[1] as double, arguments[2] as double);
      }
      return true;
    }),
  );
  return arc!;
}

void main() {
  testWidgets("devrait s'annoncer comme une barre de progression à 40 % sur 0-100 quand value vaut 0,4", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.4, label: 'Téléversement')));
    expect(
      tester.getSemantics(find.byType(FlProgress)),
      matchesSemantics(
        label: 'Téléversement',
        value: '40%',
        minValue: '0',
        maxValue: '100',
        role: SemanticsRole.progressBar,
      ),
    );
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer comme un indicateur de chargement sans valeur quand value est nul", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_bar(const FlProgress.linear(label: 'Chargement')));
    expect(
      tester.getSemantics(find.byType(FlProgress)),
      matchesSemantics(label: 'Chargement', role: SemanticsRole.loadingSpinner),
    );
    semantics.dispose();
  });

  testWidgets('devrait prendre la hauteur de la barre et le diamètre de l’anneau de sa taille', (tester) async {
    for (final (size, bar, ring) in [
      (FlProgressSize.sm, 4.0, 24.0),
      (FlProgressSize.md, 8.0, 32.0),
      (FlProgressSize.lg, 12.0, 48.0),
    ]) {
      await tester.pumpWidget(_bar(FlProgress.linear(value: 0.5, label: 'Copie', size: size)));
      expect(tester.getSize(_paint).height, bar, reason: '$size');
      await tester.pumpWidget(toggleApp(FlProgress.circular(value: 0.5, label: 'Copie', size: size)));
      expect(tester.getSize(_paint), Size.square(ring), reason: '$size');
    }
  });

  testWidgets('devrait remplir dans la couleur choisie, selected pour accent, sur une piste surfaceSecondary', (
    tester,
  ) async {
    for (final (color, expected) in [
      (FlProgressColor.accent, _light.selected),
      (FlProgressColor.neutral, _light.onControl),
      (FlProgressColor.success, _light.success),
      (FlProgressColor.warning, _light.warning),
      (FlProgressColor.danger, _light.dangerFill),
    ]) {
      await tester.pumpWidget(_bar(FlProgress.linear(value: 0.5, label: 'Copie', color: color)));
      expect(_fill(tester, expected).width, 100, reason: '$color');
      expect(_paint, paints..rrect(color: _light.surfaceSecondary));
    }
  });

  testWidgets('devrait remplir la barre depuis le début de la ligne, à droite quand le sens est RTL', (tester) async {
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.5, label: 'Copie')));
    expect(_fill(tester), const Rect.fromLTRB(0, 0, 100, 8));
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.5, label: 'Copie'), direction: TextDirection.rtl));
    expect(_fill(tester), const Rect.fromLTRB(100, 0, 200, 8));
  });

  testWidgets('devrait afficher le libellé et la valeur au-dessus de la barre quand showLabel est vrai', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.6, label: 'Chargement', showLabel: true)));
    expect(find.text('Chargement'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(tester.getRect(find.text('Chargement')).bottom + 6, tester.getRect(_paint).top);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Chargement')),
      matchesSemantics(
        label: 'Chargement',
        value: '60%',
        minValue: '0',
        maxValue: '100',
        role: SemanticsRole.progressBar,
      ),
    );
    expect(find.bySemanticsLabel('Chargement'), findsOneWidget);
    await tester.pumpWidget(_bar(const FlProgress.linear(label: 'Chargement', showLabel: true)));
    expect(find.textContaining('%'), findsNothing);
    semantics.dispose();
  });

  testWidgets('devrait écrire le nom et la valeur atténuée après l’anneau, centrés sur lui, quand showLabel est vrai', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      toggleApp(const Center(child: FlProgress.circular(value: 0.75, label: 'Profil', showLabel: true))),
    );
    final ring = tester.getRect(_paint);
    final text = tester.getRect(find.textContaining('Profil'));
    expect(find.text('Profil \u206675%\u2069', findRichText: true), findsOneWidget);
    expect(text.left - ring.right, 8);
    expect(text.center.dy, closeTo(ring.center.dy, 0.5));
    expect(find.bySemanticsLabel('Profil'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'devrait lire une valeur écrite qui n’est pas un nombre après le libellé, la valeur restant le pourcentage',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _bar(
          FlProgress.linear(
            value: 0.75,
            label: 'Collecte',
            showLabel: true,
            valueLabel: (share) => '\$${(share * 1000).round()} sur \$1000',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('\$750 sur \$1000'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Collecte'))),
        matchesSemantics(
          label: 'Collecte\n\$750 sur \$1000',
          value: '75%',
          minValue: '0',
          maxValue: '100',
          role: SemanticsRole.progressBar,
        ),
      );
      await tester.pumpWidget(
        _bar(FlProgress.linear(value: 0.4, label: 'Envoi', valueLabel: (share) => '${(share * 100).round()} %')),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Envoi')),
        matchesSemantics(
          label: 'Envoi',
          value: '40 %',
          minValue: '0',
          maxValue: '100',
          role: SemanticsRole.progressBar,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets('devrait faire avancer le remplissage en medium2, sans saut, quand value change', (tester) async {
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.2, label: 'Copie')));
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.8, label: 'Copie')));
    await tester.pump(const Duration(milliseconds: 100));
    final during = _fill(tester).right;
    expect(during, greaterThan(40));
    expect(during, lessThan(160));
    await tester.pump(FlTokens.defaults.motion.medium2);
    expect(_fill(tester).right, 160);
  });

  testWidgets('devrait sauter à la nouvelle valeur quand le mouvement est réduit', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.2, label: 'Copie')));
    await tester.pumpWidget(_bar(const FlProgress.linear(value: 0.8, label: 'Copie')));
    expect(_fill(tester).right, 160);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('devrait faire courir deux cinquièmes de piste sans fin quand la progression est indéterminée', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(const FlProgress.linear(label: 'Chargement')));
    await tester.pump(const Duration(milliseconds: 500));
    final first = _fill(tester);
    expect(first.width, closeTo(80, 0.01));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_fill(tester), isNot(first));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets("devrait poser l'indéterminé immobile au milieu, sans frame planifié, quand le mouvement est réduit", (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_bar(const FlProgress.linear(label: 'Chargement')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_fill(tester), const Rect.fromLTRB(60, 0, 140, 8));
  });

  testWidgets('devrait remplir l’anneau dans le sens horaire depuis midi', (tester) async {
    await tester.pumpWidget(toggleApp(const FlProgress.circular(value: 0.75, label: 'Synchronisation')));
    final (start, sweep) = _arc(tester);
    expect(start, closeTo(-math.pi / 2, 1e-9));
    expect(sweep, closeTo(1.5 * math.pi, 1e-9));
  });
}

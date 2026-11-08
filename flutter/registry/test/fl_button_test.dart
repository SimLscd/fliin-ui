import 'dart:ui' show Tristate;

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'torture/torture.g.dart';
import 'torture/themes.dart';

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.android, FlDensity? density, FlTokens? tokens}) =>
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => FlScope(
        tokens: tokens,
        brightness: Brightness.light,
        platform: platform,
        density: density,
        child: FocusScope(autofocus: true, child: Center(child: child)),
      ),
    );

void main() {
  setUpAll(loadTortureFonts);

  testWidgets('devrait porter son état choisi sur le nœud de sa cible, nom inchangé, quand il bascule', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final selected in [null, false, true]) {
      await tester.pumpWidget(
        _app(
          FlButton.icon(
            label: 'Favori',
            icon: const SizedBox.square(dimension: 20),
            size: FlButtonSize.sm,
            selected: selected,
            onPressed: () {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(FlButton));
      expect(node.label, 'Favori', reason: '$selected');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, switch (selected) {
        null => Tristate.none,
        true => Tristate.isTrue,
        false => Tristate.isFalse,
      });
      expect(node.rect.size, const Size.square(48), reason: 'le nœud est celui de la cible, pas un second nœud');
      expect(find.semantics.byLabel('Favori'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
    semantics.dispose();
  });

  testWidgets("devrait s'annoncer comme un bouton activé avec son libellé quand onPressed est fourni", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(FlButton(label: 'Enregistrer', onPressed: () {})));
    expect(
      tester.getSemantics(find.byType(FlButton)),
      matchesSemantics(
        label: 'Enregistrer',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait appeler onPressed une fois quand on touche le bouton', (tester) async {
    var presses = 0;
    await tester.pumpWidget(_app(FlButton(label: 'Enregistrer', onPressed: () => presses++)));
    await tester.tap(find.byType(FlButton));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });

  testWidgets('devrait ignorer le toucher et se déclarer désactivé quand loading est vrai ou onPressed nul', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    for (final button in [
      FlButton(label: 'Envoi', loading: true, onPressed: () => presses++),
      const FlButton(label: 'Envoi', onPressed: null),
    ]) {
      await tester.pumpWidget(_app(button));
      await tester.tap(find.byType(FlButton), warnIfMissed: false);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(FlButton)),
        matchesSemantics(label: 'Envoi', isButton: true, hasEnabledState: true),
      );
    }
    expect(presses, 0);
    semantics.dispose();
  });

  testWidgets("devrait prendre le focus au clavier, montrer l'anneau et s'activer avec Entrée", (tester) async {
    var presses = 0;
    // En pilule, le fond est lui-même un rrect, peint avant l'anneau.
    final ring = paints
      ..rrect(color: FlTokens.defaults.light.accent)
      ..rrect(color: FlTokens.defaults.light.focusRing, style: PaintingStyle.stroke);
    await tester.pumpWidget(_app(FlButton(label: 'Enregistrer', onPressed: () => presses++)));
    expect(find.byType(FlButton), isNot(ring));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(FlButton), ring);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 1);
  });

  testWidgets(
    'devrait dessiner le bouton à la hauteur de la densité et garder la cible de la plateforme quand la densité change',
    (tester) async {
      for (final (platform, guideline, target) in [
        (TargetPlatform.android, androidTapTargetGuideline, 48.0),
        (TargetPlatform.iOS, iOSTapTargetGuideline, 44.0),
      ]) {
        for (final (density, visual) in [
          (FlDensity.compact, 44.0),
          (FlDensity.comfortable, 48.0),
          (FlDensity.spacious, 56.0),
        ]) {
          final reason = '${platform.name} ${density.name}';
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            _app(
              FlButton(label: 'OK', onPressed: () {}),
              platform: platform,
              density: density,
            ),
          );
          final fill = find.descendant(of: find.byType(FlButton), matching: find.byType(DecoratedBox)).first;
          expect(tester.getSize(fill).height, visual, reason: reason);
          final rect = tester.getSemantics(find.byType(FlButton)).rect;
          expect(rect.height, greaterThanOrEqualTo(target), reason: reason);
          expect(rect.width, greaterThanOrEqualTo(target), reason: reason);
          await expectLater(tester, meetsGuideline(guideline), reason: reason);
          semantics.dispose();
        }
      }
    },
  );

  testWidgets('devrait occuper 44 de haut et garder une cible de 24 au moins quand le bouton est compact sur bureau', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          FlButton(label: 'OK', onPressed: () {}),
          platform: platform,
        ),
      );
      expect(tester.getSize(find.byType(FlButton)).height, 44, reason: platform.name);
      final rect = tester.getSemantics(find.byType(FlButton)).rect;
      expect(rect.height, greaterThanOrEqualTo(24), reason: platform.name);
      expect(rect.width, greaterThanOrEqualTo(24), reason: platform.name);
      semantics.dispose();
    }
  });

  testWidgets('devrait appeler onPressed quand on touche la marge de la cible hors du visuel compact', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      _app(
        FlButton(label: 'OK', onPressed: () => presses++),
        density: FlDensity.compact,
      ),
    );
    final fill = tester.getRect(find.descendant(of: find.byType(FlButton), matching: find.byType(DecoratedBox)).first);
    // Compact à 44, le visuel laisse 2 de marge sous la cible de 48.
    await tester.tapAt(fill.topCenter - const Offset(0, 1.5));
    await tester.tapAt(fill.bottomCenter + const Offset(0, 1.5));
    expect(presses, 2);
    await tester.tapAt(fill.topCenter - const Offset(0, 20));
    expect(presses, 2);
  });

  testWidgets("devrait faire tourner l'indicateur de chargement quand le mouvement n'est pas réduit", (tester) async {
    await tester.pumpWidget(_app(FlButton(label: 'Envoi', loading: true, onPressed: () {})));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets("devrait figer l'indicateur de chargement quand Android supprime les animations", (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(FlButton(label: 'Envoi', loading: true, onPressed: () {})),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets("devrait figer l'indicateur de chargement quand Reduce Motion iOS s'active pendant qu'il tourne", (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlButton(label: 'Envoi', loading: true, onPressed: () {})));
    expect(tester.hasRunningAnimations, isTrue);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'devrait agrandir la ligne et le bouton au lieu de rogner le texte quand la police dépasse la hauteur de ligne',
    (tester) async {
      final label = tortureA.typography.ios.controlMd;
      final natural = TextPainter(
        text: TextSpan(
          text: 'Appuyer',
          style: TextStyle(fontFamily: tortureA.typography.ios.fontFamily, fontSize: label.size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(natural.height, greaterThan(label.lineHeight));

      await tester.pumpWidget(
        _app(
          FlButton(label: 'Appuyer', onPressed: () {}),
          platform: TargetPlatform.iOS,
          tokens: tortureA,
        ),
      );
      final text = tester.getRect(find.text('Appuyer'));
      final fill = tester.getRect(
        find.descendant(of: find.byType(FlButton), matching: find.byType(DecoratedBox)).first,
      );
      expect(text.height, greaterThanOrEqualTo(natural.height));
      final margin = (tortureA.size.controlComfortable - label.lineHeight) / 2;
      expect(fill.top, lessThanOrEqualTo(text.top - margin));
      expect(fill.bottom, greaterThanOrEqualTo(text.bottom + margin));
      natural.dispose();
    },
  );

  testWidgets('devrait garder la hauteur de ligne des jetons quand la police tient dans la ligne', (tester) async {
    await tester.pumpWidget(
      _app(
        FlButton(label: 'Appuyer', onPressed: () {}),
        platform: TargetPlatform.iOS,
      ),
    );
    expect(tester.getSize(find.text('Appuyer')).height, FlTokens.defaults.typography.ios.controlMd.lineHeight);
  });

  Rect fillOf(WidgetTester tester, Finder button) =>
      tester.getRect(find.descendant(of: button, matching: find.byType(DecoratedBox)).first);

  testWidgets('devrait passer à disabledOpacity sans changer de couleurs quand onPressed est nul', (tester) async {
    await tester.pumpWidget(_app(const FlButton(label: 'Indisponible', onPressed: null)));
    final opacity = tester.widget<Opacity>(find.descendant(of: find.byType(FlButton), matching: find.byType(Opacity)));
    expect(opacity.opacity, FlTokens.defaults.size.disabledOpacity);
    await tester.pumpWidget(_app(FlButton(label: 'Indisponible', loading: true, onPressed: () {})));
    expect(
      tester.widget<Opacity>(find.descendant(of: find.byType(FlButton), matching: find.byType(Opacity))).opacity,
      1,
    );
  });

  testWidgets('devrait compter la bordure dans la largeur du bouton outline, comme Yoga', (tester) async {
    await tester.pumpWidget(
      _app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlButton(key: Key('ghost'), label: 'Modifier', variant: FlButtonVariant.ghost, onPressed: null),
            FlButton(key: Key('outline'), label: 'Modifier', variant: FlButtonVariant.outline, onPressed: null),
          ],
        ),
      ),
    );
    final border = FlTokens.defaults.size.border;
    final ghost = fillOf(tester, find.byKey(const Key('ghost')));
    final outline = fillOf(tester, find.byKey(const Key('outline')));
    expect(outline.width, moreOrLessEquals(ghost.width + 2 * border, epsilon: 0.5));
    expect(outline.height, ghost.height);
  });

  testWidgets(
    'devrait dessiner un carré à la hauteur de sa taille et lire son libellé quand il ne montre qu’une icône',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (size, side) in [(FlButtonSize.sm, 44.0), (FlButtonSize.md, 48.0), (FlButtonSize.lg, 56.0)]) {
        await tester.pumpWidget(
          _app(FlButton.icon(label: 'Aimer', icon: const SizedBox.square(dimension: 18), size: size, onPressed: () {})),
        );
        expect(fillOf(tester, find.byType(FlButton)).size, Size.square(side), reason: size.name);
        expect(
          tester.getSemantics(find.byType(FlButton)),
          matchesSemantics(
            label: 'Aimer',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
      }
      semantics.dispose();
    },
  );

  testWidgets('devrait garder une marge autour du texte agrandi au lieu de le coller aux bords du bouton', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(
          FlButton(label: 'Appuyer', onPressed: () {}),
          platform: TargetPlatform.iOS,
        ),
      ),
    );
    final text = tester.getRect(find.text('Appuyer'));
    final fill = fillOf(tester, find.byType(FlButton));
    final style = FlTokens.defaults.typography.ios.controlMd;
    final margin = (FlTokens.defaults.size.controlComfortable - style.lineHeight) / 2;
    expect(text.top - fill.top, moreOrLessEquals(margin, epsilon: 1));
    expect(fill.bottom - text.bottom, moreOrLessEquals(margin, epsilon: 1));
  });

  testWidgets('devrait appliquer l’approche de SF au libellé sur iOS, aucune sur Android ni avec une police nommée', (
    tester,
  ) async {
    for (final (platform, tokens, tracking) in [
      (TargetPlatform.iOS, null, -0.1504),
      (TargetPlatform.android, null, 0.0),
      (TargetPlatform.iOS, tortureA, 0.0),
    ]) {
      await tester.pumpWidget(
        _app(
          FlButton(label: 'Appuyer', onPressed: () {}),
          platform: platform,
          tokens: tokens,
        ),
      );
      final reason = '${platform.name} ${tokens == null ? 'police système' : 'police nommée'}';
      expect(tester.widget<Text>(find.text('Appuyer')).style!.letterSpacing, tracking, reason: reason);
    }
  });

  testWidgets('devrait faire apparaître le voile d’appui de la variante sous le libellé quand on presse', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FlButton(label: 'Appuyer', onPressed: () {})));
    FadeTransition veil() => tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(ColoredBox), matching: find.byType(FadeTransition)).first,
    );
    expect(veil().opacity.value, 0);
    expect(
      tester.widget<ColoredBox>(find.descendant(of: find.byType(FlButton), matching: find.byType(ColoredBox))).color,
      FlTokens.defaults.light.accentPressed,
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byType(FlButton)));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(FlTokens.defaults.motion.short4);
    expect(veil().opacity.value, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(veil().opacity.value, 0);
  });

  testWidgets('devrait prendre toute la largeur reçue avec fullWidth, et sa largeur naturelle sous une rangée', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: Center(
            child: FlButton(label: 'Continuer', fullWidth: true, onPressed: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlButton)).width, 300);
    final label = tester.getRect(find.text('Continuer'));
    expect(label.center.dx, moreOrLessEquals(tester.getRect(find.byType(FlButton)).center.dx, epsilon: 0.5));
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [FlButton(label: 'Continuer', fullWidth: true, onPressed: () {})],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FlButton)).width, lessThan(300));
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 300,
          child: Center(
            child: FlButton(label: 'Continuer', onPressed: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlButton)).width, lessThan(300), reason: 'sans fullWidth, la largeur du contenu');
  });
}

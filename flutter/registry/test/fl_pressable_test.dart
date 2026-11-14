import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.android}) => WidgetsApp(
  color: const Color(0xFF000000),
  builder: (context, _) => FlScope(
    brightness: Brightness.light,
    platform: platform,
    child: Center(child: child),
  ),
);

FlPressable _pressable({VoidCallback? onPressed, String? label, bool autofocus = false}) => FlPressable(
  onPressed: onPressed,
  label: label,
  autofocus: autofocus,
  borderRadius: BorderRadius.zero,
  builder: (context, states) => const SizedBox(width: 20, height: 20, child: Text('Ok')),
);

void main() {
  testWidgets("devrait s'annoncer comme un bouton activé, focalisable et étiqueté quand onPressed est fourni", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_pressable(onPressed: () {}, label: 'Appuyer')));
    expect(
      tester.getSemantics(find.byType(FlPressable)),
      matchesSemantics(
        label: 'Appuyer',
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

  testWidgets("devrait prendre son libellé dans le texte de son contenu quand label n'est pas donné", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_pressable(onPressed: () {})));
    expect(
      tester.getSemantics(find.byType(FlPressable)),
      matchesSemantics(
        label: 'Ok',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('devrait se déclarer désactivé, sans action ni focus, quand onPressed est nul même avec autofocus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_pressable(label: 'Appuyer', autofocus: true)));
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(FlPressable)),
      matchesSemantics(label: 'Appuyer', isButton: true, hasEnabledState: true),
    );
    semantics.dispose();
  });

  testWidgets(
    "devrait montrer l'anneau dès le premier frame suivant et s'activer avec Espace quand autofocus est vrai",
    (tester) async {
      var presses = 0;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(_app(_pressable(onPressed: () => presses++, autofocus: true)));
      await tester.pump();
      expect(
        find.byType(FlPressable),
        paints..rrect(color: FlTokens.defaults.light.focusRing, style: PaintingStyle.stroke),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(presses, 1);
    },
  );

  testWidgets('ne devrait pas prendre le focus par autofocus quand onPressed est nul', (tester) async {
    await tester.pumpWidget(_app(_pressable(label: 'Désactivé', autofocus: true)));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FlPressable>(), isNull);
    await tester.pumpWidget(_app(_pressable(onPressed: () {}, label: 'Actif', autofocus: true)));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FlPressable>()?.label, 'Actif');
  });

  Future<Rect> pressedRect(WidgetTester tester, {required double width, bool reduce = false}) async {
    if (reduce) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(
      _app(
        FlPressable(
          onPressed: () {},
          borderRadius: BorderRadius.zero,
          builder: (context, states) => SizedBox(key: const Key('visual'), width: width, height: 40),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('visual'))));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(FlTokens.defaults.motion.medium2);
    final rect = tester.getRect(find.byKey(const Key('visual')));
    await gesture.up();
    await tester.pumpAndSettle();
    return rect;
  }

  testWidgets('devrait rétrécir de (1 − pressedScale) × pressScaleReference / largeur quand on presse, comme HeroUI', (
    tester,
  ) async {
    final tokens = FlTokens.defaults;
    for (final width in [100.0, 200.0]) {
      final rect = await pressedRect(tester, width: width);
      final scale = 1 - (1 - tokens.motion.pressedScale) * tokens.size.pressScaleReference / width;
      expect(rect.width, moreOrLessEquals(width * scale, epsilon: 1e-6), reason: '$width');
    }
  });

  testWidgets('devrait poser les bords haut et bas du contrôle pressé sur un pixel entier', (tester) async {
    final rect = await pressedRect(tester, width: 100);
    for (final edge in [rect.top, rect.bottom]) {
      expect(edge * 3, moreOrLessEquals((edge * 3).roundToDouble(), epsilon: 1e-6), reason: '$edge à 3 px par point');
    }
  });

  testWidgets('ne devrait pas rétrécir sous Reduce Motion', (tester) async {
    final rect = await pressedRect(tester, width: 100, reduce: true);
    expect(rect.size, const Size(100, 40));
  });

  testWidgets('devrait laisser FlPressHighlight invisible hors d’un FlPressable', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: FlPressHighlight(color: Color(0xFF00FF00)),
      ),
    );
    expect(find.byType(FlPressHighlight), paintsNothing);
  });

  Future<TestGesture> pressOverlay(WidgetTester tester, FlPressOverlay overlay, {bool reduce = false}) async {
    if (reduce) {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(
      _app(
        FlPressable(
          onPressed: () {},
          borderRadius: BorderRadius.zero,
          scaleOnPress: false,
          overlay: overlay,
          builder: (context, states) => const SizedBox(
            key: Key('visual'),
            width: 200,
            height: 100,
            child: FlPressHighlight(color: Color(0xFF00FF00)),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byKey(const Key('visual')));
    final gesture = await tester.startGesture(origin + const Offset(30, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(FlTokens.defaults.motion.ripple * 2);
    return gesture;
  }

  testWidgets('devrait étendre une onde depuis le point touché quand overlay est ripple', (tester) async {
    final gesture = await pressOverlay(tester, FlPressOverlay.ripple);
    final radius = const Offset(200, 100).distance * 1.25;
    expect(find.byType(FlPressHighlight), paints..circle(x: 30, y: 20, radius: radius, color: const Color(0xFF00FF00)));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(FlPressHighlight), paintsNothing);
  });

  testWidgets('devrait poser un voile uni à la place de l’onde sous Reduce Motion', (tester) async {
    final gesture = await pressOverlay(tester, FlPressOverlay.ripple, reduce: true);
    expect(find.byType(FlPressHighlight), paints..rect(color: const Color(0xFF00FF00)));
    await gesture.up();
  });

  testWidgets('ne devrait peindre aucun voile quand overlay est none', (tester) async {
    final gesture = await pressOverlay(tester, FlPressOverlay.none);
    expect(find.byType(FlPressHighlight), paintsNothing);
    await gesture.up();
  });

  for (final (platform, hovers) in [
    (TargetPlatform.macOS, true),
    (TargetPlatform.iOS, false),
    (TargetPlatform.android, false),
  ]) {
    testWidgets(
      'devrait ${hovers ? 'passer' : 'ne pas passer'} en hovered sous la souris quand la plateforme est ${platform.name}',
      (tester) async {
        final seen = <Set<WidgetState>>[];
        await tester.pumpWidget(
          _app(
            FlPressable(
              onPressed: () {},
              borderRadius: BorderRadius.zero,
              builder: (context, states) {
                seen.add({...states});
                return const SizedBox(width: 20, height: 20);
              },
            ),
            platform: platform,
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: tester.getCenter(find.byType(FlPressable)));
        await tester.pumpAndSettle();
        expect(seen.last.contains(WidgetState.hovered), hovers);
      },
      // Un navigateur sur un Mac, comme sur le site : seule la plateforme du thème change.
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}

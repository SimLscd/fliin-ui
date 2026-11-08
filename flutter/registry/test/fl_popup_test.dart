import 'dart:async';

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: FlScope(brightness: Brightness.light, platform: TargetPlatform.iOS, child: child),
);

void main() {
  Future<AnimationController> pumpContent(
    WidgetTester tester,
    FlPopupEntrance entrance, {
    FlSide side = FlSide.bottom,
    TextDirection direction = TextDirection.ltr,
  }) async {
    final controller = AnimationController(vsync: const TestVSync(), duration: const Duration(milliseconds: 200));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        Center(
          child: FlPopupContent(
            animation: controller,
            entrance: entrance,
            side: side,
            child: const SizedBox(key: Key('content'), width: 100, height: 50),
          ),
        ),
        direction: direction,
      ),
    );
    return controller;
  }

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: find.byKey(const Key('content')), matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testWidgets('devrait poser le dialogue de 1,04 à 1 en l’affichant, et le réduire vers 0,96 en sortant', (
    tester,
  ) async {
    final controller = await pumpContent(tester, FlPopupEntrance.dialog);
    expect(tester.getSize(find.byKey(const Key('content'))), const Size(100, 50));
    expect(tester.getRect(find.byKey(const Key('content'))).width, moreOrLessEquals(104));
    expect(opacity(tester), 0);
    controller.value = 1;
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('content'))).width, moreOrLessEquals(100));
    expect(opacity(tester), 1);
    unawaited(controller.reverse());
    await tester.pump();
    await tester.pump(FlTokens.defaults.motion.short3 ~/ 2);
    final leaving = tester.getRect(find.byKey(const Key('content'))).width;
    expect(leaving, inExclusiveRange(96, 100), reason: 'il se réduit vers 0,96, sans regrossir');
    await tester.pumpAndSettle();
  });

  testWidgets('devrait faire venir un popover posé dessous depuis son ancre, au-dessus de sa place', (tester) async {
    final controller = await pumpContent(tester, FlPopupEntrance.popover);
    final start = tester.getCenter(find.byKey(const Key('content')));
    controller.value = 1;
    await tester.pump();
    final end = tester.getCenter(find.byKey(const Key('content')));
    // It slides from its anchor and grows from 0.92 out of the anchor's edge,
    // which moves its centre by half the height it lacks.
    expect(end.dy - start.dy, moreOrLessEquals(FlTokens.defaults.size.popoverTravel + 50 * (1 - 0.92) / 2));
    expect(end.dx, start.dx);
  });

  testWidgets('devrait sortir le dialogue le long de easeIn, et l’ouvrir le long de easeOut', (tester) async {
    final controller = await pumpContent(tester, FlPopupEntrance.dialog);
    final motion = FlTokens.defaults.motion;
    unawaited(controller.forward());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), moreOrLessEquals(motion.easeOut.transform(0.5)));
    await tester.pumpAndSettle();
    unawaited(controller.reverse());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), moreOrLessEquals(motion.easeIn.transform(0.5)));
    await tester.pumpAndSettle();
  });

  testWidgets('devrait faire venir un popover de son ancre, de chaque côté et en RTL, le long de easeOut', (
    tester,
  ) async {
    final travel = FlTokens.defaults.size.popoverTravel;
    final eased = FlTokens.defaults.motion.easeOut.transform(0.5);
    // The slide, plus the centre's move as it grows from 0.92 out of the
    // anchor's edge: half the extent it lacks along that axis.
    double away(double e, double extent) => travel * (1 - e) + extent * (1 - (0.92 + 0.08 * e)) / 2;
    for (final (side, direction, toward) in [
      (FlSide.top, TextDirection.ltr, const Offset(0, -1)),
      (FlSide.bottom, TextDirection.ltr, const Offset(0, 1)),
      (FlSide.start, TextDirection.ltr, const Offset(-1, 0)),
      (FlSide.end, TextDirection.ltr, const Offset(1, 0)),
      (FlSide.start, TextDirection.rtl, const Offset(1, 0)),
      (FlSide.end, TextDirection.rtl, const Offset(-1, 0)),
    ]) {
      final controller = await pumpContent(tester, FlPopupEntrance.popover, side: side, direction: direction);
      controller.value = 1;
      await tester.pump();
      final rest = tester.getCenter(find.byKey(const Key('content')));
      controller.value = 0;
      await tester.pump();
      final extent = toward.dx == 0 ? 50.0 : 100.0;
      final start = rest - tester.getCenter(find.byKey(const Key('content')));
      expect(start.dx, moreOrLessEquals(toward.dx * away(0, extent)), reason: '$side $direction');
      expect(start.dy, moreOrLessEquals(toward.dy * away(0, extent)), reason: '$side $direction');
      controller.value = 0.5;
      await tester.pump();
      expect(
        (rest - tester.getCenter(find.byKey(const Key('content')))).distance,
        moreOrLessEquals(away(eased, extent)),
        reason: '$side $direction',
      );
    }
  });

  testWidgets('ne devrait ni déplacer ni agrandir le contenu sous Reduce Motion, seulement le fondre', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final controller = await pumpContent(tester, FlPopupEntrance.dialog);
    expect(tester.getRect(find.byKey(const Key('content'))).width, 100);
    controller.value = 0.5;
    await tester.pump();
    expect(opacity(tester), greaterThan(0));
    expect(tester.getRect(find.byKey(const Key('content'))).width, 100);
  });

  testWidgets('devrait garder ses durées d’entrée et de sortie quand le système désactive les animations', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final motion = FlTokens.defaults.motion;
    final controller = flPopupController(vsync: tester, motion: motion);
    unawaited(controller.forward());
    await tester.pump();
    await tester.pump(motion.short4 ~/ 2);
    expect(controller.value, closeTo(0.5, 0.01));
    await tester.pump(motion.short4 ~/ 2);
    expect(controller.value, 1);
    unawaited(controller.reverse());
    await tester.pump();
    await tester.pump(motion.short3 ~/ 2);
    expect(controller.value, closeTo(0.5, 0.01));
    controller.dispose();
  });

  testWidgets('devrait voiler de scrim à scrimOpacity et fermer au toucher nommé', (tester) async {
    final semantics = tester.ensureSemantics();
    var dismissed = 0;
    final controller = AnimationController(vsync: const TestVSync(), value: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(FlPopupOverlay(animation: controller, onDismiss: () => dismissed++, dismissLabel: 'Fermer')),
    );
    final tokens = FlTokens.defaults;
    expect(
      find.byType(FlPopupOverlay),
      paints..rect(color: tokens.light.scrim.withValues(alpha: tokens.light.scrim.a * tokens.size.scrimOpacity)),
    );
    expect(tester.getSemantics(find.byType(FlPopupOverlay)), matchesSemantics(label: 'Fermer', hasTapAction: true));
    await tester.tap(find.byType(FlPopupOverlay));
    expect(dismissed, 1);
    semantics.dispose();
  });

  testWidgets('devrait recevoir le toucher sans rien peindre quand le voile est transparent', (tester) async {
    var dismissed = 0;
    final controller = AnimationController(vsync: const TestVSync(), value: 1);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(FlPopupOverlay(animation: controller, backdrop: FlPopupBackdrop.transparent, onDismiss: () => dismissed++)),
    );
    expect(find.byType(FlPopupOverlay), paintsNothing);
    await tester.tap(find.byType(FlPopupOverlay));
    expect(dismissed, 1);
  });

  test('devrait ouvrir en short4 et fermer en short3', () {
    final motion = FlTokens.defaults.motion;
    final controller = flPopupController(vsync: const TestVSync(), motion: motion);
    addTearDown(controller.dispose);
    expect((controller.duration, controller.reverseDuration), (motion.short4, motion.short3));
  });
}

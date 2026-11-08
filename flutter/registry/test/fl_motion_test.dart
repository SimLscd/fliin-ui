import 'dart:async';
import 'dart:math' as math;

import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double _ratio(SpringDescription spring) => spring.damping / (2 * math.sqrt(spring.mass * spring.stiffness));

Future<FlMotion> _motion(WidgetTester tester, {bool disableAnimations = false}) async {
  late FlMotion motion;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          motion = FlMotion.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return motion;
}

void main() {
  testWidgets("devrait garder le ressort spatial quand le mouvement n'est pas réduit", (tester) async {
    final spec = (await _motion(tester)).spring(FlSpring.spatial);
    expect(spec, isA<FlSpringMotion>());
    final spring = (spec as FlSpringMotion).description;
    expect(spring.stiffness, 700);
    expect(_ratio(spring), closeTo(0.9, 1e-9));
  });

  testWidgets(
    'devrait remplacer chaque ressort spatial par un fondu de 150 ms quand Android désactive les animations',
    (tester) async {
      final motion = await _motion(tester, disableAnimations: true);
      for (final spring in [FlSpring.press, FlSpring.spatial, FlSpring.spatialSlow, FlSpring.release]) {
        final spec = motion.spring(spring);
        expect(spec, isA<FlFadeMotion>(), reason: spring.name);
        expect((spec as FlFadeMotion).duration, const Duration(milliseconds: 150));
      }
    },
  );

  testWidgets('devrait remplacer un ressort spatial par un fondu quand Reduce Motion iOS est actif', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    expect((await _motion(tester)).spring(FlSpring.spatial), isA<FlFadeMotion>());
  });

  test('devrait passer les ressorts d\'effet à ζ = 1 quand le mouvement est réduit', () {
    final defaults = FlTokens.defaults.motion;
    final bouncy = SpringDescription.withDampingRatio(mass: 1, stiffness: 1600, ratio: 0.6);
    final tokens = FlMotionTokens(
      press: defaults.press,
      spatial: defaults.spatial,
      spatialSlow: defaults.spatialSlow,
      release: defaults.release,
      effects: bouncy,
      effectsFast: bouncy,
      gentle: defaults.gentle,
      indicator: defaults.indicator,
      layout: defaults.layout,
      segment: defaults.segment,
      thumb: defaults.thumb,
      expand: defaults.expand,
      stack: defaults.stack,
      toastEnter: defaults.toastEnter,
      sliderThumb: defaults.sliderThumb,
      pop: defaults.pop,
      roll: defaults.roll,
      shake: defaults.shake,
      standard: defaults.standard,
      easeOut: defaults.easeOut,
      easeInOutQuad: defaults.easeInOutQuad,
      easeIn: defaults.easeIn,
      easeInOut: defaults.easeInOut,
      ease: defaults.ease,
      accelerate: defaults.accelerate,
      otpEnter: defaults.otpEnter,
      otpExit: defaults.otpExit,
      decelerate: defaults.decelerate,
      easeInOutCubic: defaults.easeInOutCubic,
      short2: defaults.short2,
      short3: defaults.short3,
      short4: defaults.short4,
      medium2: defaults.medium2,
      indicatorTurn: defaults.indicatorTurn,
      progressSweep: defaults.progressSweep,
      short1: defaults.short1,
      toggle: defaults.toggle,
      medium1: defaults.medium1,
      long2: defaults.long2,
      rippleMin: defaults.rippleMin,
      ripple: defaults.ripple,
      pulse: defaults.pulse,
      shimmer: defaults.shimmer,
      pressedScale: defaults.pressedScale,
    );
    for (final spring in [FlSpring.effects, FlSpring.effectsFast]) {
      expect(
        _ratio((FlMotion(tokens: tokens, reduced: false).spring(spring) as FlSpringMotion).description),
        closeTo(0.6, 1e-9),
      );
      final reduced = FlMotion(tokens: tokens, reduced: true).spring(spring) as FlSpringMotion;
      expect(_ratio(reduced.description), closeTo(1.0, 1e-9), reason: spring.name);
      expect(reduced.description.stiffness, 1600);
    }
  });

  testWidgets("devrait passer au fondu sous FlScope quand Reduce Motion iOS s'active pendant que l'app tourne", (
    tester,
  ) async {
    late FlMotion motion;
    await tester.pumpWidget(
      FlScope(
        child: Builder(
          builder: (context) {
            motion = FlMotion.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(motion.spring(FlSpring.spatial), isA<FlSpringMotion>());

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(motion.spring(FlSpring.spatial), isA<FlFadeMotion>());
  });

  testWidgets('devrait finir exactement sur la cible, puis terminer son futur, quand le ressort de driveTo s’arrête', (
    tester,
  ) async {
    final controller = AnimationController.unbounded(vsync: const TestVSync());
    addTearDown(controller.dispose);
    double? landed;
    unawaited(
      controller
          .driveTo(1, FlSpringMotion(FlTokens.defaults.motion.press))
          .then((reached) => landed = reached ? controller.value : null),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.value, inExclusiveRange(0, 1));
    expect(landed, isNull);
    await tester.pumpAndSettle();
    expect(controller.value, 1);
    expect(landed, 1);
  });

  testWidgets('devrait terminer le futur par false quand un autre driveTo interrompt le ressort', (tester) async {
    final controller = AnimationController.unbounded(vsync: const TestVSync());
    addTearDown(controller.dispose);
    final spring = FlSpringMotion(FlTokens.defaults.motion.press);
    final reached = <bool>[];
    unawaited(controller.driveTo(1, spring).then(reached.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    unawaited(controller.driveTo(0, spring).then(reached.add));
    await tester.pumpAndSettle();
    expect(reached, [false, true]);
    expect(controller.value, 0);
  });

  testWidgets('devrait terminer le futur par false quand le contrôleur est disposé en route', (tester) async {
    final controller = AnimationController.unbounded(vsync: const TestVSync());
    bool? reached;
    unawaited(controller.driveTo(1, FlFadeMotion(FlTokens.defaults.motion.short3)).then((value) => reached = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    controller.dispose();
    await tester.pump();
    expect(reached, isFalse);
  });

  testWidgets(
    'devrait aller linéairement à la cible en 150 ms, même quand Android réduit les durées, quand driveTo reçoit un fondu',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final controller = AnimationController.unbounded(vsync: const TestVSync());
      addTearDown(controller.dispose);
      unawaited(controller.driveTo(1, FlFadeMotion(FlTokens.defaults.motion.short3)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(controller.value, closeTo(0.5, 0.01));
      await tester.pump(const Duration(milliseconds: 80));
      expect(controller.value, 1);
      expect(controller.isAnimating, isFalse);
    },
  );
}

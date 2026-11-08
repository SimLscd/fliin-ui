import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// The spring of an animation, chosen by use (DESIGN.md §2.4). [FlMotion.spring]
/// turns it into a [FlMotionSpec] according to the tokens and reduced motion;
/// the durations quoted are those of the default tokens.
enum FlSpring {
  /// Pressed state, switches, checkboxes (about 120 ms). Under reduced motion,
  /// a fade lasting `motion.duration.short3`, with no spring or overshoot.
  press,
  /// Opening a popover, a menu, an accordion (about 170 ms). A fade under
  /// reduced motion.
  spatial,
  /// Sheet, page transition (about 260 ms). A fade under reduced motion.
  spatialSlow,
  /// End of a gesture released with velocity: released sheet, swipe to delete
  /// (about 375 ms, slight overshoot). A fade under reduced motion.
  release,
  /// Color, opacity, shadow (about 145 ms). Stays a spring, without overshoot,
  /// under reduced motion.
  effects,
  /// Hover, focus (about 95 ms). Stays a spring, without overshoot, under
  /// reduced motion.
  effectsFast,
}

/// How an animation advances: a spring ([FlSpringMotion]) or a linear fade
/// ([FlFadeMotion]). Obtained from [FlMotion.spring] and played by `driveTo`.
sealed class FlMotionSpec {
  const FlMotionSpec();
}

/// A physical spring animation, starting from the current velocity.
final class FlSpringMotion extends FlMotionSpec {
  /// A spring described by [description].
  const FlSpringMotion(this.description);

  /// Mass, stiffness and damping of the spring.
  final SpringDescription description;
}

/// The linear fade of reduced motion, in place of a spatial spring: the
/// animated value must only drive an opacity.
final class FlFadeMotion extends FlMotionSpec {
  /// A fade of [duration].
  const FlFadeMotion(this.duration);

  /// The fade's duration, `short3` (150 ms) with the default tokens.
  final Duration duration;
}

/// The motion tokens of a context and the reduced-motion state. A component
/// reads it with [FlMotion.of] and picks its animations with [spring].
final class FlMotion {
  /// Motion on [tokens], reduced when [reduced] is true. [FlMotion.of] builds
  /// it from the context.
  const FlMotion({required this.tokens, required this.reduced});

  /// The theme's springs and durations.
  final FlMotionTokens tokens;
  /// True when the user asked for fewer animations: Reduce Motion on iOS,
  /// "Remove animations" on Android.
  final bool reduced;

  /// Android's "Remove animations" arrives through `MediaQuery`, iOS's Reduce
  /// Motion through `FlScope`, which listens for it on `PlatformDispatcher`.
  static FlMotion of(BuildContext context) {
    final theme = FlScope.of(context);
    return FlMotion(
      tokens: theme.motion,
      reduced: theme.reduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
    );
  }

  /// The specification of [spring]: the token spring, or under reduced motion a
  /// `short3` fade for a spatial spring and a critically damped spring for an
  /// effect.
  FlMotionSpec spring(FlSpring spring) {
    final description = switch (spring) {
      FlSpring.press => tokens.press,
      FlSpring.spatial => tokens.spatial,
      FlSpring.spatialSlow => tokens.spatialSlow,
      FlSpring.release => tokens.release,
      FlSpring.effects => tokens.effects,
      FlSpring.effectsFast => tokens.effectsFast,
    };
    if (!reduced) return FlSpringMotion(description);
    return switch (spring) {
      FlSpring.press || FlSpring.spatial || FlSpring.spatialSlow || FlSpring.release => FlFadeMotion(tokens.short3),
      FlSpring.effects || FlSpring.effectsFast => FlSpringMotion(
        SpringDescription.withDampingRatio(mass: description.mass, stiffness: description.stiffness),
      ),
    };
  }
}

/// Plays a [FlMotionSpec] on an `AnimationController`.
extension FlMotionDrive on AnimationController {
  /// Goes to [target] from the current value and velocity, so that an
  /// interruption does not make the animation jump (DESIGN.md §2.4). The
  /// spring stops within a tolerance: the value is set to [target] at the
  /// end, so that the resting state is exact.
  ///
  /// [FlFadeMotion] is the reduced-motion fade (DESIGN.md §2.4, "spatial
  /// springs become 150 ms fades"; §9.3, "no translation"): the value goes
  /// linearly to [target] over the fade's duration, even when Android shortens
  /// durations, if the controller keeps `AnimationBehavior.preserve`, like
  /// `AnimationController.unbounded`. It must then only drive an opacity,
  /// never a position or a scale.
  ///
  /// The future always completes: `true` when the value is set to [target],
  /// `false` when another animation, `stop` or `dispose` interrupts this one.
  /// It can therefore be awaited without risk of hanging.
  Future<bool> driveTo(double target, FlMotionSpec spec, {double? velocity}) {
    final run = switch (spec) {
      FlSpringMotion(:final description) => animateWith(
        SpringSimulation(description, value, target, velocity ?? this.velocity),
      ),
      FlFadeMotion(:final duration) => animateTo(target, duration: duration),
    };
    return run.orCancel.then(
      (_) {
        value = target;
        return true;
      },
      onError: (Object error) => error is TickerCanceled ? false : throw error,
    );
  }
}

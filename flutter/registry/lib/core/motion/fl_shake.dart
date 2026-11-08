import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/motion/fl_motion_scope.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// Shakes [child] sideways once each time [active] turns true: a code or a
/// value the app refuses. The `shake` spring is thrown from rest, towards
/// the start of the line first, and swings about three times around its
/// place, `space.xs × 1.5` at most. Nothing moves under reduced motion: the
/// refusal is already written, outlined or announced.
class FlShake extends StatefulWidget {
  /// Shakes [child] when [active] turns true.
  const FlShake({super.key, required this.active, required this.child});

  /// Turning true shakes [child]; staying true does not shake it again.
  final bool active;

  /// What shakes.
  final Widget child;

  @override
  State<FlShake> createState() => _FlShakeState();
}

class _FlShakeState extends State<FlShake> with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(vsync: this);

  @override
  void didUpdateWidget(FlShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.active) return;
    final motion = FlMotion.of(context);
    if (motion.reduced) return;
    final spring = motion.tokens.shake;
    // The peak of a spring thrown from rest is close to its velocity over its
    // angular frequency.
    final amplitude = FlScope.of(context).space.xs * 1.5;
    final towardStart = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    final velocity = towardStart * amplitude * math.sqrt(spring.stiffness / spring.mass);
    _x
        .animateWith(SpringSimulation(spring, 0, 0, velocity))
        .orCancel
        .then<void>((_) => _x.value = 0, onError: (Object error) => error is TickerCanceled ? null : throw error);
  }

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _x,
    builder: (context, child) => Transform.translate(offset: Offset(_x.value, 0), child: child),
    child: widget.child,
  );
}

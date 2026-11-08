import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/motion/fl_motion_scope.dart';

/// Shows [child] by scaling it from [from] to full size on the `pop` spring,
/// which overshoots slightly, while it fades in over `short3`; hides it by
/// shrinking it back while it fades out over `short2`. A count's badge that
/// appears, a liked heart, a toast's icon once the toast has landed. Under
/// reduced motion, it only fades.
///
/// [replay] bumps a child that stays: turning true, it scales [child] back
/// to [from] and lets the spring bring it back, past full size and down
/// again (a box being checked, a heart being liked); nothing moves under
/// reduced motion.
///
/// At rest, shown, it paints [child] untouched. On its way out, it keeps
/// painting the child it last showed (a badge leaves with its last count,
/// not with 0). Hidden and faded out, it lays out nothing.
class FlPop extends StatefulWidget {
  /// Pops [child] in when [shown] turns true, out when it turns false.
  const FlPop({
    super.key,
    this.shown = true,
    this.appear = false,
    this.from = 0,
    this.delay = Duration.zero,
    this.replay = false,
    required this.child,
  }) : assert(from >= 0 && from < 1, 'the starting scale is below full size');

  /// True: [child] shows; turning false pops it out.
  final bool shown;

  /// True: [child] also pops in when this widget is first built shown,
  /// instead of showing at once.
  final bool appear;

  /// The scale [child] starts from on its way in, and returns to on its way
  /// out: 0, it grows from nothing; 0.6, it bumps.
  final double from;

  /// How long [child] waits, hidden, before popping in: a toast's icon waits
  /// for the toast to land.
  final Duration delay;

  /// Turning true pops [child] again from [from], without fading it.
  final bool replay;

  /// What pops.
  final Widget child;

  @override
  State<FlPop> createState() => _FlPopState();
}

class _FlPopState extends State<FlPop> with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: _rest);
  // Reduced-motion fades keep their duration when the system shortens
  // animations (DESIGN.md §2.4).
  late final AnimationController _opacity = AnimationController(
    vsync: this,
    value: _rest,
    animationBehavior: AnimationBehavior.preserve,
  );
  var _started = false;
  late Widget _shownChild = widget.child;

  double get _rest => widget.shown && !widget.appear ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.shown && widget.appear) _show();
  }

  @override
  void didUpdateWidget(FlPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown != oldWidget.shown) {
      widget.shown ? _show() : _hide();
    } else if (widget.shown && widget.replay && !oldWidget.replay) {
      _bump();
    }
  }

  void _bump() {
    final motion = FlMotion.of(context);
    if (motion.reduced) return;
    _settle(_scale, SpringSimulation(motion.tokens.pop, widget.from, 1, 0), 1);
  }

  void _show() {
    final motion = FlMotion.of(context);
    final tokens = motion.tokens;
    final delay = widget.delay.inMicroseconds / Duration.microsecondsPerSecond;
    final fade = tokens.short3.inMicroseconds / Duration.microsecondsPerSecond;
    _settle(_opacity, _Delayed(_Linear(_opacity.value, 1, fade), delay), 1);
    if (motion.reduced) {
      _scale.value = 1;
      return;
    }
    final start = math.max(_scale.value, widget.from);
    _settle(_scale, _Delayed(SpringSimulation(tokens.pop, start, 1, 0), delay), 1);
  }

  void _hide() {
    final motion = FlMotion.of(context);
    final tokens = motion.tokens;
    _settle(_opacity, _Linear(_opacity.value, 0, tokens.short2.inMicroseconds / Duration.microsecondsPerSecond), 0);
    if (!motion.reduced) {
      _scale.driveTo(widget.from, FlSpringMotion(tokens.effects));
    }
  }

  /// Runs [simulation], then sets [target] exactly: a spring stops within a
  /// tolerance, and a scale of 0.999 would blur the child at rest.
  static void _settle(AnimationController controller, Simulation simulation, double target) {
    controller
        .animateWith(simulation)
        .orCancel
        .then<void>(
          (_) => controller.value = target,
          onError: (Object error) => error is TickerCanceled ? null : throw error,
        );
  }

  @override
  void dispose() {
    _scale.dispose();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.shown) _shownChild = widget.child;
    return AnimatedBuilder(
      animation: Listenable.merge([_scale, _opacity]),
      builder: (context, child) {
        final opacity = _opacity.value.clamp(0.0, 1.0);
        if (!widget.shown && opacity == 0) return const SizedBox.shrink();
        return _Fade(
          alpha: Color.getAlphaFromOpacity(opacity),
          child: Transform.scale(scale: math.max(0, _scale.value), child: child),
        );
      },
      child: _shownChild,
    );
  }
}

/// [child] at [alpha]. Unlike `Opacity`, fully opaque it adds no layer: an
/// opacity layer, even at 255, moves the antialiasing of what it holds, and
/// [FlPop] at rest must paint its child as if it were not there.
class _Fade extends SingleChildRenderObjectWidget {
  const _Fade({required this.alpha, super.child});

  final int alpha;

  @override
  _RenderFade createRenderObject(BuildContext context) => _RenderFade(alpha);

  @override
  void updateRenderObject(BuildContext context, _RenderFade renderObject) => renderObject.alpha = alpha;
}

class _RenderFade extends RenderProxyBox {
  _RenderFade(this._alpha);

  int _alpha;
  set alpha(int value) {
    if (value == _alpha) return;
    final composited = alwaysNeedsCompositing;
    final visible = _alpha > 0;
    _alpha = value;
    if (composited != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    if (visible != _alpha > 0) markNeedsSemanticsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _alpha > 0 && _alpha < 255;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _alpha == 0) {
      layer = null;
      return;
    }
    if (_alpha == 255) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushOpacity(offset, _alpha, super.paint, oldLayer: layer as OpacityLayer?);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child case final child? when _alpha > 0) visitor(child);
  }
}

/// [inner], held at its start for [delay] seconds.
class _Delayed extends Simulation {
  _Delayed(this.inner, this.delay);

  final Simulation inner;
  final double delay;

  @override
  double x(double time) => inner.x(math.max(0, time - delay));

  @override
  double dx(double time) => time < delay ? 0 : inner.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && inner.isDone(time - delay);
}

/// From [from] to [to] at constant speed over [duration] seconds.
class _Linear extends Simulation {
  _Linear(this.from, this.to, this.duration);

  final double from;
  final double to;
  final double duration;

  @override
  double x(double time) => duration <= 0 ? to : from + (to - from) * math.min(1, time / duration);

  @override
  double dx(double time) => duration <= 0 || time >= duration ? 0 : (to - from) / duration;

  @override
  bool isDone(double time) => time >= duration;
}

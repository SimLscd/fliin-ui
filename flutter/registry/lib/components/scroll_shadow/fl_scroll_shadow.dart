// Modified from the ScrollShadow of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
// The eased gradient follows easeGradient from react-native-easing-gradient
// (@phamfoo, MIT).
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The edges of an [FlScrollShadow] that can carry a shadow. `top` and
/// `start` name the same edge: the top of a vertical scroll, the start (on
/// the right in RTL) of a horizontal scroll; `bottom` and `end`, the
/// opposite edge.
enum FlScrollShadowVisibility {
  /// Both edges, each when content overflows on its side.
  auto,

  /// Same as [auto].
  both,

  /// The top, or the start: the edge where already-scrolled content
  /// overflows.
  top,

  /// The bottom, or the end: the edge where upcoming content overflows.
  bottom,

  /// Same as [top], for a horizontal scroll.
  start,

  /// Same as [bottom], for a horizontal scroll.
  end,

  /// No edge.
  none,
}

/// Fades the edges of a scrollable into the page color: a gradient of
/// [size] points at each edge where content overflows, opaque at the edge
/// and transparent toward the inside, along `motion.curve.easeInOut`. Its
/// opacity follows the scroll: zero when the edge is reached, full once a
/// quarter of [size] of content is hidden on that side.
///
/// [child] is the scrollable (`ListView`, `SingleChildScrollView`…), whose
/// axis gives the orientation. A shadow removed by [visibility] or
/// [enabled] fades out over `motion.duration.short4`, at once under reduced
/// motion.
class FlScrollShadow extends StatefulWidget {
  /// Shadows on both edges, 50 points deep, `surface` colored.
  const FlScrollShadow({
    super.key,
    this.size = 50,
    this.visibility = FlScrollShadowVisibility.auto,
    this.enabled = true,
    this.color,
    this.mask = false,
    this.onVisibilityChange,
    required this.child,
  });

  /// The depth of each gradient, in points: 50 by default.
  final double size;

  /// The edges that can carry a shadow.
  final FlScrollShadowVisibility visibility;

  /// False, both shadows fade out.
  final bool enabled;

  /// The shadow color; null, `surface`, the page background. Unused with
  /// [mask].
  final Color? color;

  /// True: the content itself fades out at the edges, as a mask, instead of
  /// a color painted over it, so the shadow works over a gradient, an image
  /// or a tinted card.
  final bool mask;

  /// Called with the edges where content is hidden, whenever they change
  /// while scrolling: [FlScrollShadowVisibility.top], `bottom`, `both` or
  /// `none` for a vertical scroll, `start`, `end`, `both` or `none` for a
  /// horizontal one.
  final ValueChanged<FlScrollShadowVisibility>? onVisibilityChange;

  /// The scrollable.
  final Widget child;

  @override
  State<FlScrollShadow> createState() => _FlScrollShadowState();
}

class _FlScrollShadowState extends State<FlScrollShadow> with TickerProviderStateMixin {
  late final AnimationController _leading = AnimationController(vsync: this);
  late final AnimationController _trailing = AnimationController(vsync: this);
  ScrollMetrics? _metrics;
  FlScrollShadowVisibility? _reported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FlScrollShadow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _leading.dispose();
    _trailing.dispose();
    super.dispose();
  }

  bool _onScroll(int depth, ScrollMetrics metrics) {
    if (depth != 0) return false;
    final axisChanged = metrics.axis != _metrics?.axis;
    _metrics = metrics;
    if (axisChanged) setState(() {});
    _sync();
    _report(metrics);
    return false;
  }

  void _report(ScrollMetrics metrics) {
    final onVisibilityChange = widget.onVisibilityChange;
    if (onVisibilityChange == null) return;
    final reading = switch (metrics.axis) {
      Axis.vertical => AxisDirection.down,
      Axis.horizontal => textDirectionToAxisDirection(Directionality.of(context)),
    };
    final forward = metrics.axisDirection == reading;
    final before = (forward ? metrics.extentBefore : metrics.extentAfter) > 0;
    final after = (forward ? metrics.extentAfter : metrics.extentBefore) > 0;
    final vertical = metrics.axis == Axis.vertical;
    final visibility = switch ((before, after)) {
      (true, true) => FlScrollShadowVisibility.both,
      (true, false) => vertical ? FlScrollShadowVisibility.top : FlScrollShadowVisibility.start,
      (false, true) => vertical ? FlScrollShadowVisibility.bottom : FlScrollShadowVisibility.end,
      (false, false) => FlScrollShadowVisibility.none,
    };
    if (visibility == _reported) return;
    _reported = visibility;
    // The first metrics arrive during layout, where the parent cannot
    // rebuild yet.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) onVisibilityChange(visibility);
      });
    } else {
      onVisibilityChange(visibility);
    }
  }

  void _sync() {
    final metrics = _metrics;
    if (metrics == null) return;
    final reading = switch (metrics.axis) {
      Axis.vertical => AxisDirection.down,
      Axis.horizontal => textDirectionToAxisDirection(Directionality.of(context)),
    };
    final forward = metrics.axisDirection == reading;
    final (leading, trailing) = switch (widget.visibility) {
      _ when !widget.enabled => (false, false),
      FlScrollShadowVisibility.auto || FlScrollShadowVisibility.both => (true, true),
      FlScrollShadowVisibility.top || FlScrollShadowVisibility.start => (true, false),
      FlScrollShadowVisibility.bottom || FlScrollShadowVisibility.end => (false, true),
      FlScrollShadowVisibility.none => (false, false),
    };
    final motion = FlMotion.of(context);
    void drive(AnimationController shade, {required bool shown, required double hidden}) {
      if (shown) {
        shade.value = (hidden / (widget.size / 4)).clamp(0.0, 1.0);
      } else if (motion.reduced) {
        shade.value = 0;
      } else if (shade.value > 0 && !shade.isAnimating) {
        shade.animateTo(0, duration: motion.tokens.short4, curve: motion.tokens.easeInOutQuad);
      }
    }

    drive(_leading, shown: leading, hidden: forward ? metrics.extentBefore : metrics.extentAfter);
    drive(_trailing, shown: trailing, hidden: forward ? metrics.extentAfter : metrics.extentBefore);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final color = widget.color ?? theme.colors.surface;
    final ease = theme.motion.easeInOut;
    // An eased gradient: 14 stops, opacity eased from the edge toward
    // the inside.
    final steps = [for (var i = 0; i <= 13; i++) i / 13];
    final colors = [for (final t in steps) color.withValues(alpha: 1 - ease.transform(t))];
    Widget shade(AnimationController opacity, AlignmentGeometry edge, AlignmentGeometry inside) => IgnorePointer(
      child: FadeTransition(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: edge, end: inside, colors: colors, stops: steps),
          ),
        ),
      ),
    );
    final size = widget.size;
    final axis = _metrics?.axis;
    Widget listen(Widget child) => NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onScroll(n.depth, n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(n.depth, n.metrics),
        child: child,
      ),
    );
    if (widget.mask) {
      return listen(
        AnimatedBuilder(
          animation: Listenable.merge([_leading, _trailing]),
          builder: (context, child) => axis == null
              ? child!
              : ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) {
                    final extent = axis == Axis.vertical ? bounds.height : bounds.width;
                    final reach = extent <= 0 ? 0.0 : (size / extent).clamp(0.0, 0.5);
                    // The content's opacity, eased from the edge inward as
                    // the colored shadow's.
                    final stops = [for (final t in steps) t * reach, for (final t in steps.reversed) 1 - t * reach];
                    final alphas = [
                      for (final t in steps) 1 - _leading.value * (1 - ease.transform(t)),
                      for (final t in steps.reversed) 1 - _trailing.value * (1 - ease.transform(t)),
                    ];
                    final opaque = theme.colors.onSurface;
                    return LinearGradient(
                      begin: axis == Axis.vertical ? Alignment.topCenter : AlignmentDirectional.centerStart,
                      end: axis == Axis.vertical ? Alignment.bottomCenter : AlignmentDirectional.centerEnd,
                      colors: [for (final a in alphas) opaque.withValues(alpha: a)],
                      stops: stops,
                    ).createShader(bounds, textDirection: Directionality.of(context));
                  },
                  child: child,
                ),
          child: widget.child,
        ),
      );
    }
    return listen(
      Stack(
        children: [
          widget.child,
          ...switch (axis) {
            null => const <Widget>[],
            Axis.vertical => [
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                height: size,
                child: shade(_leading, Alignment.topCenter, Alignment.bottomCenter),
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                height: size,
                child: shade(_trailing, Alignment.bottomCenter, Alignment.topCenter),
              ),
            ],
            Axis.horizontal => [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: size,
                child: shade(_leading, AlignmentDirectional.centerStart, AlignmentDirectional.centerEnd),
              ),
              PositionedDirectional(
                end: 0,
                top: 0,
                bottom: 0,
                width: size,
                child: shade(_trailing, AlignmentDirectional.centerEnd, AlignmentDirectional.centerStart),
              ),
            ],
          },
        ],
      ),
    );
  }
}

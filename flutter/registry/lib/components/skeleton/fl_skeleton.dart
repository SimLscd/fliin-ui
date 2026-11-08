// Modified from the Skeleton and SkeletonGroup of HeroUI Native 1.0.10,
// Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'dart:ui' show lerpDouble;

import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The animation of an [FlSkeleton] while loading.
enum FlSkeletonVariant {
  /// A `skeletonShimmer` highlight sweeps across the bone in reading
  /// direction, endlessly, over `motion.duration.shimmer`, at constant speed.
  shimmer,

  /// The opacity goes from 0.5 to 1 and back, `motion.duration.pulse` each
  /// way, along `motion.curve.easeInOut`.
  pulse,

  /// A still bone, which appears and disappears without a fade.
  none,
}

/// A loading placeholder: a bone of the `skeleton` color, sized and rounded
/// by the caller, in place of [child] while [loading] is true. When
/// [loading] turns false, [child] replaces the bone with a
/// `motion.duration.medium2` fade (no fade for [FlSkeletonVariant.none]).
///
/// Under reduced motion, neither shimmer nor pulse: the bone stays still, at
/// opacity 0.5 for [FlSkeletonVariant.pulse], and fades are
/// instant.
///
/// While loading, the bone announces itself as a loading indicator named
/// [label]; inside an [FlSkeletonGroup], the group announces itself instead,
/// only once.
class FlSkeleton extends StatefulWidget {
  /// A standalone bone, [FlSkeletonVariant.shimmer] and loading by default.
  const FlSkeleton({
    super.key,
    required String this.label,
    bool this.loading = true,
    FlSkeletonVariant this.variant = FlSkeletonVariant.shimmer,
    this.width,
    this.height,
    this.radius = 0,
    this.child,
  });

  /// A bone of an [FlSkeletonGroup]: without [loading] or [variant], it takes
  /// the group's; it does not announce itself, the group does.
  const FlSkeleton.item({super.key, this.loading, this.variant, this.width, this.height, this.radius = 0, this.child})
    : label = null;

  /// What is loading, read by the screen reader; null for a group bone.
  final String? label;

  /// True while loading: the bone in place of [child].
  final bool? loading;

  /// The bone's animation.
  final FlSkeletonVariant? variant;

  /// The bone's width; when null, the one the parent imposes.
  final double? width;

  /// The bone's height; when null, the one the parent imposes.
  final double? height;

  /// The radius of the bone's continuous corners. Beyond half the shorter
  /// side, the bone becomes a capsule, or a circle if it is square.
  final double radius;

  /// The loaded content, shown when [loading] is false.
  final Widget? child;

  @override
  State<FlSkeleton> createState() => _FlSkeletonState();
}

class _FlSkeletonState extends State<FlSkeleton> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this);
  late final AnimationController _enter = AnimationController(vsync: this);
  FlSkeletonVariant? _running;
  var _entered = false;

  ({bool loading, FlSkeletonVariant variant}) _resolve() {
    final group = context.dependOnInheritedWidgetOfExactType<_FlSkeletonGroupScope>();
    assert(widget.label != null || group != null, 'FlSkeleton.item outside an FlSkeletonGroup');
    return (
      loading: widget.loading ?? group?.loading ?? true,
      variant: widget.variant ?? group?.variant ?? FlSkeletonVariant.shimmer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = FlMotion.of(context);
    if (!_entered) {
      _entered = true;
      // The fade-in entrance, which `none` and reduced motion skip.
      if (motion.reduced || _resolve().variant == FlSkeletonVariant.none) {
        _enter.value = 1;
      } else {
        _enter.animateTo(1, duration: motion.tokens.medium2, curve: motion.tokens.easeInOutQuad);
      }
    }
    _sync();
  }

  @override
  void didUpdateWidget(FlSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final motion = FlMotion.of(context);
    final (:loading, :variant) = _resolve();
    final running = loading && !motion.reduced && variant != FlSkeletonVariant.none ? variant : null;
    if (running == _running) return;
    _running = running;
    _loop.value = 0;
    switch (running) {
      case null || FlSkeletonVariant.none:
        _loop.stop();
      case FlSkeletonVariant.shimmer:
        _loop
          ..duration = motion.tokens.shimmer
          ..repeat();
      case FlSkeletonVariant.pulse:
        _loop
          ..duration = motion.tokens.pulse
          ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final motion = FlMotion.of(context);
    final (:loading, :variant) = _resolve();
    final shown = loading ? _bone(theme, motion, variant) : (widget.child ?? const SizedBox.shrink());
    return FadeTransition(
      opacity: _enter,
      alwaysIncludeSemantics: true,
      child: AnimatedSwitcher(
        duration: motion.reduced || variant == FlSkeletonVariant.none ? Duration.zero : motion.tokens.medium2,
        switchInCurve: motion.tokens.easeInOutQuad,
        switchOutCurve: motion.tokens.easeInOutQuad,
        // A bone without a width takes the parent's: constraints pass
        // through unchanged, where the default Stack loosens them.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.passthrough,
          alignment: AlignmentDirectional.topStart,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(loading), child: shown),
      ),
    );
  }

  Widget _bone(FlTheme theme, FlMotion motion, FlSkeletonVariant variant) {
    Widget bone = FlPixelSnap(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _BonePainter(
            radius: widget.radius,
            fill: theme.colors.skeleton,
            highlight: theme.colors.skeletonShimmer,
            sweep: _running == FlSkeletonVariant.shimmer ? _loop : null,
            travel: MediaQuery.sizeOf(context).width,
            direction: Directionality.of(context),
          ),
        ),
      ),
    );
    if (variant == FlSkeletonVariant.pulse) {
      bone = FadeTransition(
        opacity: _loop.drive(CurveTween(curve: motion.tokens.easeInOut)).drive(Tween(begin: 0.5, end: 1)),
        child: bone,
      );
    }
    return switch (widget.label) {
      final label? => Semantics(
        container: true,
        role: SemanticsRole.loadingSpinner,
        label: label,
        child: ExcludeSemantics(child: bone),
      ),
      null => ExcludeSemantics(child: bone),
    };
  }
}

/// The bone's fill, and the highlight that sweeps across it: a horizontal
/// transparent, [highlight], transparent gradient, as wide as the bone, that
/// starts just before the bone and ends [travel] (the screen width) past its
/// start edge, clipped to the bone's shape.
class _BonePainter extends CustomPainter {
  _BonePainter({
    required this.radius,
    required this.fill,
    required this.highlight,
    required this.sweep,
    required this.travel,
    required this.direction,
  }) : super(repaint: sweep);

  final double radius;
  final Color fill;
  final Color highlight;
  final Animation<double>? sweep;
  final double travel;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final path = FlContinuousBorder.pathFor(Offset.zero & size, radius);
    canvas.drawPath(path, Paint()..color = fill);
    final progress = sweep?.value;
    // The ends are transparent: no color outside the tokens, the highlight
    // fades into its own.
    final clear = highlight.withValues(alpha: 0);
    if (progress == null) return;
    final (from, to) = direction == TextDirection.ltr ? (-size.width, travel) : (travel, -size.width);
    final band = Offset(lerpDouble(from, to, progress)!, 0) & size;
    canvas
      ..save()
      ..clipPath(path)
      ..drawRect(band, Paint()..shader = LinearGradient(colors: [clear, highlight, clear]).createShader(band))
      ..restore();
  }

  @override
  bool shouldRepaint(_BonePainter oldDelegate) =>
      radius != oldDelegate.radius ||
      fill != oldDelegate.fill ||
      highlight != oldDelegate.highlight ||
      sweep != oldDelegate.sweep ||
      travel != oldDelegate.travel ||
      direction != oldDelegate.direction;
}

/// A group of bones that load together: each [FlSkeleton.item] in [child]
/// takes the group's [loading] and [variant], unless it gives its own. The
/// group announces itself once as a loading indicator named [label].
class FlSkeletonGroup extends StatelessWidget {
  /// A loading group, [FlSkeletonVariant.shimmer] by default.
  const FlSkeletonGroup({
    super.key,
    required this.label,
    this.loading = true,
    this.variant = FlSkeletonVariant.shimmer,
    this.skeletonOnly = false,
    required this.child,
  });

  /// What is loading, read by the screen reader.
  final String label;

  /// True while loading, for each bone of the group.
  final bool loading;

  /// The animation of each bone of the group.
  final FlSkeletonVariant variant;

  /// True when [child] exists only for loading: the group renders nothing
  /// once [loading] is false.
  final bool skeletonOnly;

  /// The layout of the bones and what surrounds them.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (skeletonOnly && !loading) return const SizedBox.shrink();
    final scope = _FlSkeletonGroupScope(loading: loading, variant: variant, child: child);
    if (!loading) return scope;
    return Semantics(container: true, role: SemanticsRole.loadingSpinner, label: label, child: scope);
  }
}

/// Lines of text not loaded yet: [lines] bones of `space.md` high, `space.sm`
/// apart (the 20-point rhythm of `textSm`), with `shape.radiusXs` corners,
/// the full width of the parent, the last one [lastLineWidth] of it.
///
/// With [label], it is a group of its own, announced once; without, it
/// belongs to the enclosing [FlSkeletonGroup], whose loading state and
/// [variant] it takes unless it gives its own. Once loaded, [child] takes
/// its place.
class FlSkeletonText extends StatelessWidget {
  /// Three lines, the last at 60 %.
  const FlSkeletonText({
    super.key,
    this.lines = 3,
    this.lastLineWidth = 0.6,
    this.label,
    this.loading,
    this.variant,
    this.child,
  }) : assert(lines > 0, 'at least one line'),
       assert(lastLineWidth > 0 && lastLineWidth <= 1, 'a share of the width, from 0 to 1');

  /// The number of lines.
  final int lines;

  /// The width of the last line, as a share of the parent's; a single line
  /// takes the full width.
  final double lastLineWidth;

  /// What is loading, read by the screen reader; null inside a group.
  final String? label;

  /// True while loading; the group's, otherwise true, when null.
  final bool? loading;

  /// The animation of the lines; the group's, otherwise
  /// [FlSkeletonVariant.shimmer], when null.
  final FlSkeletonVariant? variant;

  /// The loaded text, shown when loading is over.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final group = context.dependOnInheritedWidgetOfExactType<_FlSkeletonGroupScope>();
    final label = this.label;
    assert(label != null || group != null, 'FlSkeletonText without a label outside an FlSkeletonGroup');
    final loading = this.loading ?? (label == null ? group?.loading : null) ?? true;
    if (!loading) return child ?? const SizedBox.shrink();
    final variant = this.variant ?? group?.variant ?? FlSkeletonVariant.shimmer;
    final bones = _FlSkeletonGroupScope(
      loading: true,
      variant: variant,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.sm,
        children: [
          for (var i = 0; i < lines; i++)
            FractionallySizedBox(
              widthFactor: i == lines - 1 && lines > 1 ? lastLineWidth : 1,
              child: FlSkeleton.item(height: theme.space.md, radius: theme.shape.radiusXs),
            ),
        ],
      ),
    );
    if (label == null) return bones;
    return Semantics(container: true, role: SemanticsRole.loadingSpinner, label: label, child: bones);
  }
}

class _FlSkeletonGroupScope extends InheritedWidget {
  const _FlSkeletonGroupScope({required this.loading, required this.variant, required super.child});

  final bool loading;
  final FlSkeletonVariant variant;

  @override
  bool updateShouldNotify(_FlSkeletonGroupScope oldWidget) =>
      loading != oldWidget.loading || variant != oldWidget.variant;
}

// Modified from the use-popup-* hooks of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/motion/fl_motion_scope.dart';
import 'package:fliin_ui/core/overlay/fl_anchor.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';
import 'package:fliin_ui/core/tokens/tokens.g.dart';

/// The scrim under a popup.
enum FlPopupBackdrop {
  /// `scrim`, modulated by `size.scrimOpacity`: dialog and sheet.
  opaque,

  /// Invisible, it only receives the tap that closes: popover and menu.
  transparent,
}

/// The dialog settles from this scale as it appears (a little less than 1.05,
/// on a phone's narrower panel).
const double _dialogEnterScale = 1.04;

/// The scale a dialog or popover shrinks to as it leaves.
const double _exitScale = 0.96;

/// The scale a popover grows from, at its anchor.
const double _popoverEnterScale = 0.92;

/// The entrance of a popup's content, one per presentation.
enum FlPopupEntrance {
  /// Settles from 1.04 to 1 when appearing, shrinks to 0.96 when leaving: a
  /// modal.
  dialog,

  /// Slides from the anchor, by at most `size.popoverTravel`, growing from
  /// 0.92 to 1 out of the anchor's side; leaves shrinking to 0.96 towards it:
  /// a popover or a dropdown.
  popover,

  /// Rises from the bottom by its full height.
  sheet,
}

/// The outline of a floating panel (popover, menu): `border` in dark, where
/// the `overlay` shadow barely detaches the panel from the page; transparent
/// in light, where the three soft layers of `overlay` draw the edge.
/// Transparent rather than absent, so the panel keeps its
/// insets in both appearances.
Color flOverlayOutline(FlTheme theme) => switch (theme.brightness) {
  Brightness.dark => theme.colors.border,
  Brightness.light => theme.colors.border.withValues(alpha: 0),
};

/// The controller of a popup: it opens in `motion.duration.short4` and closes
/// in `short3`. A value of 0 is closed, 1
/// open. It keeps its durations when the system disables animations: the
/// reduced-motion fade lasts as long (DESIGN.md §2.4).
AnimationController flPopupController({required TickerProvider vsync, required FlMotionTokens motion}) =>
    AnimationController(
      vsync: vsync,
      duration: motion.short4,
      reverseDuration: motion.short3,
      animationBehavior: AnimationBehavior.preserve,
    );

/// The scrim of a popup, whose opacity follows [animation] along
/// `motion.curve.easeInOutQuad`. A tap calls [onDismiss]; when null, the scrim
/// blocks the tap without closing. [dismissLabel] names this tap for screen
/// readers.
class FlPopupOverlay extends StatelessWidget {
  /// A [backdrop] scrim that follows [animation].
  const FlPopupOverlay({
    super.key,
    required this.animation,
    this.backdrop = FlPopupBackdrop.opaque,
    this.onDismiss,
    this.dismissLabel,
  });

  /// The popup's openness, from 0 to 1.
  final Animation<double> animation;

  /// Opaque or transparent.
  final FlPopupBackdrop backdrop;

  /// Called when the scrim is tapped.
  final VoidCallback? onDismiss;

  /// The name of the closing tap, for screen readers.
  final String? dismissLabel;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final veil = switch (backdrop) {
      FlPopupBackdrop.opaque => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: theme.motion.easeInOutQuad),
        // `scrim` carries its opacity (35 % in light, 55 % in dark); `scrimOpacity` modulates it.
        child: ColoredBox(color: theme.colors.scrim.withValues(alpha: theme.colors.scrim.a * theme.size.scrimOpacity)),
      ),
      FlPopupBackdrop.transparent => const SizedBox.expand(),
    };
    return Semantics(
      label: onDismiss == null ? null : dismissLabel,
      onTap: onDismiss,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onDismiss, child: veil),
    );
  }
}

/// The content of a popup, which enters and leaves according to [entrance] as
/// [animation] goes from 0 to 1 and back: `easeOut` on entry, `easeIn` on the
/// dialog's exit, `easeOut` both ways for the popover. Under reduced motion,
/// it only fades in.
class FlPopupContent extends StatelessWidget {
  /// [child] placed by [entrance].
  const FlPopupContent({
    super.key,
    required this.animation,
    required this.entrance,
    this.side = FlSide.bottom,
    this.offset,
    required this.child,
  });

  /// The popup's openness, from 0 to 1.
  final Animation<double> animation;

  /// Dialog, popover or sheet.
  final FlPopupEntrance entrance;

  /// The side of the anchor where a popover sits: it comes from there.
  final FlSide side;

  /// The gap between a popover and its anchor; it slides by the smaller of
  /// [offset] and `size.popoverTravel`. When null: `size.popoverTravel`.
  final double? offset;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = FlMotion.of(context);
    final travel = FlScope.of(context).size.popoverTravel;
    final curved = CurvedAnimation(
      parent: animation,
      curve: motion.tokens.easeOut,
      reverseCurve: entrance == FlPopupEntrance.dialog ? motion.tokens.easeIn : motion.tokens.easeOut,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    if (motion.reduced) return faded;
    return switch (entrance) {
      FlPopupEntrance.dialog => _DialogEntrance(animation: curved, child: faded),
      FlPopupEntrance.popover => _PopoverEntrance(
        animation: curved,
        distance: math.min(offset ?? travel, travel),
        side: side,
        child: faded,
      ),
      FlPopupEntrance.sheet => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      ),
    };
  }
}

class _PopoverEntrance extends AnimatedWidget {
  const _PopoverEntrance({
    required Animation<double> animation,
    required this.distance,
    required this.side,
    required this.child,
  }) : super(listenable: animation);

  final double distance;
  final FlSide side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final t = animation.value;
    final away = distance * (1 - t);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The content comes from the anchor: from below for a popover placed above.
    final shift = switch (side) {
      FlSide.top => Offset(0, away),
      FlSide.bottom => Offset(0, -away),
      FlSide.start => Offset(rtl ? -away : away, 0),
      FlSide.end => Offset(rtl ? away : -away, 0),
    };
    final scale = animation.status == AnimationStatus.reverse
        ? _exitScale + (1 - _exitScale) * t
        : _popoverEnterScale + (1 - _popoverEnterScale) * t;
    // The panel grows out of its anchor, like CSS's `--trigger-anchor-point`.
    final origin = switch (side) {
      FlSide.top => AlignmentDirectional.bottomCenter,
      FlSide.bottom => AlignmentDirectional.topCenter,
      FlSide.start => AlignmentDirectional.centerEnd,
      FlSide.end => AlignmentDirectional.centerStart,
    };
    return Transform.translate(
      offset: shift,
      child: Transform.scale(scale: scale, alignment: origin.resolve(Directionality.of(context)), child: child),
    );
  }
}

class _DialogEntrance extends AnimatedWidget {
  const _DialogEntrance({required Animation<double> animation, required this.child}) : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final t = animation.value;
    final scale = animation.status == AnimationStatus.reverse
        ? _exitScale + (1 - _exitScale) * t
        : _dialogEnterScale - (_dialogEnterScale - 1) * t;
    return Transform.scale(scale: scale, child: child);
  }
}

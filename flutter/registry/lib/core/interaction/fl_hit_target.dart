import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// Extends the touch target of [child] to `FlTheme.hitTarget` (48×48 Android,
/// 44×44 iOS, 24×24 desktop) outside of layout, like React Native's
/// `hitSlop`: the box keeps the size of [child], and only the touch and the
/// semantic rectangle overflow, centered on it.
///
/// The semantics node is the target's: the control's semantics sit beneath
/// it, without `container`, so that screen readers and guidelines read its
/// rectangle.
///
/// Under a [FlHitTargetHost] (placed by the root `FlScope`), a touch in the
/// margin passes through ancestors smaller than the target, and goes to the
/// nearest target when several margins overlap. Without a host, the margin
/// only receives what the ancestors let through.
///
/// Near a screen edge, the target is pulled back inside: the part that would
/// stick out moves to the other side of the control, without ever uncovering
/// it. The touch follows it under a host, which always leaves a neighbor's
/// visible part to that neighbor. Without a host, the touch keeps the target
/// centered: pulled back, it would take a larger share of the visible part of
/// the neighbor painted before it. Only the semantic rectangle is then pulled
/// back.
class FlHitTarget extends SingleChildRenderObjectWidget {
  /// A touch target around `child`, at the size given by the nearest
  /// `FlScope`.
  const FlHitTarget({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitTarget(FlScope.of(context).hitTarget, Scrollable.maybeOf(context)?.position);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHitTarget)
      ..side = FlScope.of(context).hitTarget
      ..scroll = Scrollable.maybeOf(context)?.position;
  }
}

class _RenderHitTarget extends RenderProxyBox {
  _RenderHitTarget(this._side, this._scroll);

  double _side;
  set side(double value) {
    if (value == _side) return;
    _side = value;
    markNeedsSemanticsUpdate();
  }

  /// The nearest scroll: it moves the target without relaying it out, and its
  /// position on screen changes its semantic rectangle.
  Listenable? _scroll;
  set scroll(Listenable? value) {
    if (value == _scroll) return;
    if (attached) {
      _scroll?.removeListener(_moved);
      value?.addListener(_moved);
    }
    _scroll = value;
  }

  /// The target's rectangle is computed with the geometry of its semantic
  /// parent: that parent is the one that must recompute it.
  void _moved() => parent?.markNeedsSemanticsUpdate();

  final List<_RenderHitTargetHost> _hosts = [];

  bool get _slops => size.width < _side || size.height < _side;

  /// The target, centered on the control.
  Rect get _centered => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: math.max(size.width, _side),
    height: math.max(size.height, _side),
  );

  /// The screen reader's target: centered, then pulled back onto the screen.
  Rect get _target {
    final centered = _centered;
    if (!_slops || !attached) return centered;
    final screen = _screenIn(this);
    return screen == null ? centered : _within(centered, Offset.zero & size, screen);
  }

  /// The screen (the view) in the frame of [object], or null if there is no
  /// view above it or the transform is not invertible.
  static Rect? _screenIn(RenderObject object) {
    RenderObject root = object;
    for (var node = object.parent; node != null; node = node.parent) {
      root = node;
    }
    if (root is! RenderView) return null;
    final toObject = Matrix4.tryInvert(object.getTransformTo(root));
    // The view's frame is in physical pixels: its paint bounds, not its size.
    return toObject == null ? null : MatrixUtils.transformRect(toObject, root.paintBounds);
  }

  /// [target] pulled back into [screen]: near an edge, the part that would
  /// stick out moves to the other side of the control, without ever
  /// uncovering [visible]. The three rectangles are in the same frame.
  static Rect _within(Rect target, Rect visible, Rect screen) {
    double shift(double low, double high, double visibleLow, double visibleHigh, double screenLow, double screenHigh) {
      final wanted = low < screenLow
          ? screenLow - low
          : high > screenHigh
          ? screenHigh - high
          : 0.0;
      return math.min(math.max(wanted, visibleHigh - high), visibleLow - low);
    }

    return target.translate(
      shift(target.left, target.right, visible.left, visible.right, screen.left, screen.right),
      shift(target.top, target.bottom, visible.top, visible.bottom, screen.top, screen.bottom),
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addListener(_moved);
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderHitTargetHost) {
        node._targets.add(this);
        _hosts.add(node);
      }
    }
  }

  @override
  void detach() {
    _scroll?.removeListener(_moved);
    for (final host in _hosts) {
      host._targets.remove(this);
    }
    _hosts.clear();
    super.detach();
  }

  @override
  Rect get semanticBounds => _target;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    if (_hosts.isNotEmpty || !_centered.contains(position)) return false;
    final center = size.center(Offset.zero);
    if (!hitTestChildren(result, position: center)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  bool _isBelow(RenderObject ancestor) {
    for (var node = parent; node != null; node = node.parent) {
      if (node == ancestor) return true;
    }
    return false;
  }

  /// The squared distance from [position] (in [host]'s frame) to the visible
  /// part, if it falls within the margin left by the clipping ancestors.
  double? _reach(_RenderHitTargetHost host, Offset position, Rect? screen) {
    if (!hasSize || !_slops) return null;
    final transform = getTransformTo(host);
    final centered = MatrixUtils.transformRect(transform, _centered);
    final visible = MatrixUtils.transformRect(transform, Offset.zero & size);
    if (!(screen == null ? centered : _within(centered, visible, screen)).contains(position)) {
      return null;
    }
    for (RenderObject child = this; child != host; child = child.parent!) {
      final parent = child.parent!;
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null && !MatrixUtils.transformRect(parent.getTransformTo(host), clip).contains(position)) {
        return null;
      }
    }
    final dx = math.max(0.0, math.max(visible.left - position.dx, position.dx - visible.right));
    final dy = math.max(0.0, math.max(visible.top - position.dy, position.dy - visible.bottom));
    return dx * dx + dy * dy;
  }
}

/// The area where [FlHitTarget]s extend their touch beyond their ancestors.
/// The root `FlScope` places it; an app without a `FlScope` above its
/// controls places it itself, above the `Navigator`.
///
/// A touch that falls on no target's visible part, but within the margin of
/// one or more, goes to the nearest, among those the touched point contains
/// (a target inside a target wins over it): it is replayed at the center of
/// that target, and all its ancestors receive it, a scrolling list included.
/// Whatever the point touches that is painted above the target (an open
/// popover, a card, an app's detector) keeps the touch, and the cursor. A
/// clipping ancestor (`ClipRect`, a list's viewport) bounds the margin, and a
/// target covered at its center (a modal route above) does not receive it.
class FlHitTargetHost extends SingleChildRenderObjectWidget {
  /// An extension area around [child].
  const FlHitTargetHost({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitTargetHost();
}

class _RenderHitTargetHost extends RenderProxyBox {
  final Set<_RenderHitTarget> _targets = {};

  static bool _holds(BoxHitTestResult result, _RenderHitTarget target) =>
      result.path.any((entry) => entry.target == target);

  /// True if [touched], what the point directly touches, is an ancestor of
  /// [target] or is painted before it: the margin never passes under what is
  /// painted above the target, as in React Native.
  static bool _beneath(RenderObject touched, _RenderHitTarget target) {
    final branches = <RenderObject, RenderObject>{};
    for (RenderObject node = touched; node.parent != null; node = node.parent!) {
      branches[node.parent!] = node;
    }
    if (branches.containsKey(target)) return false;
    for (RenderObject node = target; node.parent != null; node = node.parent!) {
      final common = node.parent!;
      if (common == touched) return true;
      final other = branches[common];
      if (other == null) continue;
      RenderObject? first;
      common.visitChildren((child) => first ??= child == other || child == node ? child : null);
      return first == other;
    }
    return false;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    // The screen once per touch, in the host's frame, for all targets.
    final screen = _targets.isEmpty ? null : _RenderHitTarget._screenIn(this);
    final reached = [
      for (final target in _targets)
        if (target._reach(this, position, screen) case final distance?) (target, distance),
    ];
    if (reached.isEmpty) return super.hitTest(result, position: position);
    final direct = BoxHitTestResult();
    hitTestChildren(direct, position: position);
    final touched = direct.path.map((entry) => entry.target).whereType<RenderObject>();
    final deepest = touched.firstOrNull;
    final innermost = touched.whereType<_RenderHitTarget>().firstOrNull;
    final candidates = [
      for (final (target, distance) in reached)
        if (target != innermost &&
            (innermost == null || target._isBelow(innermost)) &&
            (deepest == null || _beneath(deepest, target)))
          (target, distance),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (target, _) in candidates) {
      final center = MatrixUtils.transformPoint(target.getTransformTo(this), target.size.center(Offset.zero));
      final trial = BoxHitTestResult();
      if (!hitTestChildren(trial, position: center) || !_holds(trial, target)) {
        continue;
      }
      hitTestChildren(result, position: center);
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return super.hitTest(result, position: position);
  }
}

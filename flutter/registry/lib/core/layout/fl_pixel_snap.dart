import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Places [child] on the physical pixel grid, as Yoga and UIKit do for every
/// view in React Native: its size rounds up to the next whole
/// pixel (the child is laid out again with that minimum), and its top-left
/// corner is painted at the nearest pixel. Its edges stay sharp instead of
/// smearing into antialiasing over half a pixel. Hit testing reuses the
/// offset of the last paint, the one the eye sees, even if an ancestor has
/// moved since without repainting it.
class FlPixelSnap extends SingleChildRenderObjectWidget {
  /// Aligns [child] on the grid of `MediaQuery.devicePixelRatioOf`.
  const FlPixelSnap({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPixelSnap(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderPixelSnap).ratio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderPixelSnap extends RenderShiftedBox {
  _RenderPixelSnap(this._ratio) : super(null);

  double _ratio;
  set ratio(double value) {
    if (value == _ratio) return;
    _ratio = value;
    markNeedsLayout();
  }

  double _up(double v) => (v * _ratio - 1e-6).ceilToDouble() / _ratio;

  Size _snapped(BoxConstraints constraints, Size child) =>
      constraints.constrain(Size(_up(child.width), _up(child.height)));

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _snapped(constraints, child?.getDryLayout(constraints) ?? Size.zero);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _snapped(constraints, child.size);
    // A minimum, not a tight size: if tight, the child would become a relayout
    // boundary and would no longer tell this parent that its natural size
    // changed.
    if (child.size != size) {
      child.layout(constraints.copyWith(minWidth: size.width, minHeight: size.height), parentUsesSize: true);
    }
  }

  /// The offset, at the last paint, between the on-screen top-left corner and
  /// the nearest pixel.
  Offset _nudge = Offset.zero;

  @override
  void paint(PaintingContext context, Offset offset) {
    final toScreen = getTransformTo(null);
    final origin = MatrixUtils.transformPoint(toScreen, Offset.zero);
    double round(double v) => (v * _ratio).roundToDouble() / _ratio - v;
    _nudge = Offset(round(origin.dx), round(origin.dy));
    final moved = toScreen != _toScreen;
    _toScreen = toScreen;
    if (moved) _realignDescendants();
    super.paint(context, offset + _nudge);
  }

  /// The transform to the screen at the last paint, offset included.
  Matrix4? _toScreen;

  /// True when a realignment is waiting for this one's position to settle.
  bool _realignPending = false;

  /// A descendant [FlPixelSnap] under a repaint boundary computed its offset
  /// from this one's former on-screen position (an entrance scale, an offset),
  /// and its boundary will not repaint by itself: `flushPaint` repaints the
  /// deepest first, and does not repaint a clean boundary. It is marked for
  /// paint once, when this one's position has stopped moving from one frame
  /// to the next: during an ancestor's animation, it waits for the end instead
  /// of repainting every frame. An unchanged position marks nothing for paint:
  /// the frames stop.
  void _realignDescendants() {
    if (_realignPending) return;
    _realignPending = true;
    final scheduler = WidgetsBinding.instance;
    Matrix4? seen;
    void settle(Duration _) {
      if (!attached) {
        _realignPending = false;
        return;
      }
      final now = getTransformTo(null);
      if (now != seen) {
        seen = now;
        scheduler
          ..addPostFrameCallback(settle)
          ..scheduleFrame();
        return;
      }
      _realignPending = false;
      // A descendant painted in the same boundary as this one has already been
      // repainted with it: marking it again would repaint this boundary, and
      // this one with it.
      void visit(RenderObject node, {required bool apart}) {
        if (node is _RenderPixelSnap && apart) {
          node.markNeedsPaint();
          return;
        }
        node.visitChildren((child) => visit(child, apart: apart || child.isRepaintBoundary));
      }

      visitChildren((child) => visit(child, apart: child.isRepaintBoundary));
    }

    scheduler
      ..addPostFrameCallback(settle)
      ..scheduleFrame();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position - _nudge)) return false;
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final childOffset = (child.parentData! as BoxParentData).offset + _nudge;
    return result.addWithPaintOffset(
      offset: childOffset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset + _nudge;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}

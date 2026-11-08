import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// The side of the anchor where the overlay sits. [start] and [end] follow
/// the reading direction.
enum FlSide {
  /// Above the anchor.
  top,
  /// Below the anchor.
  bottom,
  /// On the side where reading starts: left in LTR, right in RTL.
  start,
  /// On the side where reading ends: right in LTR, left in RTL.
  end,
}

/// The alignment of the overlay along the anchor: on a [FlSide.top] or
/// [FlSide.bottom] side, [start] and [end] follow the reading direction; on a
/// [FlSide.start] or [FlSide.end] side, they go from top to bottom.
enum FlAlign {
  /// The overlay's start edge on the anchor's, or their top edges on a lateral
  /// side.
  start,
  /// The overlay centered on the anchor.
  center,
  /// The overlay's end edge on the anchor's, or their bottom edges on a lateral
  /// side.
  end,
}

/// Where the overlay sits: its top-left corner in the overlay's frame, and the
/// side retained, which is not the requested side when it had to flip.
typedef FlAnchorFit = ({Offset offset, FlSide side});

enum _Edge { top, bottom, left, right }

extension on _Edge {
  bool get vertical => this == _Edge.top || this == _Edge.bottom;

  _Edge get opposite => switch (this) {
    _Edge.top => _Edge.bottom,
    _Edge.bottom => _Edge.top,
    _Edge.left => _Edge.right,
    _Edge.right => _Edge.left,
  };

  FlSide side(TextDirection direction) => switch ((this, direction)) {
    (_Edge.top, _) => FlSide.top,
    (_Edge.bottom, _) => FlSide.bottom,
    (_Edge.left, TextDirection.ltr) || (_Edge.right, TextDirection.rtl) => FlSide.start,
    (_Edge.right, TextDirection.ltr) || (_Edge.left, TextDirection.rtl) => FlSide.end,
  };

  /// The room between the anchor and the edge of [bounds], on this side.
  double room(Rect anchor, Rect bounds, double gap) => switch (this) {
    _Edge.top => anchor.top - gap - bounds.top,
    _Edge.bottom => bounds.bottom - anchor.bottom - gap,
    _Edge.left => anchor.left - gap - bounds.left,
    _Edge.right => bounds.right - anchor.right - gap,
  };

  /// The coordinate of the top or left edge of the child placed on this side.
  double place(Rect anchor, Size child, double gap) => switch (this) {
    _Edge.top => anchor.top - gap - child.height,
    _Edge.bottom => anchor.bottom + gap,
    _Edge.left => anchor.left - gap - child.width,
    _Edge.right => anchor.right + gap,
  };
}

_Edge _edge(FlSide side, TextDirection direction) => switch ((side, direction)) {
  (FlSide.top, _) => _Edge.top,
  (FlSide.bottom, _) => _Edge.bottom,
  (FlSide.start, TextDirection.ltr) || (FlSide.end, TextDirection.rtl) => _Edge.left,
  (FlSide.end, TextDirection.ltr) || (FlSide.start, TextDirection.rtl) => _Edge.right,
};

/// Brings [value] into [min, max - extent]. A child larger than the area
/// sticks to the start edge: left, or right when [fromEnd].
double _shift(double value, double min, double max, double extent, {bool fromEnd = false}) {
  if (max - min < extent) return fromEnd ? max - extent : min;
  return value.clamp(min, max - extent);
}

/// Places a child of size [child] against [anchor], within [bounds], on side
/// [side] and aligned by [align], [gap] from the anchor.
///
/// If the child does not fit on the requested side, it takes the side with
/// the most room; if it does not fit there either, it overflows onto the
/// anchor rather than out of [bounds]. Along the anchor, it slides to stay
/// within [bounds].
FlAnchorFit flAnchor({
  required Rect anchor,
  required Size child,
  required Rect bounds,
  required FlSide side,
  required FlAlign align,
  required TextDirection direction,
  required double gap,
}) {
  final preferred = _edge(side, direction);
  final extent = preferred.vertical ? child.height : child.width;
  final room = preferred.room(anchor, bounds, gap);
  final edge = room >= extent || room >= preferred.opposite.room(anchor, bounds, gap) ? preferred : preferred.opposite;
  final rtl = direction == TextDirection.rtl;
  final main = edge.place(anchor, child, gap);
  if (edge.vertical) {
    final (start, end) = rtl ? (anchor.right - child.width, anchor.left) : (anchor.left, anchor.right - child.width);
    final cross = switch (align) {
      FlAlign.start => start,
      FlAlign.center => anchor.center.dx - child.width / 2,
      FlAlign.end => end,
    };
    return (
      offset: Offset(
        _shift(cross, bounds.left, bounds.right, child.width, fromEnd: rtl),
        _shift(main, bounds.top, bounds.bottom, child.height),
      ),
      side: edge.side(direction),
    );
  }
  final cross = switch (align) {
    FlAlign.start => anchor.top,
    FlAlign.center => anchor.center.dy - child.height / 2,
    FlAlign.end => anchor.bottom - child.height,
  };
  return (
    offset: Offset(
      _shift(main, bounds.left, bounds.right, child.width, fromEnd: rtl),
      _shift(cross, bounds.top, bounds.bottom, child.height),
    ),
    side: edge.side(direction),
  );
}

/// The area of an overlay of size [overlay] where an anchored child can sit:
/// without the notches and system bars ([padding]) or the keyboard
/// ([viewInsets]), [margin] from the edges.
Rect flAnchorBounds({
  required Size overlay,
  required EdgeInsets padding,
  required EdgeInsets viewInsets,
  required double margin,
}) => Rect.fromLTRB(
  math.max(padding.left, viewInsets.left) + margin,
  math.max(padding.top, viewInsets.top) + margin,
  overlay.width - math.max(padding.right, viewInsets.right) - margin,
  overlay.height - math.max(padding.bottom, viewInsets.bottom) - margin,
);

/// Places [child] against [anchor], a rectangle in the frame of the
/// surrounding overlay, with [flAnchor]: [gap] from the anchor, [margin] from
/// the safe edges of `MediaQuery`. The child never exceeds the safe area.
///
/// [travel] moves the child that many points closer to the anchor, on the
/// retained side: an entrance that starts from the anchor without knowing the
/// final side.
class FlAnchoredLayout extends StatelessWidget {
  /// A child placed below the anchor and aligned with its start, by default.
  const FlAnchoredLayout({
    super.key,
    required this.anchor,
    this.side = FlSide.bottom,
    this.align = FlAlign.start,
    this.travel = 0,
    this.gap,
    this.margin,
    required this.child,
  });

  /// The anchor's rectangle, in the overlay's frame.
  final Rect anchor;
  /// The requested side; the child moves to the opposite side when it does not
  /// fit and the other has more room.
  final FlSide side;
  /// The child's alignment along the anchor.
  final FlAlign align;
  /// The entrance offset towards the anchor, in logical points, on the
  /// retained side; 0 at rest.
  final double travel;
  /// The gap between the anchor and the child; when null: `space.xs`.
  final double? gap;
  /// The margin between the child and the safe edges; when null: `space.sm`.
  final double? margin;
  /// The panel to place, kept within the safe area.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return CustomSingleChildLayout(
      delegate: _AnchorDelegate(
        anchor: anchor,
        side: side,
        align: align,
        direction: Directionality.of(context),
        gap: gap ?? theme.space.xs,
        margin: margin ?? theme.space.sm,
        padding: MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero,
        viewInsets: MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero,
        travel: travel,
      ),
      child: child,
    );
  }
}

class _AnchorDelegate extends SingleChildLayoutDelegate {
  const _AnchorDelegate({
    required this.anchor,
    required this.side,
    required this.align,
    required this.direction,
    required this.gap,
    required this.margin,
    required this.padding,
    required this.viewInsets,
    required this.travel,
  });

  final Rect anchor;
  final FlSide side;
  final FlAlign align;
  final TextDirection direction;
  final double gap;
  final double margin;
  final EdgeInsets padding;
  final EdgeInsets viewInsets;
  final double travel;

  Rect _bounds(Size overlay) =>
      flAnchorBounds(overlay: overlay, padding: padding, viewInsets: viewInsets, margin: margin);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bounds = _bounds(constraints.biggest);
    return BoxConstraints.loose(Size(math.max(bounds.width, 0), math.max(bounds.height, 0)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fit = flAnchor(
      anchor: anchor,
      child: childSize,
      bounds: _bounds(size),
      side: side,
      align: align,
      direction: direction,
      gap: gap,
    );
    final toward = switch (_edge(fit.side, direction)) {
      _Edge.top => Offset(0, travel),
      _Edge.bottom => Offset(0, -travel),
      _Edge.left => Offset(travel, 0),
      _Edge.right => Offset(-travel, 0),
    };
    return fit.offset + toward;
  }

  @override
  bool shouldRelayout(_AnchorDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      side != oldDelegate.side ||
      align != oldDelegate.align ||
      direction != oldDelegate.direction ||
      gap != oldDelegate.gap ||
      margin != oldDelegate.margin ||
      padding != oldDelegate.padding ||
      viewInsets != oldDelegate.viewInsets ||
      travel != oldDelegate.travel;
}

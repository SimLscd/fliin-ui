import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';

/// Around the control, or within its edge when it spans the full width (a
/// list row): outside, the ring would leave the screen and overlap the
/// neighboring rows.
enum FlFocusRingPlacement {
  /// The ring surrounds the control, `size.focusRingGap` from its edge.
  outside,

  /// The ring is drawn within the control's edge, for a full-width surface.
  inside,
}

/// Draws the keyboard focus ring over [child] when [visible] is true, in the
/// `focusRing` color and `size.focusRing` thick. `FlPressable` places it on
/// the `focused` state.
class FlFocusRing extends StatelessWidget {
  /// A ring that follows [borderRadius], outside by default.
  const FlFocusRing({
    super.key,
    required this.visible,
    required this.borderRadius,
    required this.child,
    this.placement = FlFocusRingPlacement.outside,
    this.gap,
  });

  /// True to draw the ring; false renders [child] alone.
  final bool visible;

  /// The corners of [child], which the ring follows, enlarged by the gap when
  /// it is outside.
  final BorderRadiusGeometry borderRadius;

  /// The surrounded control; the ring paints over it without changing its size.
  final Widget child;

  /// Outside or within the edge, see [FlFocusRingPlacement].
  final FlFocusRingPlacement placement;

  /// The distance between the control's edge and an outside ring; when
  /// null, `size.focusRingGap`. A field takes 0: its ring hugs its outline.
  final double? gap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final theme = FlScope.of(context);
    return CustomPaint(
      foregroundPainter: _FocusRingPainter(
        color: theme.colors.focusRing,
        width: theme.size.focusRing,
        gap: gap ?? theme.size.focusRingGap,
        borderRadius: borderRadius.resolve(Directionality.of(context)),
        placement: placement,
      ),
      child: child,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.color,
    required this.width,
    required this.gap,
    required this.borderRadius,
    required this.placement,
  });

  final Color color;
  final double width;
  final double gap;
  final BorderRadius borderRadius;
  final FlFocusRingPlacement placement;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = borderRadius.toRRect(Offset.zero & size);
    canvas.drawRRect(
      switch (placement) {
        FlFocusRingPlacement.outside => shape.inflate(gap + width / 2),
        FlFocusRingPlacement.inside => shape.deflate(width / 2),
      },
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      color != oldDelegate.color ||
      width != oldDelegate.width ||
      gap != oldDelegate.gap ||
      borderRadius != oldDelegate.borderRadius ||
      placement != oldDelegate.placement;
}

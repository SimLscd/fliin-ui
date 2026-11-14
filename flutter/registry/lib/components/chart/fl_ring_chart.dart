import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/chart/fl_category.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The ring's thickness, a share of its diameter.
const double _thickness = 0.12;

/// The shares of a whole as a ring: one slice per share from the top, in
/// the reading direction (clockwise, counterclockwise in RTL), separated by
/// `space.xs` of the surface under it, in the plain colors of
/// [FlCategoryFill]. [center] sits in the hole: the total, or the chosen
/// share.
///
/// With [selected], the chosen slice is in `selected` and the others in
/// `selectedSoft`. With [onSelected], touching a slice chooses it; the
/// screen reader reads [semanticLabel] as a button whose tap chooses the
/// next share, so that every share can be reached. Without it, the ring is
/// an image read as [semanticLabel].
class FlRingChart extends StatelessWidget {
  /// The ring of [shares].
  const FlRingChart({
    super.key,
    required this.shares,
    required this.semanticLabel,
    this.selected,
    this.onSelected,
    this.diameter,
    this.center,
  });

  /// The shares, in order: their color follows it.
  final List<FlShare> shares;

  /// What the screen reader says of the ring: the total and each share.
  final String semanticLabel;

  /// The chosen share; null, none.
  final int? selected;

  /// Receives the share touched; null, the ring is not pressable.
  final ValueChanged<int>? onSelected;

  /// The ring's diameter; null, five times the control height.
  final double? diameter;

  /// What the hole shows, centered and scaled down to fit.
  final Widget? center;

  double get _total => shares.fold(0.0, (sum, s) => sum + s.weight);

  /// The share under [position], in a ring of [size]; null in the hole,
  /// outside the ring or between two slices.
  int? _hit(Offset position, double size, TextDirection direction) {
    final total = _total;
    if (total == 0) return null;
    final c = Offset(size / 2, size / 2);
    final v = position - c;
    final outer = size / 2;
    // The hole and a band just inside it still choose: a finger is wider
    // than the ring.
    if (v.distance > outer || v.distance < outer * (1 - _thickness * 2.5)) {
      return null;
    }
    var angle = math.atan2(v.dx, -v.dy);
    if (direction == TextDirection.rtl) angle = -angle;
    if (angle < 0) angle += 2 * math.pi;
    var start = 0.0;
    for (final (i, share) in shares.indexed) {
      final sweep = share.weight / total * 2 * math.pi;
      if (angle >= start && angle < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  int _next() {
    final drawn = [
      for (final (i, share) in shares.indexed)
        if (share.weight > 0) i,
    ];
    if (drawn.isEmpty) return 0;
    final at = drawn.indexOf(selected ?? -1);
    return drawn[(at + 1) % drawn.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final size = diameter ?? theme.controlHeight * 5;
    final direction = Directionality.of(context);
    final onSelected = this.onSelected;
    final hole = size * (1 - _thickness * 2) - theme.space.lg * 2;
    Widget ring = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          shares: shares,
          selected: selected,
          colors: theme.colors,
          gap: theme.space.xs,
          direction: direction,
        ),
        child: Center(
          child: SizedBox.square(
            dimension: math.max(0, hole),
            child: center == null ? null : FittedBox(fit: BoxFit.scaleDown, child: center),
          ),
        ),
      ),
    );
    if (onSelected != null) {
      ring = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: (details) {
          final hit = _hit(details.localPosition, size, direction);
          if (hit != null) onSelected(hit);
        },
        child: ring,
      );
    }
    // Centered at its own size, whatever the width it is given.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Semantics(
        container: true,
        image: onSelected == null,
        button: onSelected != null,
        label: semanticLabel,
        value: switch (selected) {
          final i? when i < shares.length => shares[i].semanticLabel ?? shares[i].label,
          _ => null,
        },
        onTap: onSelected == null ? null : () => onSelected(_next()),
        child: ExcludeSemantics(child: ring),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.shares,
    required this.selected,
    required this.colors,
    required this.gap,
    required this.direction,
  });

  final List<FlShare> shares;
  final int? selected;
  final FlColorTokens colors;
  final double gap;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final total = shares.fold(0.0, (sum, s) => sum + s.weight);
    final stroke = size.width * _thickness;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        paint..color = FlCategoryFill(FlCategoryFill.count - 1).color(colors),
      );
      return;
    }
    final drawn = shares.where((s) => s.weight > 0).length;
    // The gap, as an angle on the middle of the ring.
    final gapAngle = drawn > 1 ? gap / (rect.width / 2) : 0.0;
    final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
    var start = -math.pi / 2;
    for (final (i, share) in shares.indexed) {
      if (share.weight == 0) continue;
      final sweep = share.weight / total * 2 * math.pi;
      final visible = math.max(sweep - gapAngle, sweep * 0.25);
      // With a choice, the chosen slice in the primary color and the others
      // quiet, as the share bar draws them; without one, the shades of each
      // category.
      paint.color = switch (selected) {
        null => FlCategoryFill(i).color(colors),
        final chosen => i == chosen ? colors.selected : colors.selectedSoft,
      };
      canvas.drawArc(rect, start * sign + (sign < 0 ? -math.pi : 0), visible * sign, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.shares != shares || old.selected != selected || old.colors != colors || old.direction != direction;
}

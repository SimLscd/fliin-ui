import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/chart/fl_category.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The dashes of the block of what remains: a dash, then a gap.
const double _dash = 5;
const double _dashGap = 4;

/// The shares of a whole as blocks side by side, each as wide as its share,
/// filled by [FlCategoryFill] in their order: where the money went. A share
/// too small to see keeps the width of `space.lg` + `space.xs`; a share
/// worth nothing leaves no block. [remaining] adds a dashed block at the
/// end, what is left of a budget.
///
/// With [onSelected], touching a block chooses its share, and the chosen
/// one ([selected]) turns `selected`. For the screen reader, the blocks are
/// one button read as [semanticLabel] with the chosen share as its value,
/// whose tap chooses the next share: a small share's block is narrower than
/// a finger, so a node per block would be a target too small to reach.
/// Without [onSelected], the blocks are one image read as [semanticLabel].
/// In RTL, the first share is on the right.
class FlShareBlocks extends StatelessWidget {
  /// The blocks of [shares].
  const FlShareBlocks({
    super.key,
    required this.shares,
    required this.semanticLabel,
    this.selected,
    this.onSelected,
    this.height,
    this.radius,
    this.remaining = 0,
  });

  /// The shares, in order: their fill follows it.
  final List<FlShare> shares;

  /// What the screen reader says of the whole: the total and each share.
  final String semanticLabel;

  /// The chosen share; null, none.
  final int? selected;

  /// Receives the share tapped; null, the blocks are not pressable.
  final ValueChanged<int>? onSelected;

  /// The blocks' height; null, twice and a quarter the control height.
  final double? height;

  /// The blocks' corner radius, bounded by half their width; null,
  /// `radiusCard`.
  final double? radius;

  /// The weight of what remains, in the shares' unit, drawn dashed after
  /// them; zero, nothing.
  final double remaining;

  /// The widths of [weights] in [available], each at least [minimum] while
  /// that fits, the rest shared by weight.
  static List<double> _widths(List<double> weights, double available, double minimum) {
    final n = weights.length;
    if (n == 0) return const [];
    if (available <= minimum * n) {
      return List.filled(n, math.max(0, available / n));
    }
    final fixed = List.filled(n, false);
    while (true) {
      final free = available - minimum * fixed.where((f) => f).length;
      final total = [
        for (var i = 0; i < n; i++)
          if (!fixed[i]) weights[i],
      ].fold(0.0, (a, b) => a + b);
      var changed = false;
      for (var i = 0; i < n; i++) {
        if (!fixed[i] && (total == 0 || weights[i] / total * free < minimum)) {
          fixed[i] = true;
          changed = true;
        }
      }
      if (!changed) {
        return [for (var i = 0; i < n; i++) fixed[i] ? minimum : weights[i] / total * free];
      }
      if (fixed.every((f) => f)) return List.filled(n, available / n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final height = this.height ?? theme.controlHeight * 2.25;
    final drawn = [
      for (final (i, share) in shares.indexed)
        if (share.weight > 0) i,
    ];
    final rest = remaining.isFinite && remaining > 0 ? remaining : 0.0;
    final onSelected = this.onSelected;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = theme.space.xs;
          final count = drawn.length + (rest > 0 ? 1 : 0);
          final widths = _widths(
            [for (final i in drawn) shares[i].weight, if (rest > 0) rest],
            constraints.maxWidth - gap * math.max(0, count - 1),
            theme.space.lg + theme.space.xs,
          );
          final corner = radius ?? theme.shape.radiusCard;
          Widget block(int slot) {
            final width = widths[slot];
            final shape = BorderRadius.circular(math.min(corner, math.min(width, height) / 2));
            if (slot == drawn.length) {
              return SizedBox(
                width: width,
                child: CustomPaint(
                  painter: _DashedPainter(color: theme.colors.border, stroke: theme.size.border * 1.5, radius: shape),
                ),
              );
            }
            final index = drawn[slot];
            final chosen = index == selected;
            final paint = CustomPaint(
              size: Size(width, height),
              painter: _BlockPainter(
                fill: FlCategoryFill(index),
                selected: chosen,
                colors: theme.colors,
                radius: shape,
              ),
            );
            if (onSelected == null) return paint;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => onSelected(index),
              child: paint,
            );
          }

          final row = Row(spacing: gap, children: [for (var slot = 0; slot < count; slot++) block(slot)]);
          if (onSelected == null) {
            return Semantics(
              image: true,
              label: semanticLabel,
              child: ExcludeSemantics(child: row),
            );
          }
          final chosen = selected;
          return Semantics(
            container: true,
            button: true,
            label: semanticLabel,
            value: chosen != null && chosen < shares.length
                ? shares[chosen].semanticLabel ?? shares[chosen].label
                : null,
            onTap: drawn.isEmpty ? null : () => onSelected(drawn[(drawn.indexOf(chosen ?? -1) + 1) % drawn.length]),
            child: ExcludeSemantics(child: row),
          );
        },
      ),
    );
  }
}

class _BlockPainter extends CustomPainter {
  const _BlockPainter({required this.fill, required this.selected, required this.colors, required this.radius});

  final FlCategoryFill fill;
  final bool selected;
  final FlColorTokens colors;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) =>
      fill.paint(canvas, radius.toRRect(Offset.zero & size), colors, selected: selected);

  @override
  bool shouldRepaint(_BlockPainter old) =>
      old.fill.index != fill.index || old.selected != selected || old.colors != colors || old.radius != radius;
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color, required this.stroke, required this.radius});

  final Color color;
  final double stroke;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) => paintDashedRRect(
    canvas,
    radius.toRRect((Offset.zero & size).deflate(stroke / 2)),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke,
  );

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color || old.stroke != stroke || old.radius != radius;
}

/// Strokes [shape] in dashes with [paint]: the outline of what remains, or
/// of a total that sums the rows above it.
void paintDashedRRect(Canvas canvas, RRect shape, Paint paint) {
  final path = Path()..addRRect(shape);
  for (final ui.PathMetric metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += _dash + _dashGap) {
      canvas.drawPath(metric.extractPath(d, math.min(d + _dash, metric.length)), paint);
    }
  }
}

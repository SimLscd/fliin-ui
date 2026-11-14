import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/chart/fl_category.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A column of an [FlStackedBars]: its short [label] under the bar, and the
/// share of each category in it, in the categories' order.
@immutable
final class FlStackedColumn {
  /// The column [label], made of [values].
  const FlStackedColumn({required this.label, required this.values});

  /// The label under the bar ("W1", "Mon").
  final String label;

  /// One value per category; zero, negative or not finite leaves no
  /// segment.
  final List<double> values;

  double get _total => values.fold(0.0, (sum, v) => sum + (v.isFinite && v > 0 ? v : 0));
}

/// Bars of a period, each a stack of its categories from the baseline, in
/// the fills of [FlCategoryFill], `space.xs` / 2 of surface between two
/// segments. The labels sit under the bars in muted `textXs`, that of
/// [highlight] (the current week, the current day) in `onSurface`. In RTL,
/// the first column is on the right.
///
/// The bars are one image read as [semanticLabel]: the table of the chart
/// gives the same figures to read one by one.
class FlStackedBars extends StatelessWidget {
  /// The bars of [columns].
  const FlStackedBars({super.key, required this.columns, required this.semanticLabel, this.highlight, this.plotHeight});

  /// The columns, in time order.
  final List<FlStackedColumn> columns;

  /// What the screen reader says of the chart.
  final String semanticLabel;

  /// The column whose label stands out; null, none.
  final int? highlight;

  /// The height of the tallest bar; null, three times the control height.
  final double? plotHeight;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final scale = theme.typography;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final plot = plotHeight ?? theme.controlHeight * 3;
    final peak = columns.fold(0.0, (m, c) => math.max(m, c._total));
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: theme.space.sm,
          children: [
            for (final (i, column) in columns.indexed)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.sm,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: theme.space.xxl),
                      child: SizedBox(
                        height: plot,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _StackPainter(
                            values: column.values,
                            height: peak == 0 ? 0 : column._total / peak * plot,
                            colors: theme.colors,
                            gap: theme.space.xs / 2,
                            radius: theme.shape.radiusSm,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      column.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: scale
                          .resolve(FlTextRole.textXs)
                          .copyWith(color: i == highlight ? theme.colors.onSurface : theme.colors.onSurfaceMuted),
                      strutStyle: scale.strut(FlTextRole.textXs, inheritedFamily: family),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  const _StackPainter({
    required this.values,
    required this.height,
    required this.colors,
    required this.gap,
    required this.radius,
  });

  final List<double> values;

  /// The bar's height, all segments together.
  final double height;
  final FlColorTokens colors;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (sum, v) => sum + (v.isFinite && v > 0 ? v : 0));
    if (total == 0 || height <= 0) return;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height - height, size.width, height),
      Radius.circular(math.min(radius, size.width / 2)),
    );
    canvas
      ..save()
      ..clipRRect(bar);
    var bottom = size.height;
    for (final (i, v) in values.indexed) {
      if (!v.isFinite || v <= 0) continue;
      final h = v / total * height;
      final top = bottom - h;
      FlCategoryFill(i).paint(
        canvas,
        RRect.fromRectAndRadius(Rect.fromLTRB(0, top + gap / 2, size.width, bottom - gap / 2), Radius.zero),
        colors,
      );
      bottom = top;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StackPainter old) =>
      old.values != values || old.height != height || old.colors != colors || old.gap != gap || old.radius != radius;
}

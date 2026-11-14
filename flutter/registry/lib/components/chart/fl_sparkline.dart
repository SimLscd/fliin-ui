import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A small line with neither axis nor tooltip: the trend of a price or of
/// a running total, beside the figure it follows. In RTL, the first value
/// is on the right. The screen reader reads [semanticLabel]; null, the line
/// is silent, for a row that already says its figure and its change.
class FlSparkline extends StatelessWidget {
  /// The line of [values].
  const FlSparkline({super.key, required this.values, this.color, this.height, this.width, this.semanticLabel});

  /// The values, in time order; a non-finite one is skipped.
  final List<double> values;

  /// The line's color; null, `onSurfaceMuted`.
  final Color? color;

  /// The height; null, `space.lg`.
  final double? height;

  /// The width; null, the available width.
  final double? width;

  /// What the screen reader says of the trend; null, nothing.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final line = SizedBox(
      width: width ?? double.infinity,
      height: height ?? theme.space.lg,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? theme.colors.onSurfaceMuted,
          stroke: theme.size.border * 1.5,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
    return switch (semanticLabel) {
      final label? => Semantics(image: true, label: label, child: line),
      null => ExcludeSemantics(child: line),
    };
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color, required this.stroke, required this.rtl});

  final List<double> values;
  final Color color;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final finite = values.where((v) => v.isFinite).toList();
    if (finite.length < 2) return;
    final lo = finite.reduce(math.min);
    final hi = finite.reduce(math.max);
    final span = hi - lo;
    final inset = stroke;
    final path = Path();
    var started = false;
    for (final (i, v) in values.indexed) {
      if (!v.isFinite) continue;
      final t = i / (values.length - 1);
      final x = inset + (rtl ? 1 - t : t) * (size.width - inset * 2);
      final y = inset + (span == 0 ? 0.5 : 1 - (v - lo) / span) * (size.height - inset * 2);
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color || old.stroke != stroke || old.rtl != rtl;
}

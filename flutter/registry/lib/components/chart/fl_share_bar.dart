import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/chart/fl_category.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A whole split into its shares on one thin line of pills: one rounded
/// pill per share worth something, in the order of [shares] from the start
/// of the reading direction, each as wide as its weight, a gap of the card
/// between two. With [selected], the chosen share is in `selected` and the
/// others in `selectedSoft`, the list beside the bar saying which; without
/// it, each share takes its [FlCategoryFill], a ramp of the primary color.
/// [remaining], when above zero, ends the line with a `selectedSoft`
/// pill: what is left of a budget. Read as one image, [semanticLabel],
/// which should say the whole and its shares.
class FlShareBar extends StatelessWidget {
  /// The bar of [shares].
  const FlShareBar({
    super.key,
    required this.shares,
    required this.semanticLabel,
    this.selected,
    this.remaining = 0,
    this.height,
  });

  /// The shares, in the order drawn.
  final List<FlShare> shares;

  /// What the screen reader says of the bar.
  final String semanticLabel;

  /// The chosen share, in `selected`; null, the shades of [FlCategoryFill].
  final int? selected;

  /// What is left after the shares, in their unit, drawn as a last pill.
  final double remaining;

  /// The bar's thickness; when null, `space.sm` and a half of `space.xs`.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final thickness = height ?? theme.space.sm + theme.space.xs / 2;
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: thickness,
          width: double.infinity,
          child: CustomPaint(
            painter: _ShareBarPainter(
              weights: [for (final s in shares) s.weight],
              selected: selected,
              remaining: remaining.isFinite && remaining > 0 ? remaining : 0,
              colors: theme.colors,
              gap: theme.space.xs * 0.75,
              direction: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareBarPainter extends CustomPainter {
  const _ShareBarPainter({
    required this.weights,
    required this.selected,
    required this.remaining,
    required this.colors,
    required this.gap,
    required this.direction,
  });

  final List<double> weights;
  final int? selected;
  final double remaining;
  final FlColorTokens colors;
  final double gap;
  final TextDirection direction;

  Color _color(int index) {
    if (index < 0) return colors.selectedSoft;
    return switch (selected) {
      null => FlCategoryFill(index).color(colors),
      final chosen => index == chosen ? colors.selected : colors.selectedSoft,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final round = Radius.circular(size.height / 2);
    final parts = [
      for (final (i, w) in weights.indexed)
        if (w > 0) (i, w),
      if (remaining > 0) (-1, remaining),
    ];
    if (parts.isEmpty) {
      canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, round), Paint()..color = colors.selectedSoft);
      return;
    }
    final available = math.max(0.0, size.width - gap * (parts.length - 1));
    final total = parts.fold(0.0, (sum, p) => sum + p.$2);
    // A share too small to see stays a round dot; the others give up that
    // room in proportion.
    final least = math.min(size.height, available / parts.length);
    final raw = [for (final p in parts) p.$2 / total * available];
    final small = raw.where((w) => w < least).length;
    final large = raw.where((w) => w >= least).fold(0.0, (sum, w) => sum + w);
    final scale = large == 0 ? 0.0 : (available - least * small) / large;
    final rtl = direction == TextDirection.rtl;
    var from = 0.0;
    for (final (k, (index, _)) in parts.indexed) {
      final width = raw[k] < least ? least : raw[k] * scale;
      final rect = rtl
          ? Rect.fromLTWH(size.width - from - width, 0, width, size.height)
          : Rect.fromLTWH(from, 0, width, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, round), Paint()..color = _color(index));
      from += width + gap;
    }
  }

  @override
  bool shouldRepaint(_ShareBarPainter old) =>
      !_sameWeights(old.weights, weights) ||
      old.selected != selected ||
      old.remaining != remaining ||
      old.colors != colors ||
      old.gap != gap ||
      old.direction != direction;

  static bool _sameWeights(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

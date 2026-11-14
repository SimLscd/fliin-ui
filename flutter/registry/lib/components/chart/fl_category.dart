import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The share of `selected` that each category's fill takes over the surface
/// under it, from the first to the sixth: the categories are told apart by
/// lightness alone, never by hue, so that they hold under any theme and for
/// any color vision, in the theme's primary color.
const List<double> _inks = [1, 0.75, 0.56, 0.39, 0.24, 0.14];

/// How a category of a share chart is drawn, by its [index] in the data: the
/// first in solid `selected`, each next one lighter. A chosen category
/// turns solid `selected`. A seventh category and those after it share the
/// last shade: past six, group the small ones into "Other".
@immutable
final class FlCategoryFill {
  /// The fill of category [index], from 0.
  const FlCategoryFill(this.index) : assert(index >= 0, 'a category index from 0');

  /// The number of fills that can be told apart.
  static const int count = 6;

  /// The category's place in the data.
  final int index;

  /// The color that stands for the category: a bar's segment, a legend dot,
  /// a ring's slice.
  Color color(FlColorTokens colors, {bool selected = false}) {
    if (selected) return colors.selected;
    final ink = colors.selected;
    return ink.withValues(alpha: ink.a * _inks[math.min(index, count - 1)]);
  }

  /// Paints the category inside [shape], `selected` when [selected].
  void paint(Canvas canvas, RRect shape, FlColorTokens colors, {bool selected = false}) =>
      canvas.drawRRect(shape, Paint()..color = color(colors, selected: selected));
}

/// A category's dot in a legend, of the size of `space.sm`.
class FlCategoryDot extends StatelessWidget {
  /// The dot of category [index], `selected` when [selected].
  const FlCategoryDot(this.index, {super.key, this.selected = false});

  /// The category's place in the data.
  final int index;

  /// True: the chosen category.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return SizedBox.square(
      dimension: theme.space.sm,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: FlCategoryFill(index).color(theme.colors, selected: selected),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// A share of a whole: a category's [label], its [value] in the app's unit,
/// and [semanticLabel], what the screen reader says of it ("Housing,
/// $1,850, 35%"); when null, [label].
@immutable
final class FlShare {
  /// The share [label] worth [value].
  const FlShare({required this.label, required this.value, this.semanticLabel});

  /// The category's name.
  final String label;

  /// Its weight: an amount, a count. Zero, negative or not finite counts as
  /// zero.
  final double value;

  /// What the screen reader says of the share; when null, [label].
  final String? semanticLabel;

  /// The weight, zero when it cannot be drawn.
  double get weight => value.isFinite && value > 0 ? value : 0;
}

/// The legend of a share chart: one dot and its label per share, wrapped
/// and centered, in muted `textSm`. Hidden from the screen reader: the
/// chart says the same.
class FlCategoryLegend extends StatelessWidget {
  /// The legend of [shares], [selected] marked.
  const FlCategoryLegend({super.key, required this.shares, this.selected, this.alignment = WrapAlignment.center});

  /// The shares, in the chart's order.
  final List<FlShare> shares;

  /// The chosen share; null, none.
  final int? selected;

  /// Where the lines of the legend sit.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final scale = theme.typography;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    return ExcludeSemantics(
      child: Wrap(
        alignment: alignment,
        spacing: theme.space.lg,
        runSpacing: theme.space.sm,
        children: [
          for (final (i, share) in shares.indexed)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.sm,
              children: [
                FlCategoryDot(i, selected: i == selected),
                Flexible(
                  child: Text(
                    share.label,
                    style: scale.resolve(FlTextRole.textSm).copyWith(color: theme.colors.onSurface),
                    strutStyle: scale.strut(FlTextRole.textSm, inheritedFamily: family),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Modified from the Separator of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The thickness of an [FlSeparator].
enum FlSeparatorVariant {
  /// One physical pixel, React Native's `hairlineWidth`.
  thin,

  /// `size.separatorThick`: separates two blocks rather than two rows.
  thick,
}

/// A `separator` line between two pieces of content, horizontal or vertical.
/// It takes the full length its parent offers (nothing when that length is
/// infinite), and snaps to the pixel grid to stay crisp. Purely decorative:
/// screen readers don't see it.
class FlSeparator extends StatelessWidget {
  /// An [axis] separator, thin by default.
  const FlSeparator({
    super.key,
    this.axis = Axis.horizontal,
    this.variant = FlSeparatorVariant.thin,
    this.thickness,
    this.color,
    this.length,
    this.indent = 0,
    this.endIndent = 0,
  }) : assert(length == null || length >= 0, 'length must not be negative'),
       assert(indent >= 0 && endIndent >= 0, 'indents must not be negative');

  /// Horizontal (a line between two rows) or vertical (between two
  /// columns).
  final Axis axis;

  /// Thin or thick.
  final FlSeparatorVariant variant;

  /// A chosen thickness, in logical points, instead of the one from
  /// [variant].
  final double? thickness;

  /// The line's color instead of the variant's: `separatorSecondary` or
  /// `separatorTertiary` on a `secondary` or `tertiary` surface.
  final Color? color;

  /// The line's length; when null, the full length the parent offers. A
  /// vertical separator between two words of a row takes one, the height of
  /// the text, without an `IntrinsicHeight` around the row.
  final double? length;

  /// The space left before the line: at the start of a horizontal
  /// separator, at the top of a vertical one.
  final double indent;

  /// The space left after the line: at the end of a horizontal separator,
  /// at the bottom of a vertical one.
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final extent =
        thickness ??
        switch (variant) {
          FlSeparatorVariant.thin => 1 / MediaQuery.devicePixelRatioOf(context),
          FlSeparatorVariant.thick => theme.size.separatorThick,
        };
    // The canvas's thick rule is a band of `surfaceSecondary`, the thin one
    // a hairline of `separator`.
    final line = ColoredBox(
      color:
          color ??
          (variant == FlSeparatorVariant.thick && thickness == null
              ? theme.colors.surfaceSecondary
              : theme.colors.separator),
    );
    Widget separator = switch (axis) {
      // Nothing along an infinite length, unless a length is given.
      Axis.horizontal => LimitedBox(
        maxWidth: length ?? 0,
        child: SizedBox(
          width: length ?? double.infinity,
          height: extent,
          child: FlPixelSnap(child: line),
        ),
      ),
      Axis.vertical => LimitedBox(
        maxHeight: length ?? 0,
        child: SizedBox(
          width: extent,
          height: length ?? double.infinity,
          child: FlPixelSnap(child: line),
        ),
      ),
    };
    if (indent > 0 || endIndent > 0) {
      separator = Padding(
        padding: switch (axis) {
          Axis.horizontal => EdgeInsetsDirectional.only(start: indent, end: endIndent),
          Axis.vertical => EdgeInsetsDirectional.only(top: indent, bottom: endIndent),
        },
        child: separator,
      );
    }
    return ExcludeSemantics(child: separator);
  }
}

// Modified from the ColorSwatch of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

export 'package:fliin_ui/components/color_swatch/fl_color_channel.dart';

/// The opacity of the 1 rule that outlines a swatch, a track or a color
/// area (`inset 0 0 0 1px rgba(0, 0, 0, 0.1)` of color-swatch.css), in the
/// theme's text color so that a dark tint also stands out from a dark
/// background.
const double flColorEdgeOpacity = 0.1;

/// The size of a swatch: 16, 24, 32, 36 or 40 per side.
enum FlColorSwatchSize {
  /// 16 (`size-4`), ring of 1.
  xs(16, 1),

  /// 24 (`size-6`), ring of 2.
  sm(24, 2),

  /// 32 (`size-8`), ring of 2: the default size.
  md(32, 2),

  /// 36 (`size-9`), ring of 2.
  lg(36, 2),

  /// 40 (`size-10`), ring of 2.
  xl(40, 2);

  const FlColorSwatchSize(this.extent, this.ring);

  /// The side, in logical points.
  final double extent;

  /// The ring thickness of a selected swatch in a picker.
  final double ring;
}

/// The shape of a swatch.
enum FlColorSwatchShape {
  /// A circle. The default.
  circle,

  /// A square with rounded corners (`square`).
  square,
}

/// The outline of a swatch of [shape], [radius] at the corners when square.
ShapeBorder flColorSwatchOutline(FlColorSwatchShape shape, double radius) => switch (shape) {
  FlColorSwatchShape.circle => const CircleBorder(),
  FlColorSwatchShape.square => RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius))),
};

/// A color swatch: the tint [color] over a
/// checkerboard that shows through a translucent color, outlined by an
/// inner rule of 1 in the text color at 10 %, read by the screen reader as
/// an image named [label].
///
/// It is what the color controls show of their value: the picked tint of a
/// `FlColorSwatchPicker`, the prefix of a `FlColorField`, the trigger of a
/// `FlColorPicker`. The color is a value of the app, never a theme color.
class FlColorSwatch extends StatelessWidget {
  /// The swatch [color], named [label].
  const FlColorSwatch({
    super.key,
    required this.color,
    required this.label,
    this.size = FlColorSwatchSize.md,
    this.shape = FlColorSwatchShape.circle,
    this.radius,
    this.edge = true,
  });

  /// The tint shown.
  final Color color;

  /// The tint's name, given by the app ("Midnight blue"); null when the
  /// swatch only illustrates a control that already names the color, and
  /// is then left out of the semantics.
  final String? label;

  /// The side; `md` (32) by default.
  final FlColorSwatchSize size;

  /// Round by default.
  final FlColorSwatchShape shape;

  /// The corners of a square swatch; null, `shape.radiusMd`,
  /// `shape.radiusXs` at `xs`.
  final double? radius;

  /// False: no inner rule, for a tint whose contrast with the background
  /// already outlines it.
  final bool edge;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    // `rounded-md`, kept square at 16, where it would round to a circle.
    final corner = radius ?? (size == FlColorSwatchSize.xs ? theme.shape.radiusXs : theme.shape.radiusMd);
    final outline = flColorSwatchOutline(shape, corner);
    Widget swatch = DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: outline),
      position: DecorationPosition.background,
      child: edge
          ? DecoratedBox(
              decoration: ShapeDecoration(
                shape: flColorEdge(outline, theme.colors.onSurface.withValues(alpha: flColorEdgeOpacity)),
              ),
            )
          : null,
    );
    // An opaque tint hides the checkerboard: none is painted, so that its
    // squares do not tint the antialiased edge.
    if (color.a < 1) swatch = FlColorChecker(shape: outline, child: swatch);
    swatch = SizedBox.square(dimension: size.extent, child: swatch);
    final label = this.label;
    swatch = label == null ? ExcludeSemantics(child: swatch) : Semantics(image: true, label: label, child: swatch);
    return swatch;
  }
}

/// The thumb of a color slider or a color area: a disc of [extent] in the
/// picked [color], ringed by 3 of `switchThumb`, which stays white on both brightnesses so that the
/// thumb stands out from any tint. Lifted by the `overlay` shadow when
/// [lifted], otherwise outlined by a 1 rule in the text color at 10 %
/// inside and out. A translucent color shows the checkerboard.
class FlColorThumb extends StatelessWidget {
  /// A thumb of [extent] in [color].
  const FlColorThumb({super.key, required this.color, required this.extent, this.lifted = true});

  /// The picked color, a value of the app.
  final Color color;

  /// The diameter, ring included.
  final double extent;

  /// True: the `overlay` shadow (the slider's); false: the outline rule
  /// (the area's).
  final bool lifted;

  /// The width of the white ring.
  static const double ring = 3;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    const outline = CircleBorder();
    final edge = theme.colors.onSurface.withValues(alpha: flColorEdgeOpacity);
    Widget inner = DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: outline),
    );
    if (color.a < 1) inner = FlColorChecker(shape: outline, child: inner);
    if (!lifted) {
      inner = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: flColorEdge(outline, edge)),
        child: inner,
      );
    }
    final thumb = SizedBox.square(
      dimension: extent,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.colors.switchThumb,
          shape: lifted
              ? outline
              : CircleBorder(
                  side: BorderSide(color: edge, strokeAlign: BorderSide.strokeAlignOutside),
                ),
        ),
        child: Padding(padding: const EdgeInsetsDirectional.all(ring), child: inner),
      ),
    );
    return lifted ? FlShadow(layers: theme.shadows.overlay, shape: outline, child: thumb) : thumb;
  }
}

/// A stroke of [width] inside the edge of [outline], inward.
ShapeBorder flColorEdge(ShapeBorder outline, Color color, {double width = 1}) {
  final side = BorderSide(color: color, width: width, strokeAlign: BorderSide.strokeAlignInside);
  return switch (outline) {
    final RoundedRectangleBorder rect => rect.copyWith(side: side),
    final StadiumBorder _ => StadiumBorder(side: side),
    _ => CircleBorder(side: side),
  };
}

/// The checkerboard behind a translucent color: squares of 8 in `surface` and `surfaceSecondary`, clipped to [shape],
/// painted under [child]. An opaque color hides it entirely.
class FlColorChecker extends StatelessWidget {
  /// A checkerboard clipped to [shape], under [child].
  const FlColorChecker({super.key, required this.shape, required this.child});

  /// The outline that clips the checkerboard.
  final ShapeBorder shape;

  /// The color laid over it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FlScope.of(context).colors;
    return CustomPaint(
      painter: _CheckerPainter(
        shape: shape,
        light: colors.surface,
        dark: colors.surfaceSecondary,
        textDirection: Directionality.maybeOf(context),
        cell: FlScope.of(context).space.sm,
      ),
      child: child,
    );
  }
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({
    required this.shape,
    required this.light,
    required this.dark,
    required this.textDirection,
    required this.cell,
  });

  final ShapeBorder shape;
  final Color light;
  final Color dark;
  final TextDirection? textDirection;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..save()
      ..clipPath(shape.getOuterPath(rect, textDirection: textDirection))
      ..drawRect(rect, Paint()..color = light);
    final paint = Paint()..color = dark;
    // `50%`: the pattern is centered on the box.
    final origin = size.center(Offset.zero) - Offset(cell, cell);
    final startX = origin.dx - (origin.dx / cell).ceil() * cell;
    final startY = origin.dy - (origin.dy / cell).ceil() * cell;
    var row = 0;
    for (var y = startY; y < size.height; y += cell, row++) {
      var column = 0;
      for (var x = startX; x < size.width; x += cell, column++) {
        if ((row + column).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) =>
      shape != oldDelegate.shape ||
      light != oldDelegate.light ||
      dark != oldDelegate.dark ||
      textDirection != oldDelegate.textDirection ||
      cell != oldDelegate.cell;
}

// Modified from the Surface of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The fill of an [FlSurface].
enum FlSurfaceVariant {
  /// `surfaceRaised`, with the `surface` shadow: a card resting on the page.
  primary,

  /// `surfaceSecondary` and the shadow: a recessed block.
  secondary,

  /// `surfaceTertiary` and the shadow: the most recessed.
  tertiary,

  /// No fill or shadow: keeps only the shape and the padding.
  transparent,
}

/// The container that holds cards, row groups and alerts: a fill, the
/// tokens' `surface` shadow, continuous corners of radius `shape.radiusCard`
/// that clip [child], `size.surfacePadding` padding, and a `border` stroke
/// of `size.surfaceBorder` when that token is not zero.
///
/// [radius], [color], [gradient] and [outlined] adjust one surface without
/// touching the theme: a billing panel tinted with the accent, a transparent
/// block drawn by its outline.
class FlSurface extends StatelessWidget {
  /// A surface around [child], `primary` by default.
  const FlSurface({
    super.key,
    this.variant = FlSurfaceVariant.primary,
    this.padding,
    this.radius,
    this.color,
    this.gradient,
    this.outlined = false,
    required this.child,
  }) : assert(radius == null || radius >= 0, 'radius must not be negative');

  /// The fill and the shadow.
  final FlSurfaceVariant variant;

  /// The padding around [child]; when null, `size.surfacePadding` on each
  /// side.
  final EdgeInsetsGeometry? padding;

  /// The radius of the continuous corners; when null, `shape.radiusCard`.
  final double? radius;

  /// The fill instead of that of [variant]; the shadow stays that of the
  /// variant.
  final Color? color;

  /// A gradient painted over the fill, clipped to the shape: from a tint of
  /// the accent to the surface, say.
  final Gradient? gradient;

  /// True: a `border` stroke of `size.border` around the surface, whatever
  /// the variant and the `size.surfaceBorder` token; a transparent surface
  /// then reads as an outlined block.
  final bool outlined;

  /// The content, clipped to the surface's shape.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final fill =
        color ??
        switch (variant) {
          FlSurfaceVariant.primary => colors.surfaceRaised,
          FlSurfaceVariant.secondary => colors.surfaceSecondary,
          FlSurfaceVariant.tertiary => colors.surfaceTertiary,
          FlSurfaceVariant.transparent => null,
        };
    final cornerRadius = radius ?? theme.shape.radiusCard;
    final shape = FlContinuousBorder(radius: cornerRadius);
    final gradient = this.gradient;
    final padded = Padding(padding: padding ?? EdgeInsets.all(theme.size.surfacePadding), child: child);
    final stroke = outlined
        ? BorderSide(color: colors.border, width: theme.size.border)
        : fill == null || theme.size.surfaceBorder == 0
        ? BorderSide.none
        : BorderSide(color: colors.border, width: theme.size.surfaceBorder);
    return FlPixelSnap(
      child: FlShadow(
        layers: variant == FlSurfaceVariant.transparent ? const [] : theme.shadows.surface,
        // React Native shadows a view from its circular corners, even when
        // continuous: between the two curves, the page background shows through.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cornerRadius)),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape, textDirection: Directionality.maybeOf(context)),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: fill, shape: shape),
            // The stroke is laid over the content: a list row without
            // padding would cover it otherwise.
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: FlContinuousBorder(radius: cornerRadius, side: stroke),
              ),
              child: gradient == null
                  ? padded
                  : DecoratedBox(
                      // Clipped by the shape above: a rectangle is enough.
                      decoration: BoxDecoration(gradient: gradient),
                      child: padded,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

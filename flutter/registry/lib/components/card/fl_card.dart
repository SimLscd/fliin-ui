// Modified from the Card of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A card: a [FlSurface] whose [children] follow one
/// another in a column, [spacing] apart, stretched to its width. Place
/// [FlCardHeader], [FlCardBody] and [FlCardFooter] in it, or any other
/// content.
///
/// A [media], most often a [FlCardMedia], comes before the content: above it,
/// or at its start when [axis] is horizontal. A [background] fills the whole
/// card behind the content, and a [trailing] widget, a close button for
/// instance, sits in the top end corner.
class FlCard extends StatelessWidget {
  /// A `primary` card around [children].
  const FlCard({
    super.key,
    this.variant = FlSurfaceVariant.primary,
    this.padding,
    this.axis = Axis.vertical,
    this.spacing,
    this.media,
    this.background,
    this.trailing,
    required this.children,
  });

  /// The surface's background and shadow.
  final FlSurfaceVariant variant;

  /// The space between the card's edge and its content; when null,
  /// `size.surfacePadding` on each side. A [FlCardMedia] with `bleed` ignores
  /// it.
  final EdgeInsetsGeometry? padding;

  /// Where [media] goes: above the content when vertical, at its start, the
  /// content taking the rest of the width, when horizontal.
  final Axis axis;

  /// The gap between two [children], and between [media] and the content;
  /// when null, `space.md`.
  final double? spacing;

  /// An image or an illustration before the content, most often a
  /// [FlCardMedia].
  final Widget? media;

  /// A widget that fills the whole card behind the content, clipped to its
  /// shape: a photo, a gradient. The content keeps its padding over it.
  final Widget? background;

  /// A widget in the top end corner, `space.md` from both edges, over the
  /// content: a close button, a menu button. The first child keeps clear of
  /// a `size.closeButton` wide button at its end.
  final Widget? trailing;

  /// The content, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final inset = (padding ?? EdgeInsets.all(theme.size.surfacePadding)).resolve(direction);
    final gap = spacing ?? theme.space.md;
    final media = this.media;
    final trailing = this.trailing;
    final bleed = media is FlCardMedia && media.bleed;
    assert(
      media is! FlCardMedia || !media.bleed || axis == Axis.vertical || media.width != null,
      'A FlCardMedia with bleed in a horizontal card needs a width.',
    );
    // Above a top media, the corner widget sits over the image, not by the
    // first child.
    final reserve = trailing != null && (media == null || axis == Axis.horizontal)
        ? math.max(
            0.0,
            theme.space.md +
                theme.size.closeButton +
                theme.space.xs -
                (direction == TextDirection.ltr ? inset.right : inset.left),
          )
        : 0.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (final (index, child) in children.indexed)
          if (index == 0 && reserve > 0)
            Padding(
              padding: EdgeInsetsDirectional.only(end: reserve),
              child: child,
            )
          else
            child,
      ],
    );
    final Widget body = switch ((media, axis)) {
      (null, _) => Padding(padding: inset, child: content),
      (final media?, Axis.vertical) when bleed => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          media,
          Padding(padding: inset, child: content),
        ],
      ),
      (final media?, Axis.vertical) => Padding(
        padding: inset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [media, content],
        ),
      ),
      (final FlCardMedia media, Axis.horizontal) when bleed => Stack(
        children: [
          PositionedDirectional(start: 0, top: 0, bottom: 0, width: media.width, child: media),
          Padding(
            padding: EdgeInsetsDirectional.only(start: media.width ?? 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: media.height ?? 0),
              child: Padding(padding: inset, child: content),
            ),
          ),
        ],
      ),
      (final media?, Axis.horizontal) => Padding(
        padding: inset,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: [
            media,
            Expanded(child: content),
          ],
        ),
      ),
    };
    final background = this.background;
    return FlSurface(
      variant: variant,
      padding: EdgeInsets.zero,
      child: background == null && trailing == null
          ? body
          : Stack(
              children: [
                if (background != null) Positioned.fill(child: background),
                body,
                if (trailing != null) PositionedDirectional(top: theme.space.md, end: theme.space.md, child: trailing),
              ],
            ),
    );
  }
}

/// An image in a [FlCard]: [child], usually an `Image` with `BoxFit.cover`,
/// sized by [width], [height] or [aspectRatio] and clipped to corners of
/// `shape.radiusXxl`.
///
/// Given as the card's `media`, it sits above the content, or at its start
/// in a horizontal card; with [bleed], it reaches the card's edges instead,
/// the card's corners clipping it. Among the card's children, it keeps its
/// [width] at the start of the line.
class FlCardMedia extends StatelessWidget {
  /// An image of [child], rounded, inside the card's padding.
  const FlCardMedia({super.key, this.width, this.height, this.aspectRatio, this.bleed = false, required this.child})
    : assert(width == null || width >= 0, 'width must not be negative'),
      assert(height == null || height >= 0, 'height must not be negative');

  /// The width; when null, that of the card's content, or the full width of
  /// the card for a top media with [bleed]. A horizontal card needs it.
  final double? width;

  /// The height; when null, from [aspectRatio], or [child]'s own. In a
  /// horizontal card with [bleed], the card's smallest height.
  final double? height;

  /// The width divided by the height, used when [height] is null.
  final double? aspectRatio;

  /// True: the image reaches the card's edges, without padding or corners
  /// of its own: on top of a vertical card, at the start of a horizontal one.
  final bool bleed;

  /// The image.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = this.aspectRatio;
    Widget image = SizedBox(
      width: width,
      height: height,
      child: height == null && aspectRatio != null ? AspectRatio(aspectRatio: aspectRatio, child: child) : child,
    );
    if (bleed) return image;
    image = ClipPath(
      clipper: ShapeBorderClipper(
        shape: FlContinuousBorder(radius: FlScope.of(context).shape.radiusXxl),
        textDirection: Directionality.maybeOf(context),
      ),
      child: image,
    );
    return width == null
        ? image
        : Align(alignment: AlignmentDirectional.topStart, widthFactor: 1, heightFactor: 1, child: image);
  }
}

/// The header of a card: icons and badges placed at the start of the line,
/// at their size.
class FlCardHeader extends StatelessWidget {
  /// A header that stacks [children].
  const FlCardHeader({super.key, this.spacing = 0, required this.children});

  /// The gap between two children.
  final double spacing;

  /// The content, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: spacing,
    children: children,
  );
}

/// The body of a card: title, description and main content, stretched to
/// its width.
class FlCardBody extends StatelessWidget {
  /// A body that stacks [children].
  const FlCardBody({super.key, this.spacing = 0, required this.children});

  /// The gap between two children; none by default.
  final double spacing;

  /// The content, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: spacing,
    children: children,
  );
}

/// The footer of a card: its actions, in a stretched column, or in a row in
/// reading order when [axis] is horizontal, by default the first at the
/// start, the last at the end, the others spread evenly between them. A row
/// that does not fit wraps onto the next line instead of overflowing.
class FlCardFooter extends StatelessWidget {
  /// A footer that stacks [children], or lines them up along [axis].
  const FlCardFooter({
    super.key,
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.alignment = WrapAlignment.spaceBetween,
    required this.children,
  });

  /// Vertical by default, like a React Native view; horizontal for a row of
  /// buttons.
  final Axis axis;

  /// The smallest gap between two children, and between two lines of a
  /// horizontal footer that wraps.
  final double spacing;

  /// Where a horizontal footer puts its children along the line:
  /// `WrapAlignment.start` keeps them together at the start (an avatar and a
  /// name, a link).
  final WrapAlignment alignment;

  /// The content.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => switch (axis) {
    Axis.vertical => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing,
      children: children,
    ),
    Axis.horizontal => Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: children,
    ),
  };
}

/// The title of a card: medium-weight `textLg`, `onSurface`.
class FlCardTitle extends StatelessWidget {
  /// The title [data].
  const FlCardTitle(this.data, {super.key});

  /// The text.
  final String data;

  @override
  Widget build(BuildContext context) => _text(context, data, FlTextRole.textLg, muted: false, heading: true);
}

/// The description of a card: `textBase`, `onSurfaceMuted`.
class FlCardDescription extends StatelessWidget {
  /// The description [data].
  const FlCardDescription(this.data, {super.key});

  /// The text.
  final String data;

  @override
  Widget build(BuildContext context) => _text(context, data, FlTextRole.textBase, muted: true);
}

Text _text(BuildContext context, String data, FlTextRole role, {required bool muted, bool? heading}) {
  final theme = FlScope.of(context);
  final scale = theme.typography;
  return Text(
    data,
    textAlign: TextAlign.start,
    style: scale
        .resolve(role, heading: heading)
        .copyWith(
          color: muted ? theme.colors.onSurfaceMuted : theme.colors.onSurface,
          fontWeight: muted ? null : theme.tokens.typography.weight.medium,
        ),
    strutStyle: scale.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily, heading: heading),
  );
}

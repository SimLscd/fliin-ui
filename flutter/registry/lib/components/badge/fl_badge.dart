// Modified from the Badge of HeroUI React v3, Copyright 2020 Next UI Inc.,
// licensed under the MIT license below and under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// Also modified from the theme colors of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0.
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The color of a [FlBadge].
enum FlBadgeColor {
  /// The highlighted color: solid, `selected` with
  /// `onSelected` text (the accent is reserved for the primary action);
  /// otherwise `onAccentSoft`, on `control` or `accentSoft`.
  accent,

  /// The neutral.
  neutral,

  /// Green.
  success,

  /// Orange.
  warning,

  /// Red.
  danger,
}

/// The fill of a [FlBadge].
enum FlBadgeVariant {
  /// The solid background of the color, its foreground text.
  primary,

  /// The `control` background, the color's soft text.
  secondary,

  /// The color's soft tint, its soft text.
  soft,
}

/// The size of a [FlBadge]: its minimum side and its text.
enum FlBadgeSize {
  /// At least 16 per side, 10 text.
  sm,

  /// At least 20 per side, `textXs` text.
  md,

  /// At least 32 per side, `textSm` text.
  lg,
}

/// The corner of the child on which a [FlBadge] sits, overflowing by a
/// quarter of its size. Start and end follow the reading direction.
enum FlBadgePlacement {
  /// Top, at the end (top right in LTR).
  topEnd,

  /// Top, at the start.
  topStart,

  /// Bottom, at the end.
  bottomEnd,

  /// Bottom, at the start.
  bottomStart,
}

/// `text-[10px]` of `.badge--sm`: no role of the scale has this size.
const double _smText = 10;

/// SF's tracking at 10 points, read from its `trak` table (24/2048 em): the
/// Core Text system font applies it, Skia does not.
const double _smTracking = 24 / 2048 * _smText;

/// `leading-[1.34]` (sm, md) and `leading-[1.43]` (lg) of `.badge`.
const double _leading = 1.34;
const double _leadingLg = 1.43;

/// `translate(±25%, ±25%)` of `.badge--top-right` and the other corners; a
/// dot sits on the corner itself (the canvas's `.badge-dot`).
const double _overhang = 0.25;
const double _dotOverhang = 0.5;

/// A badge placed on the corner of [child]: a
/// count, a short word, an icon or a plain dot, circled by a ring of
/// [ringColor] that separates it from what it overlaps. It does not change
/// the layout of [child], and its text does not grow beyond
/// `size.iconMaxScale`.
///
/// The screen reader announces it with [child], as a single node
/// ("Messages", then "3 unread"): [child] and its badge are merged, so
/// [child] must be a single element.
///
/// A count that changes rolls its digits to the new value; with `hideZero`,
/// the badge pops in when the count leaves zero and pops out when it returns
/// to it (`FlPop`). Under reduced motion, it changes at once or fades.
///
/// Without [child], the badge stands alone, in its place in the row (the
/// unread count at the end of a row, next to the time): no corner, no
/// overflow, and its label joins the node that contains it.
class FlBadge extends StatelessWidget {
  /// A count: beyond `max`, `<max>+`. At zero, the badge stays, unless
  /// `hideZero` is set. When [semanticLabel] is null: the displayed text.
  const FlBadge.count({
    super.key,
    this.child,
    required int this._count,
    this._max = 99,
    this._hideZero = false,
    this.semanticLabel,
    this.color = FlBadgeColor.neutral,
    this.variant = FlBadgeVariant.primary,
    this.size = FlBadgeSize.md,
    this.placement = FlBadgePlacement.topEnd,
    this.ringColor,
  }) : assert(_count >= 0, 'a count is not negative'),
       assert(_max > 0, 'the cap is positive'),
       _text = null,
       _icon = null;

  /// A short word ("New"). When [semanticLabel] is null: that word.
  const FlBadge.text({
    super.key,
    this.child,
    required String this._text,
    this.semanticLabel,
    this.color = FlBadgeColor.neutral,
    this.variant = FlBadgeVariant.primary,
    this.size = FlBadgeSize.md,
    this.placement = FlBadgePlacement.topEnd,
    this.ringColor,
  }) : _count = null,
       _max = 0,
       _hideZero = false,
       _icon = null;

  /// An icon at the size and color of the text, named by [semanticLabel].
  const FlBadge.icon({
    super.key,
    this.child,
    required Widget this._icon,
    required String this.semanticLabel,
    this.color = FlBadgeColor.neutral,
    this.variant = FlBadgeVariant.primary,
    this.size = FlBadgeSize.md,
    this.placement = FlBadgePlacement.topEnd,
    this.ringColor,
  }) : _count = null,
       _max = 0,
       _hideZero = false,
       _text = null;

  /// A dot with no content (online, new), named by [semanticLabel]; `sm` by
  /// default.
  const FlBadge.dot({
    super.key,
    this.child,
    required String this.semanticLabel,
    this.color = FlBadgeColor.neutral,
    this.variant = FlBadgeVariant.primary,
    this.size = FlBadgeSize.sm,
    this.placement = FlBadgePlacement.topEnd,
    this.ringColor,
  }) : _count = null,
       _max = 0,
       _hideZero = false,
       _text = null,
       _icon = null;

  /// What the badge marks: an icon, an avatar, a tab; when null, the badge
  /// alone.
  final Widget? child;

  /// What the screen reader reads after [child] ("3 unread").
  final String? semanticLabel;

  /// The color; the neutral by default.
  final FlBadgeColor color;

  /// The fill.
  final FlBadgeVariant variant;

  /// The size; `md` by default.
  final FlBadgeSize size;

  /// The corner; top end by default.
  final FlBadgePlacement placement;

  /// The ring's color: that of the background under [child]. When null:
  /// `surface`, the page background.
  final Color? ringColor;

  final int? _count;
  final int _max;
  final bool _hideZero;
  final String? _text;
  final Widget? _icon;

  /// The displayed text: the capped count or the word; null for an icon or
  /// a dot.
  String? get _shown => switch (_count) {
    final count? => count > _max ? '$_max+' : '$count',
    null => _text,
  };

  bool get _hidden => _hideZero && _count == 0;

  @override
  Widget build(BuildContext context) {
    final hidden = _hidden;
    final label = hidden ? null : semanticLabel ?? _shown;
    final child = this.child;
    // A count that leaves zero pops in, and pops out when it returns to it.
    if (child == null) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(
          child: FlPop(shown: !hidden, child: _pastille(context)),
        ),
      );
    }
    return MergeSemantics(
      child: Stack(
        // The child keeps the parent's constraints: the badge does not change
        // its layout.
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: placement.top ? 0 : null,
            bottom: placement.top ? null : 0,
            start: placement.start ? 0 : null,
            end: placement.start ? null : 0,
            child: _overhanging(
              context,
              ExcludeSemantics(
                child: FlPop(shown: !hidden, child: _pastille(context)),
              ),
            ),
          ),
          if (label != null) Semantics(label: label),
        ],
      ),
    );
  }

  bool get _dot => _count == null && _text == null && _icon == null;

  /// The quarter of the badge that overflows its corner, on the corner's
  /// side; half of a dot.
  Widget _overhanging(BuildContext context, Widget child) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final overhang = _dot ? _dotOverhang : _overhang;
    final outward = placement.start != rtl ? -overhang : overhang;
    return FractionalTranslation(translation: Offset(outward, placement.top ? -overhang : overhang), child: child);
  }

  Widget _pastille(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final scale = theme.typography;
    final (fill, ink) = switch ((variant, color)) {
      (FlBadgeVariant.primary, FlBadgeColor.accent) => (colors.selected, colors.onSelected),
      (FlBadgeVariant.primary, FlBadgeColor.neutral) => (colors.control, colors.onControl),
      (FlBadgeVariant.primary, FlBadgeColor.success) => (colors.success, colors.onSuccess),
      (FlBadgeVariant.primary, FlBadgeColor.warning) => (colors.warning, colors.onWarning),
      (FlBadgeVariant.primary, FlBadgeColor.danger) => (colors.dangerFill, colors.onDanger),
      (FlBadgeVariant.secondary, FlBadgeColor.accent) => (colors.control, colors.onAccentSoft),
      (FlBadgeVariant.secondary, FlBadgeColor.neutral) => (colors.control, colors.onControl),
      (FlBadgeVariant.secondary, FlBadgeColor.success) => (colors.control, colors.onSuccessSoft),
      (FlBadgeVariant.secondary, FlBadgeColor.warning) => (colors.control, colors.onWarningSoft),
      // `danger` holds 4.5:1 on `control`; `onDangerSoft` is darker only
      // for the soft tint.
      (FlBadgeVariant.secondary, FlBadgeColor.danger) => (colors.control, colors.danger),
      (FlBadgeVariant.soft, FlBadgeColor.accent) => (colors.accentSoft, colors.onAccentSoft),
      (FlBadgeVariant.soft, FlBadgeColor.neutral) => (colors.controlPressed, colors.onControl),
      (FlBadgeVariant.soft, FlBadgeColor.success) => (colors.successSoft, colors.onSuccessSoft),
      (FlBadgeVariant.soft, FlBadgeColor.warning) => (colors.warningSoft, colors.onWarningSoft),
      (FlBadgeVariant.soft, FlBadgeColor.danger) => (colors.dangerSoft, colors.onDangerSoft),
    };
    // The canvas's `.badge`: 16 high with a padding of 4 and 10 text, 20
    // with 5 and `textXs`, 32 with 8 and `textSm`; a dot of 12, 16 or 24.
    final xs = theme.space.xs;
    final (side, padding, radius, role) = switch (size) {
      FlBadgeSize.sm => (xs * 4, xs, theme.shape.radiusXl, FlTextRole.textXs),
      FlBadgeSize.md => (xs * 5, xs * 1.25, theme.shape.radiusCard, FlTextRole.textXs),
      FlBadgeSize.lg => (xs * 8, xs * 2, theme.shape.radiusXxl, FlTextRole.textSm),
    };
    final extent = _dot ? side * 3 / 4 : side;
    final base = scale.style(role);
    final systemFont = scale.familyOf(role) == null;
    final fontSize = size == FlBadgeSize.sm ? _smText : base.size;
    final style = scale
        .resolve(role)
        .copyWith(
          color: ink,
          fontSize: fontSize,
          fontWeight: theme.tokens.typography.weight.medium,
          letterSpacing: size == FlBadgeSize.sm && systemFont && theme.platform == TargetPlatform.iOS
              ? _smTracking
              : null,
          fontVariations: systemFont ? [FontVariation.opticalSize(fontSize)] : null,
        );
    final strut = StrutStyle(
      fontFamily: scale.familyOf(role) ?? DefaultTextStyle.of(context).style.fontFamily,
      fontSize: fontSize,
      height: size == FlBadgeSize.lg ? _leadingLg : _leading,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: theme.tokens.typography.weight.medium,
    );
    final text = _shown;
    final icon = _icon;
    final content = icon != null
        ? IconTheme.merge(
            data: IconThemeData(color: ink, size: fontSize),
            child: icon,
          )
        : text != null
        ? Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: padding),
            // A count rolls its digits to the new value.
            child: _count == null
                ? Text(text, maxLines: 1, softWrap: false, style: style, strutStyle: strut)
                : FlRollingText(text, maxLines: 1, softWrap: false, style: style, strutStyle: strut),
          )
        : null;
    // box-shadow: 0 0 0 2px var(--surface): outside the badge.
    final ring = theme.size.border * 2;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: theme.size.iconMaxScale,
      child: FlPixelSnap(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: extent, minHeight: extent),
          child: CustomPaint(
            painter: _Pastille(
              fill: fill,
              // Alone, it overlaps nothing: no ring, which would leave a
              // fringe on a pressed row or a card.
              ring: child == null ? null : ringColor ?? colors.surface,
              ringWidth: ring,
              radius: radius,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

extension on FlBadgePlacement {
  bool get top => this == FlBadgePlacement.topEnd || this == FlBadgePlacement.topStart;

  bool get start => this == FlBadgePlacement.topStart || this == FlBadgePlacement.bottomStart;
}

/// The ring, outside the badge like a `box-shadow` spread, then the
/// background over it; both are drawn as paths.
class _Pastille extends CustomPainter {
  _Pastille({required this.fill, required this.ring, required this.ringWidth, required this.radius});

  final Color fill;
  final Color? ring;
  final double ringWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).scaleRadii();
    if (ring case final ring?) {
      canvas.drawPath(Path()..addRRect(body.inflate(ringWidth)), Paint()..color = ring);
    }
    canvas.drawPath(Path()..addRRect(body), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_Pastille old) =>
      old.fill != fill || old.ring != ring || old.ringWidth != ringWidth || old.radius != radius;
}

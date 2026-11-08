// Modified from the Button of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The visual emphasis of an [FlButton]. The accent is reserved for a single
/// primary action per view: everything else is told apart by grays.
enum FlButtonVariant {
  /// `accent` fill, `onAccent` text, flat: the primary action of the
  /// screen, one per view.
  primary,

  /// `control` background, `onAccentSoft` text: a highlighted secondary
  /// action.
  secondary,

  /// `control` background, `onControl` text: a neutral secondary action.
  tertiary,

  /// No fill, a hairline in `border`,
  /// `onControl` text.
  outline,

  /// No background or border, `onControl` text: a subtle action.
  ghost,

  /// `dangerFill` fill, `onDanger` text, flat: a destructive action, never
  /// next to the primary action.
  danger,

  /// Translucent `dangerSoft` background, `onDangerSoft` text: a subtle
  /// destructive action.
  dangerSoft,

  /// `selected` fill, `onSelected` text: the inverted action of a screen
  /// that keeps the accent off, like an onboarding's.
  inverse,
}

/// The press feedback of a [FlButton].
enum FlButtonFeedback {
  /// The button shrinks and dims.
  scaleHighlight,

  /// The button shrinks, and a ripple starts from the touched point.
  scaleRipple,

  /// The button shrinks, without dimming.
  scale,

  /// Neither scale nor dimming: only the screen reader and focus convey the press.
  none;

  bool get _scales => this != none;

  FlPressOverlay get _overlay => switch (this) {
    scaleHighlight => FlPressOverlay.highlight,
    scaleRipple => FlPressOverlay.ripple,
    scale || none => FlPressOverlay.none,
  };
}

/// The size of an [FlButton]: 44, 48 or 56 points high with the default
/// tokens, the control heights of the three densities.
enum FlButtonSize {
  /// Height `size.controlCompact`, label `controlSm`.
  sm,

  /// Height `size.controlComfortable`, label `controlMd`.
  md,

  /// Height `size.controlSpacious`, label `controlLg`.
  lg;

  /// The size that follows the theme's density: compact, comfortable or spacious.
  static FlButtonSize of(FlDensity density) => switch (density) {
    FlDensity.compact => sm,
    FlDensity.comfortable => md,
    FlDensity.spacious => lg,
  };
}

typedef _Metrics = ({double height, double padding, double gap, double icon, FlTextRole text, double radius});

typedef _Paint = ({Color? fill, Color? border, Color foreground, Color highlight});

/// An action button: [label] between optional [leading] and
/// [trailing] icons, or an icon alone through [FlButton.icon]. It shrinks
/// and dims when pressed, and turns half opaque when disabled.
class FlButton extends StatelessWidget {
  /// Creates a labeled button, with the `primary` variant by default.
  const FlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FlButtonVariant.primary,
    this.size,
    this.loading = false,
    this.leading,
    this.trailing,
    this.feedback = FlButtonFeedback.scaleHighlight,
    this.statesController,
    this.selected,
    this.fullWidth = false,
  }) : icon = null,
       extent = null;

  /// Creates a square button that shows only [icon]; [label] remains what
  /// the screen reader reads.
  const FlButton.icon({
    super.key,
    required this.label,
    required Widget this.icon,
    required this.onPressed,
    this.variant = FlButtonVariant.primary,
    this.size,
    this.loading = false,
    this.feedback = FlButtonFeedback.scaleHighlight,
    this.statesController,
    this.extent,
    this.selected,
  }) : leading = null,
       trailing = null,
       fullWidth = false;

  /// The displayed text, read as is by the screen reader in place of the
  /// whole content of the button.
  final String label;

  /// Called when the button is pressed. When null: the button goes to
  /// `size.disabledOpacity` and announces itself disabled.
  final VoidCallback? onPressed;

  /// The background, the border and the text color; `primary` by default.
  final FlButtonVariant variant;

  /// The height, the padding and the text size. When null, it follows the
  /// theme's density: `md` on mobile.
  final FlButtonSize? size;

  /// True: a `FlSpinner` in the text color replaces [leading] (at the icon's
  /// size) or [icon] (at size `md`), and the button
  /// ignores presses without changing appearance. The indicator is still
  /// under reduced motion.
  final bool loading;

  /// An icon before the text, in the text's tint and size, capped by
  /// `size.iconMaxScale`. Hidden during [loading].
  final Widget? leading;

  /// An icon after the text, in the text's tint and size.
  final Widget? trailing;

  /// The icon of a [FlButton.icon] button, alone in a square.
  final Widget? icon;

  /// The side of a [FlButton.icon]'s square, in logical points; when null,
  /// the height of [size] (the close button takes a smaller one).
  final double? extent;

  /// The press feedback: scale and dimming by default.
  final FlButtonFeedback feedback;

  /// The button's states, which the app can read or force; see
  /// `FlPressable.statesController`.
  final WidgetStatesController? statesController;

  /// Selected or not, for a toggle button (a favorite, an editor's bold);
  /// null for an action button. [label] stays the same, selected or not: a
  /// favorite is named "Favorite". The node carries `selected`: iOS sets
  /// the "selected" trait when it is true, Android `setSelected`, and the
  /// off state is announced nowhere; so the screen should announce the
  /// change (`SemanticsService.sendAnnouncement`). Selected, a `tertiary`
  /// button takes the `selected` fill and `onSelected` text, like every
  /// chosen state; a `secondary`, `outline` or `ghost` one the `accentSoft`
  /// fill. Color is not enough to convey the state: the app changes [icon]
  /// or [leading] with it.
  ///
  /// ```dart
  /// FlButton.icon(label: 'Favorite', selected: favorite, variant: FlButtonVariant.secondary,
  ///     icon: favorite ? heartFilled : heartOutline, onPressed: toggleFavorite)
  /// FlButton.icon(label: 'Bold', selected: bold,
  ///     variant: bold ? FlButtonVariant.secondary : FlButtonVariant.ghost, icon: boldIcon, onPressed: toggleBold)
  /// ```
  final bool? selected;

  /// True: the button takes the full width it is given, its content
  /// centered; under an unbounded width (in a `Row`),
  /// it keeps its natural width. False by default: as wide as its content.
  /// A [FlButton.icon] stays square.
  final bool fullWidth;

  _Metrics _metrics(FlTheme theme, FlButtonSize size) {
    final s = theme.size;
    return switch (size) {
      FlButtonSize.sm => (
        height: s.controlCompact,
        padding: s.buttonPaddingSm,
        gap: s.buttonGapSm,
        icon: s.buttonIconSm,
        text: FlTextRole.controlSm,
        radius: theme.shape.radiusButton,
      ),
      FlButtonSize.md => (
        height: s.controlComfortable,
        padding: s.buttonPaddingMd,
        gap: s.buttonGapMd,
        icon: s.buttonIconMd,
        text: FlTextRole.controlMd,
        radius: theme.shape.radiusButton,
      ),
      FlButtonSize.lg => (
        height: s.controlSpacious,
        padding: s.buttonPaddingLg,
        gap: s.buttonGapLg,
        icon: s.buttonIconLg,
        text: FlTextRole.controlLg,
        radius: theme.shape.radiusButtonLarge,
      ),
    };
  }

  /// The colors of each variant and the press veil. No variant carries a
  /// halo: the buttons are flat, and a colored glow would blur into the focus ring and linger on a disabled button.
  _Paint _paint(FlTheme theme) {
    final c = theme.colors;
    final subtle = c.controlPressed.withValues(alpha: theme.size.pressedOverlayOpacity);
    // Selected, a tertiary toggle turns `selected` like the canvas's state
    // matrix; the other neutral variants take the `accentSoft` fill (the
    // canvas's favorite); the filled and destructive variants keep theirs.
    if (variant == FlButtonVariant.tertiary && selected == true) {
      return (
        fill: c.selected,
        border: null,
        foreground: c.onSelected,
        highlight: Color.alphaBlend(c.onSelected.withValues(alpha: theme.size.pressedOverlayOpacity), c.selected),
      );
    }
    if (variant case FlButtonVariant.secondary || FlButtonVariant.outline || FlButtonVariant.ghost
        when selected == true) {
      return (
        fill: c.accentSoft,
        border: variant == FlButtonVariant.outline ? c.border : null,
        foreground: c.onAccentSoft,
        highlight: c.accentSoftPressed,
      );
    }
    return switch (variant) {
      FlButtonVariant.primary => (fill: c.accent, border: null, foreground: c.onAccent, highlight: c.accentPressed),
      FlButtonVariant.secondary => (
        fill: c.control,
        border: null,
        foreground: c.onAccentSoft,
        highlight: c.controlPressed,
      ),
      FlButtonVariant.tertiary => (fill: c.control, border: null, foreground: c.onControl, highlight: c.controlPressed),
      FlButtonVariant.outline => (fill: null, border: c.border, foreground: c.onControl, highlight: subtle),
      FlButtonVariant.ghost => (fill: null, border: null, foreground: c.onControl, highlight: subtle),
      FlButtonVariant.danger => (fill: c.dangerFill, border: null, foreground: c.onDanger, highlight: c.dangerPressed),
      FlButtonVariant.dangerSoft => (
        fill: c.dangerSoft,
        border: null,
        foreground: c.onDangerSoft,
        // Over the fill, the veil that brings it to `dangerSoftPressed`
        // rather than stacking both tints.
        highlight: _veilOver(c.dangerSoft, c.dangerSoftPressed),
      ),
      // No token darkens `selected`: pressed, an `onSelected` veil, like the
      // chosen segment's.
      FlButtonVariant.inverse => (
        fill: c.selected,
        border: null,
        foreground: c.onSelected,
        highlight: Color.alphaBlend(c.onSelected.withValues(alpha: theme.size.pressedOverlayOpacity), c.selected),
      ),
    };
  }

  /// The veil that, painted over [fill], gives [target]: both are the same
  /// color at two opacities.
  static Color _veilOver(Color fill, Color target) {
    if (fill.a >= 1 || target.a <= fill.a) return target;
    return target.withValues(alpha: (target.a - fill.a) / (1 - fill.a));
  }

  /// The fill under the pointer, Izydesk's state matrix: a filled variant
  /// darkens to `size.hoverBrightness` (`filter: brightness(.92)`); a neutral
  /// one, unselected, steps to `controlPressed`, hovered or pressed, even
  /// without fill (`outline`, `ghost`).
  Color? _hovered(FlTheme theme, Color? fill, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled) || loading) return fill;
    final hovered = states.contains(WidgetState.hovered);
    switch (variant) {
      case FlButtonVariant.primary || FlButtonVariant.danger || FlButtonVariant.inverse:
        if (!hovered || fill == null) return fill;
        final k = theme.size.hoverBrightness;
        return Color.from(alpha: fill.a, red: fill.r * k, green: fill.g * k, blue: fill.b * k);
      case FlButtonVariant.secondary || FlButtonVariant.tertiary || FlButtonVariant.outline || FlButtonVariant.ghost:
        if (selected == true) return fill;
        return hovered || states.contains(WidgetState.pressed) ? theme.colors.controlPressed : fill;
      case FlButtonVariant.dangerSoft:
        return fill;
    }
  }

  /// The button's shape: continuous corners in the `rounded` shape.
  static OutlinedBorder _shape(FlButtonShape shape, double radius, BorderSide side) => switch (shape) {
    FlButtonShape.square => RoundedRectangleBorder(side: side),
    FlButtonShape.rounded => FlContinuousBorder(side: side, radius: radius),
    FlButtonShape.pill => StadiumBorder(side: side),
  };

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final sized = _metrics(theme, size ?? FlButtonSize.of(theme.density));
    final metrics = switch (extent) {
      final side? => (
        height: side,
        padding: sized.padding,
        gap: sized.gap,
        icon: sized.icon,
        text: sized.text,
        radius: sized.radius,
      ),
      null => sized,
    };
    final paint = _paint(theme);
    final border = paint.border;
    final shape = _shape(
      theme.shape.button,
      metrics.radius,
      border == null ? BorderSide.none : BorderSide(color: border, width: theme.size.border),
    );
    // Yoga counts the border in an automatic width, not in a fixed height:
    // only the outline width grows.
    final inline = metrics.padding + (border == null ? 0 : theme.size.border);
    // The height is a minimum, and the padding that centers the line keeps
    // it when the text grows, changing nothing at 1×.
    final block = (metrics.height - theme.typography.style(metrics.text).lineHeight) / 2;
    final radius = switch (theme.shape.button) {
      FlButtonShape.square => BorderRadius.zero,
      FlButtonShape.rounded => BorderRadius.circular(metrics.radius),
      FlButtonShape.pill => theme.shape.buttonRadius,
    };
    final iconSize = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: theme.size.iconMaxScale)
        .scale(metrics.icon);
    final iconTheme = IconThemeData(color: paint.foreground, size: iconSize);
    // Yoga snaps each view to the pixel grid, the icon included.
    Widget glyph(Widget child) => FlPixelSnap(
      child: IconTheme.merge(data: iconTheme, child: child),
    );
    // The loading state: an md Spinner in the text color in an icon button,
    // at the icon's size next to a label.
    final spinner = FlSpinner(label: label, color: paint.foreground, extent: this.icon == null ? iconSize : null);
    final icon = this.icon;
    final leading = this.leading;
    final trailing = this.trailing;

    final Widget content;
    if (icon != null) {
      content = loading ? spinner : glyph(icon);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: metrics.gap,
        children: [
          if (loading) spinner else if (leading != null) glyph(leading),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.typography.resolve(metrics.text).copyWith(color: paint.foreground),
              strutStyle: theme.typography.strut(
                metrics.text,
                inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
              ),
            ),
          ),
          if (trailing != null) glyph(trailing),
        ],
      );
    }

    final button = FlPressable(
      onPressed: loading ? null : onPressed,
      statesController: statesController,
      selected: selected,
      label: label,
      borderRadius: radius,
      scaleOnPress: feedback._scales,
      overlay: feedback._overlay,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled) && !loading;
        final fill = _hovered(theme, paint.fill, states);
        final motion = FlMotion.of(context);
        return Opacity(
          opacity: disabled ? theme.size.disabledOpacity : 1,
          child: FlPixelSnap(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: metrics.height, minWidth: icon == null ? 0 : metrics.height),
              // The hover fill fades in over 100 ms.
              child: TweenAnimationBuilder<Color?>(
                // A tween needs an end: no fill is the hover color, transparent.
                tween: ColorTween(end: fill ?? theme.colors.controlPressed.withValues(alpha: 0)),
                duration: motion.reduced ? Duration.zero : theme.motion.short2,
                curve: Curves.easeOut,
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(color: fill, shape: shape),
                  child: child,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: ShapeBorderClipper(shape: shape),
                        child: FlPressHighlight(color: paint.highlight),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: icon == null ? inline : 0,
                        vertical: icon == null ? block : 0,
                      ),
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!fullWidth) return button;
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.hasBoundedWidth ? SizedBox(width: constraints.maxWidth, child: button) : button,
    );
  }
}

// Modified from the Chip of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The fill of a [FlChip].
enum FlChipVariant {
  /// The solid background of the color, its foreground text.
  primary,

  /// The `control` background, the color's soft text.
  secondary,

  /// No background, the color's soft text.
  tertiary,

  /// The color's tint at 15 %, its soft text.
  soft,
}

/// The color of a [FlChip].
enum FlChipColor {
  /// The highlighted color: solid, `selected` with
  /// `onSelected` text (the accent is reserved for the primary action);
  /// soft, `accentSoft` with `onAccentSoft` text.
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

/// The size of a [FlChip]: its padding, its radius and its text.
enum FlChipSize {
  /// 20 high, `textXs` text.
  sm,

  /// 28 high, `textSm` text.
  md,

  /// 36 high, `textBase` text.
  lg,
}

/// A chip: a short medium-weight label in a capsule,
/// between two optional pieces of content (an icon, a remove button). It is
/// pressable when [onPressed] is given, without changing appearance.
class FlChip extends StatelessWidget {
  /// A `primary` `accent` `md` chip that shows [label].
  const FlChip({
    super.key,
    required this.label,
    this.variant = FlChipVariant.primary,
    this.color = FlChipColor.accent,
    this.size = FlChipSize.md,
    this.leading,
    this.trailing,
    this.onPressed,
    this.enabled = true,
    this.statesController,
    this.dot = false,
  });

  /// The label.
  final String label;

  /// The fill.
  final FlChipVariant variant;

  /// The color.
  final FlChipColor color;

  /// The size.
  final FlChipSize size;

  /// Content before the label, tinted with its color and at its size.
  final Widget? leading;

  /// Content after the label, tinted likewise.
  final Widget? trailing;

  /// True: a dot of the label's color before it, a status chip
  /// ("Active", "Pending"), 6 across with the default tokens. It comes
  /// before [leading], and is not read: the label says the status.
  final bool dot;

  /// When null: the chip is not pressable.
  final VoidCallback? onPressed;

  /// False: a pressable chip that cannot be pressed now, faded to
  /// `size.disabledOpacity` and announced as disabled. No effect without
  /// [onPressed].
  final bool enabled;

  /// The chip's states, which the app can read or force; see
  /// `FlPressable.statesController`. Hovered or pressed, a `control` chip
  /// steps to `controlPressed`, Izydesk's state matrix.
  final WidgetStatesController? statesController;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final xs = theme.space.xs;
    final scale = theme.typography;
    final soft = variant != FlChipVariant.primary;
    final fill = switch ((variant, color)) {
      (FlChipVariant.tertiary, _) => null,
      (FlChipVariant.secondary, _) || (_, FlChipColor.neutral) => colors.control,
      (FlChipVariant.primary, FlChipColor.accent) => colors.selected,
      (FlChipVariant.primary, FlChipColor.success) => colors.success,
      (FlChipVariant.primary, FlChipColor.warning) => colors.warning,
      (FlChipVariant.primary, FlChipColor.danger) => colors.dangerFill,
      (FlChipVariant.soft, FlChipColor.accent) => colors.accentSoft,
      (FlChipVariant.soft, FlChipColor.success) => colors.successSoft,
      (FlChipVariant.soft, FlChipColor.warning) => colors.warningSoft,
      (FlChipVariant.soft, FlChipColor.danger) => colors.dangerSoft,
    };
    final ink = switch (color) {
      FlChipColor.accent => soft ? colors.onAccentSoft : colors.onSelected,
      FlChipColor.neutral => colors.onControl,
      FlChipColor.success => soft ? colors.onSuccessSoft : colors.onSuccess,
      FlChipColor.warning => soft ? colors.onWarningSoft : colors.onWarning,
      // `danger` holds 4.5:1 on `control`; `onDangerSoft` is darker only
      // for the soft tint.
      FlChipColor.danger => switch (variant) {
        FlChipVariant.primary => colors.onDanger,
        FlChipVariant.secondary || FlChipVariant.tertiary => colors.danger,
        FlChipVariant.soft => colors.onDangerSoft,
      },
    };
    // px-2 py-0.5 rounded-xl, px-3 py-1 rounded-2xl, px-4 py-1.5 rounded-3xl.
    final (role, horizontal, vertical, radius) = switch (size) {
      FlChipSize.sm => (FlTextRole.textXs, xs * 2, xs / 2, theme.shape.radiusXl),
      FlChipSize.md => (FlTextRole.textSm, xs * 3, xs, theme.shape.radiusXxl),
      FlChipSize.lg => (FlTextRole.textBase, xs * 4, xs * 1.5, theme.shape.radiusCard),
    };
    final style = scale.resolve(role).copyWith(color: ink, fontWeight: theme.tokens.typography.weight.medium);
    final leading = this.leading;
    final trailing = this.trailing;
    final shape = FlContinuousBorder(radius: radius);
    Widget chip({bool hovered = false}) => FlPixelSnap(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: hovered && fill == colors.control ? colors.controlPressed : fill,
          shape: shape,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: horizontal, vertical: vertical),
          child: IconTheme.merge(
            data: IconThemeData(color: ink, size: scale.style(role).size),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              // gap-1: calc(var(--spacing) * 1).
              spacing: xs,
              children: [
                if (dot)
                  SizedBox.square(
                    dimension: xs * 1.5,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: ink, shape: const CircleBorder()),
                    ),
                  ),
                ?leading,
                Flexible(
                  child: Text(
                    label,
                    style: style,
                    strutStyle: scale.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
    final onPressed = this.onPressed;
    // align-self: flex-start: stretched by a column, the chip keeps its
    // width, at the start of the line.
    if (onPressed == null) return _start(chip());
    return _start(
      FlPressable(
        onPressed: enabled ? onPressed : null,
        statesController: statesController,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        scaleOnPress: false,
        overlay: FlPressOverlay.none,
        builder: (context, states) => states.contains(WidgetState.disabled)
            ? Opacity(opacity: theme.size.disabledOpacity, child: chip())
            : chip(hovered: states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)),
      ),
    );
  }
}

Widget _start(Widget child) =>
    Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: child);

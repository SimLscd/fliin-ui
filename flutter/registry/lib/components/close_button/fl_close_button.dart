// Modified from the CloseButton of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The button that closes a dialog, a sheet, a popover or a menu: a round
/// button of `size.closeButton` with a cross of `size.closeIcon`.
///
/// When [filled], the cross sits on a `control` disc, like a `FlAppBar`'s
/// back chevron, which steps to `controlPressed` under the pointer and when
/// pressed. Otherwise the disc is Izydesk's `.close-btn`: no fill at rest,
/// `control` under the pointer and when pressed, and an `onSurfaceMuted`
/// cross.
/// The touch target stays the platform's.
class FlCloseButton extends StatelessWidget {
  /// A close button named [label] for the screen reader.
  const FlCloseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.statesController,
    this.filled = true,
    this.icon,
  });

  /// What the screen reader reads, usually "Close".
  final String label;

  /// Called on tap; when null, the button is disabled.
  final VoidCallback? onPressed;

  /// The button's states; see `FlPressable.statesController`.
  final WidgetStatesController? statesController;

  /// True: the cross sits on a `control` disc; false, bare until the pointer
  /// or a press fills it.
  final bool filled;

  /// The glyph in place of the cross (a circled cross,
  /// a chevron down for a sheet), sized and tinted like it through the
  /// `IconTheme`; null, `FlIcons.xmark`.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final side = theme.size.closeButton;
    // A disc by default; the theme's `radiusXxl` squares it (`square` preset).
    final radius = BorderRadius.circular(math.min(theme.shape.radiusXxl, side / 2));
    // Not a FlButton: `.close-btn` fills when pressed without shrinking,
    // where the button shrinks.
    final colors = theme.colors;
    final rest = filled ? colors.control : colors.control.withValues(alpha: 0);
    final active = filled ? colors.controlPressed : colors.control;
    return FlPressable(
      onPressed: onPressed,
      statesController: statesController,
      label: label,
      borderRadius: radius,
      scaleOnPress: false,
      builder: (context, states) => Opacity(
        opacity: states.contains(WidgetState.disabled) ? theme.size.disabledOpacity : 1,
        child: FlPixelSnap(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: radius,
                    // Under the pointer the disc fades to its pressed fill.
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: states.contains(WidgetState.hovered) && !states.contains(WidgetState.disabled)
                            ? active
                            : rest,
                      ),
                      duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.short2,
                      builder: (context, fill, child) => ColoredBox(color: fill!, child: child),
                      child: FlPressHighlight(color: active),
                    ),
                  ),
                ),
                _CloseIcon(color: filled ? colors.onControl : colors.onSurfaceMuted, icon: icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIcon extends StatelessWidget {
  const _CloseIcon({required this.color, required this.icon});

  final Color color;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final side = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: theme.size.iconMaxScale)
        .scale(theme.size.closeIcon);
    final icon = this.icon;
    if (icon == null) return FlIcon(FlIcons.xmark, size: side, color: color);
    return IconTheme.merge(
      data: IconThemeData(color: color, size: side),
      child: icon,
    );
  }
}

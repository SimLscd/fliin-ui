// Modified from the ToggleButton of HeroUI React v3, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/button/fl_button.dart';

/// The look of an [FlToggleButton] when it is off.
enum FlToggleButtonVariant {
  /// A `control` fill.
  filled,

  /// No fill until hovered or on: in a toolbar.
  ghost,
}

/// A button that stays on or off: a favorite, an
/// editor's bold, a mute. Off, it is a `control` button (or a bare one,
/// [FlToggleButtonVariant.ghost]); on, it takes the `selected` fill and
/// `onSelected` text, like every chosen state, the fill crossfading in
/// `short2`. It is an [FlButton]: the same heights, padding, shape preset,
/// press scale and focus ring. For an exclusive choice among several, use
/// `segmented`.
///
/// The screen reader reads [label] and the selected state; [label] does not
/// change with it ("Bold", not "Bold on"). Color alone does not tell the
/// state: give [selectedLeading] or [selectedIcon], shown while it is on (a
/// filled heart).
///
/// ```dart
/// FlToggleButton(label: 'Like', selected: liked, onChanged: setLiked,
///     leading: FlIcon(FlIcons.heart), selectedLeading: FlIcon(FlIcons.heartFill))
/// ```
class FlToggleButton extends StatelessWidget {
  /// A labeled toggle button.
  const FlToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.variant = FlToggleButtonVariant.filled,
    this.size,
    this.leading,
    this.selectedLeading,
    this.trailing,
  }) : icon = null,
       selectedIcon = null;

  /// A square toggle button that shows only [icon]; [label] remains what the
  /// screen reader reads.
  const FlToggleButton.icon({
    super.key,
    required this.label,
    required Widget this.icon,
    required this.selected,
    required this.onChanged,
    this.variant = FlToggleButtonVariant.filled,
    this.size,
    this.selectedIcon,
  }) : leading = null,
       selectedLeading = null,
       trailing = null;

  /// The text shown, and read by the screen reader.
  final String label;

  /// On or off.
  final bool selected;

  /// Receives the opposite of [selected] when pressed; null disables the
  /// button, at `size.disabledOpacity`.
  final ValueChanged<bool>? onChanged;

  /// The look when off; `filled` by default.
  final FlToggleButtonVariant variant;

  /// The height, the padding and the text size; null follows the theme's
  /// density.
  final FlButtonSize? size;

  /// An icon before the text.
  final Widget? leading;

  /// The icon before the text while [selected], in place of [leading].
  final Widget? selectedLeading;

  /// An icon after the text, in the text's color (a chevron, a lock).
  final Widget? trailing;

  /// The icon of an [FlToggleButton.icon], alone in a square.
  final Widget? icon;

  /// The icon of an [FlToggleButton.icon] while [selected], in place of
  /// [icon].
  final Widget? selectedIcon;

  @override
  Widget build(BuildContext context) {
    // On, both variants become the `tertiary` button's selected state: the
    // `selected` fill. Off, `filled` is the `tertiary` button and `ghost` the
    // `ghost` one.
    final look = selected || variant == FlToggleButtonVariant.filled ? FlButtonVariant.tertiary : FlButtonVariant.ghost;
    final onChanged = this.onChanged;
    final onPressed = onChanged == null ? null : () => onChanged(!selected);
    final icon = selected ? selectedIcon ?? this.icon : this.icon;
    return icon == null
        ? FlButton(
            label: label,
            leading: selected ? selectedLeading ?? leading : leading,
            trailing: trailing,
            selected: selected,
            variant: look,
            size: size,
            onPressed: onPressed,
          )
        : FlButton.icon(label: label, icon: icon, selected: selected, variant: look, size: size, onPressed: onPressed);
  }
}

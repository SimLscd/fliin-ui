// Modified from SearchField of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

// `search-field.css` and `search-field.tsx`: the `size.indicatorIcon`
// magnifier at `space.md` from the start, the text at 36 from the start; the
// clear button at `space.md` from the end: Izydesk's 20 disc in
// `onSurfaceMuted` with its 12 cross in `field`, specific to this field.
const double _clearSize = 20;
const double _crossSize = 12;

/// A search field: an [FlInput] with a
/// magnifier, the keyboard's "search" key, and a round `onSurfaceMuted` button
/// that clears the input, shown as long as it isn't empty. The text keeps
/// its place when the button appears. When disabled, the whole field fades,
/// magnifier included, and the button disappears. [icon] replaces the
/// magnifier; [trailing] shows at the end while the input is empty (a key
/// cap for the shortcut that focuses it), and gives way to the clear button.
/// Put it in an `FlField` for a visible label and a help line.
class FlSearchField extends StatefulWidget {
  /// A search field named [label], whose clear button is named
  /// [clearLabel].
  const FlSearchField({
    super.key,
    required this.label,
    required this.clearLabel,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.variant = FlInputVariant.primary,
    this.searchIcon = true,
    this.icon,
    this.trailing,
    this.invalid,
    this.disabled,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.pill = false,
  });

  /// The field name, read by the screen reader ("Search").
  final String label;

  /// The clear button's name ("Clear search").
  final String clearLabel;

  /// The input. Null, the field creates its own; a provided controller stays
  /// owned by the caller.
  final TextEditingController? controller;

  /// The focus node; null, the field creates one.
  final FocusNode? focusNode;

  /// The placeholder text ("Search…"), shown while the input is empty.
  final String? placeholder;

  /// The input background: `primary` by default.
  final FlInputVariant variant;

  /// False: no magnifier, the text starts at `space.md`.
  final bool searchIcon;

  /// The icon at the start instead of the magnifier, at `size.indicatorIcon`
  /// in `onSurfaceMuted` unless it sets its own; when null, the magnifier.
  /// Ignored when [searchIcon] is false.
  final Widget? icon;

  /// At the end while the input is empty, `space.sm` from the edge: the key
  /// cap of the shortcut that focuses the field.
  /// Neither read nor touchable; the clear button replaces it once there is
  /// text. When null, nothing.
  final Widget? trailing;

  /// True: `danger` border. Null, the `FlFieldScope` state.
  final bool? invalid;

  /// True: the field fades, with neither focus nor clearing. Null, the
  /// `FlFieldScope` state.
  final bool? disabled;

  /// Takes focus on the first frame.
  final bool autofocus;

  /// Receives the input on each keystroke, and the empty string on clearing.
  final ValueChanged<String>? onChanged;

  /// Receives the input on the keyboard's "search" key.
  final ValueChanged<String>? onSubmitted;

  /// Called after the button clears the input.
  final VoidCallback? onCleared;

  /// True: a capsule, its text at the size of body text, like a
  /// conversation's composer; false, the field's corners.
  final bool pill;

  @override
  State<FlSearchField> createState() => _FlSearchFieldState();
}

class _FlSearchFieldState extends State<FlSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void didUpdateWidget(FlSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    switch ((oldWidget.controller, widget.controller)) {
      case (final previous?, null):
        _own = TextEditingController.fromValue(previous.value);
      case (null, _?):
        _own?.dispose();
        _own = null;
      case _:
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final space = theme.space;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    // The magnifier faces the reading direction (`rtl:-scale-x-100`).
    final custom = widget.icon;
    final icon = Padding(
      padding: EdgeInsetsDirectional.only(start: space.md, end: space.sm),
      child: custom == null
          ? Transform.flip(
              flipX: !ltr,
              child: FlIcon(FlIcons.magnifier, size: theme.size.indicatorIcon, color: theme.colors.onSurfaceMuted),
            )
          : IconTheme.merge(
              data: IconThemeData(size: theme.size.indicatorIcon, color: theme.colors.onSurfaceMuted),
              child: custom,
            ),
    );
    // A disc by default; the theme's `radiusXxl` squares it (`square` preset).
    final clearRadius = BorderRadius.circular(math.min(theme.shape.radiusXxl, _clearSize / 2));
    // Disabled, the field shows no clear button (Izydesk's search field at
    // half opacity): it could not be pressed.
    final disabled = widget.disabled ?? FlFieldScope.maybeOf(context)?.disabled ?? false;
    final trailing = widget.trailing;
    final clear = Padding(
      padding: EdgeInsetsDirectional.only(start: space.sm, end: space.md),
      child: SizedBox.square(
        dimension: _clearSize,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty || disabled
              ? const SizedBox.shrink()
              : FlPressable(
                  label: widget.clearLabel,
                  borderRadius: clearRadius,
                  onPressed: _clear,
                  builder: (context, states) => DecoratedBox(
                    decoration: BoxDecoration(color: theme.colors.onSurfaceMuted, borderRadius: clearRadius),
                    child: Center(
                      child: FlIcon(FlIcons.xmark, size: _crossSize, color: theme.colors.field),
                    ),
                  ),
                ),
        ),
      ),
    );
    final suffix = trailing == null
        ? clear
        : ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => value.text.isEmpty
                ? IgnorePointer(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(start: space.sm, end: space.sm),
                        child: trailing,
                      ),
                    ),
                  )
                : clear,
          );
    return FlInputAffixes(
      prefix: widget.searchIcon ? icon : null,
      suffix: suffix,
      child: FlInput(
        label: widget.label,
        controller: _controller,
        focusNode: widget.focusNode,
        placeholder: widget.placeholder,
        variant: widget.variant,
        invalid: widget.invalid,
        disabled: widget.disabled,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        compact: widget.pill,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

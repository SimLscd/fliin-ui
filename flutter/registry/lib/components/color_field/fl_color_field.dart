// Modified from the ColorField and ColorInputGroup of HeroUI React v3,
// Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';

/// A hexadecimal color field: the label, an input that writes the color as
/// `#RRGGBB` with a 16 swatch of it at its start, then the help or the
/// error. It has the frame of a `FlTextField`: white, lifted by the
/// `field` shadow, the accent ring on focus, the `danger` outline when
/// [error] is given.
///
/// Typed text counts as soon as it is a color (`#RGB` or `#RRGGBB`, the
/// `#` optional; with [alpha], `#RGBA` and `#RRGGBBAA` too): [onChanged]
/// receives it at once, and the swatch follows. On leaving the field or on
/// the action key, a color is rewritten in full capitals, and text that is
/// not one gives the previous color back, as React Aria's `ColorField`
/// does; an emptied field gives null, unless [required].
///
/// The hex is written left to right on an Arabic page too. The color is a
/// value of the app, never a theme color.
class FlColorField extends StatefulWidget {
  /// A field named [label] that shows [value] and offers the colors typed to
  /// [onChanged].
  const FlColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.helper,
    this.error,
    this.alpha = false,
    this.required = false,
    this.enabled = true,
    this.variant = FlInputVariant.primary,
    this.focusNode,
    this.autofocus = false,
  });

  /// The field's name, shown above and read by the screen reader.
  final String label;

  /// The color shown; null, an empty field. A value different from the one
  /// being typed replaces the text: the parent has the last word.
  final Color? value;

  /// Receives each color typed, and null when the field is emptied (unless
  /// [required]); up to the parent to give it back in [value].
  final ValueChanged<Color?> onChanged;

  /// The example text of an empty field ("#0485F7").
  final String? placeholder;

  /// The help under the field, read as a hint. Hidden while [error] is
  /// non-null.
  final String? helper;

  /// Non-null: the field is invalid, and this text replaces [helper].
  final String? error;

  /// True: the field reads and writes the opacity (`#RRGGBBAA`).
  final bool alpha;

  /// True: an asterisk follows the label, and an emptied field gives the
  /// previous color back.
  final bool required;

  /// False: the whole field is half opaque, without touch or focus.
  final bool enabled;

  /// The background: `primary` by default, `secondary` on a surface.
  final FlInputVariant variant;

  /// The input's focus node; null, the field creates its own.
  final FocusNode? focusNode;

  /// Takes focus on the first frame if nothing else has it within its scope.
  final bool autofocus;

  @override
  State<FlColorField> createState() => _FlColorFieldState();
}

class _FlColorFieldState extends State<FlColorField> {
  final TextEditingController _text = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// The last color the input gave the parent: given back in
  /// [FlColorField.value], it does not rewrite the text being typed.
  Color? _typed;

  @override
  void initState() {
    super.initState();
    _text.text = _format(widget.value);
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(FlColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChange);
      _focus.addListener(_onFocusChange);
    }
    if (oldWidget.value != widget.value && !(_focus.hasFocus && widget.value == _typed)) {
      _show(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _ownFocus?.dispose();
    _text.dispose();
    super.dispose();
  }

  String _format(Color? color) => color == null ? '' : flColorHex(color, alpha: widget.alpha);

  void _show(Color? color) {
    final text = _format(color);
    if (_text.text == text) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _settle();
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      if (!widget.required && widget.value != null) {
        _typed = null;
        widget.onChanged(null);
      }
      return;
    }
    final color = flParseColorHex(text, alpha: widget.alpha);
    if (color == null || color == widget.value) return;
    _typed = color;
    widget.onChanged(color);
  }

  /// On leaving: a color is rewritten in full, anything else gives the
  /// previous color back.
  void _settle() {
    final color = flParseColorHex(_text.text, alpha: widget.alpha);
    if (color == null && _text.text.trim().isEmpty && !widget.required) {
      _show(null);
      return;
    }
    _show(color ?? widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.value;
    return FlTextField(
      label: widget.label,
      controller: _text,
      focusNode: _focus,
      placeholder: widget.placeholder,
      helper: widget.helper,
      error: widget.error,
      required: widget.required,
      enabled: widget.enabled,
      variant: widget.variant,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      textDirection: TextDirection.ltr,
      prefix: shown == null ? null : FlColorSwatch(color: shown, label: null, size: FlColorSwatchSize.xs),
      onChanged: _onChanged,
      onSubmitted: (_) => _settle(),
    );
  }
}

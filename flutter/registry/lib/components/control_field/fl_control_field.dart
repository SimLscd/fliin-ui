// Modified from the ControlField of HeroUI Native 1.0.10, Copyright 2025 NextUI
// Inc., licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/components/radio/fl_radio.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/components/switch/fl_switch.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The control of a [FlControlField]: a switch after the label, a checkbox or a
/// radio before it.
enum FlControlFieldIndicator {
  /// A `FlSwitch`.
  toggle,

  /// A `FlCheckbox`.
  checkbox,

  /// A `FlRadio`, which is selected and never unchecked: the row, the
  /// keyboard and the screen reader only select it. It gets no pressed
  /// state.
  radio,
}

/// The background of the box or the unchecked radio of a [FlControlField].
/// The switch has only one.
enum FlControlFieldVariant {
  /// `field` background and `field` shadow: a row placed on the page.
  primary,

  /// `control` background, no shadow: a row placed on a surface, a sheet or
  /// a dialog, whose background is that of `field`.
  secondary,
}

/// Where the control of a [FlControlField] sits.
enum FlControlFieldSide {
  /// Before the label and its description.
  start,

  /// After them, at the end of the row.
  end,
}

/// A one-row setting: a checkbox or a radio
/// before the label and its description, a switch after them. The whole
/// row is tappable and presses the switch or the checkbox (not the radio,
/// which has no pressed state); the screen reader reads it as a single
/// control, label and description included. [error] shows under the label
/// and the description, beside the control, when the field is [invalid].
/// Framed, the row sits on a `surfaceRaised` card that a `danger` outline
/// surrounds when invalid, or a `selected` one when [outlineSelected] and
/// on. [indicatorSide] moves the control to the other side.
class FlControlField extends StatefulWidget {
  /// A row [label] whose control is in state [value].
  const FlControlField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.description,
    this.error,
    this.indicator = FlControlFieldIndicator.toggle,
    this.variant = FlControlFieldVariant.primary,
    this.invalid = false,
    this.required = false,
    this.framed,
    this.indicatorSide,
    this.outlineSelected = false,
  });

  /// On, checked or selected. The parent holds it.
  final bool value;

  /// Receives the opposite state when the row is tapped (always true for a
  /// radio), or the one the control requests. When null: the row is
  /// disabled, its texts go to `size.disabledOpacity`.
  final ValueChanged<bool>? onChanged;

  /// The label, in `textBase`.
  final String label;

  /// A help text under the label, in `textSm`.
  final String? description;

  /// The error message under the label and the description, as a
  /// `FlFieldError`, shown when [invalid] is true.
  final String? error;

  /// The control at the end of the row; a switch by default.
  final FlControlFieldIndicator indicator;

  /// The background of the box or the unchecked radio; `primary` by default.
  final FlControlFieldVariant variant;

  /// True: the value is rejected; the box, the radio or the switch, and the
  /// card when [framed], take a `danger` outline, and [error] appears.
  final bool invalid;

  /// True: the label carries an asterisk.
  final bool required;

  /// True: the row sits on its own `surfaceRaised` card, as a setting placed
  /// on the page. When null, a `primary` field is framed and a `secondary`
  /// one, already on a surface, is not; a group's rows are never framed.
  final bool? framed;

  /// The side of the control. When null, a switch at the end, as in iOS
  /// settings, and a checkbox or a radio at the start, as in a form.
  final FlControlFieldSide? indicatorSide;

  /// True: a framed field that is on, checked or selected is outlined in
  /// `selected`, like delivery options: the chosen card of a list of
  /// options stands out. An invalid field keeps its `danger` outline.
  final bool outlineSelected;

  @override
  State<FlControlField> createState() => _FlControlFieldState();
}

class _FlControlFieldState extends State<FlControlField> {
  final WidgetStatesController _states = WidgetStatesController();

  bool get _enabled => widget.onChanged != null;

  /// Toggles the switch or the checkbox; selects the radio, never
  /// unchecking it, like its keyboard (`toggleable: false`).
  void _activate() => widget.onChanged?.call(widget.indicator == FlControlFieldIndicator.radio || !widget.value);

  void _press(bool pressed) => _states.update(WidgetState.pressed, pressed && _enabled);

  @override
  void didUpdateWidget(FlControlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  Widget _control() {
    final onChanged = widget.onChanged;
    final secondary = widget.variant == FlControlFieldVariant.secondary;
    return switch (widget.indicator) {
      FlControlFieldIndicator.toggle => FlSwitch(
        value: widget.value,
        onChanged: onChanged,
        label: widget.label,
        statesController: _states,
      ),
      FlControlFieldIndicator.checkbox => FlCheckbox(
        value: widget.value,
        onChanged: onChanged == null ? null : (value) => onChanged(value ?? false),
        label: widget.label,
        variant: secondary ? FlCheckboxVariant.secondary : FlCheckboxVariant.primary,
        statesController: _states,
      ),
      FlControlFieldIndicator.radio => RadioGroup<bool>(
        groupValue: widget.value ? true : null,
        onChanged: (_) => onChanged?.call(true),
        child: FlRadio<bool>(
          value: true,
          label: widget.label,
          enabled: _enabled,
          variant: secondary ? FlRadioVariant.secondary : FlRadioVariant.primary,
        ),
      ),
    };
  }

  /// The label in `textBase` regular, `onSurface` even when invalid (the
  /// outline and the error carry it), its asterisk in `danger`; the
  /// description in `textSm` `onSurfaceMuted`.
  Widget _texts(FlTheme theme) {
    final colors = theme.colors;
    final scale = theme.typography;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    Widget text(String data, FlTextRole role, Color color, {List<InlineSpan> trailing = const []}) => Text.rich(
      TextSpan(text: data, children: trailing),
      style: scale.resolve(role).copyWith(color: color, fontWeight: theme.tokens.typography.weight.normal),
      strutStyle: scale.strut(role, inheritedFamily: family),
    );
    final description = widget.description;
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text(
          widget.label,
          FlTextRole.textBase,
          colors.onSurface,
          trailing: [
            if (widget.required)
              TextSpan(
                text: ' *',
                semanticsLabel: '',
                style: TextStyle(color: _enabled ? colors.danger : colors.onSurfaceMuted),
              ),
          ],
        ),
        if (description != null) text(description, FlTextRole.textSm, colors.onSurfaceMuted),
      ],
    );
    // A disabled field fades its texts with its control, and falls outside
    // the contrast rule like it (WCAG 1.4.3).
    return _enabled ? texts : Opacity(opacity: theme.size.disabledOpacity, child: texts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final description = widget.description;
    final error = widget.error;
    final onChanged = widget.onChanged;
    final framed = widget.framed ?? widget.variant == FlControlFieldVariant.primary;
    final leading = switch (widget.indicatorSide) {
      FlControlFieldSide.start => true,
      FlControlFieldSide.end => false,
      null => widget.indicator != FlControlFieldIndicator.toggle,
    };
    // The error is the texts' last line (`.choice-text .err`), outside the
    // row's merged reading: it is announced on its own when it appears.
    final texts = Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: _texts(theme)),
          if (error != null) FlFieldError(error),
        ],
      ),
    );
    final control = ExcludeSemantics(child: _control());
    final row = FlHitTarget(
      child: Semantics(
        enabled: _enabled,
        label: widget.label,
        hint: description,
        toggled: widget.indicator == FlControlFieldIndicator.toggle ? widget.value : null,
        checked: widget.indicator == FlControlFieldIndicator.toggle ? null : widget.value,
        inMutuallyExclusiveGroup: widget.indicator == FlControlFieldIndicator.radio ? true : null,
        onTap: onChanged == null ? null : _activate,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: onChanged == null ? null : _activate,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: theme.size.controlCompact),
            child: Row(spacing: theme.space.md, children: leading ? [control, texts] : [texts, control]),
          ),
        ),
      ),
    );
    final Widget field;
    if (framed) {
      final shape = FlContinuousBorder(
        radius: theme.shape.radiusCard,
        side: switch ((widget.invalid, widget.outlineSelected && widget.value)) {
          (true, _) => BorderSide(color: colors.danger, width: theme.size.border),
          (false, true) => BorderSide(color: colors.selected, width: theme.size.border),
          (false, false) => BorderSide.none,
        },
      );
      field = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: shape),
        child: FlSurface(
          padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.lg, vertical: theme.space.md),
          child: row,
        ),
      );
    } else {
      field = row;
    }
    return FlFieldScope(invalid: widget.invalid, disabled: !_enabled, required: widget.required, child: field);
  }
}

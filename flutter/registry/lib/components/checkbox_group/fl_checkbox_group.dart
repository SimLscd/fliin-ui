// Modified from the CheckboxGroup of HeroUI React v3, Copyright 2020 Next UI
// Inc., licensed under the MIT license below and under Apache 2.0:
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
// Also modified from the ControlField of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0.
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/checkbox/fl_checkbox.dart';
import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A box of a [FlCheckboxGroup]: the value it adds to the selection, its
/// label and its help text.
class FlCheckboxGroupOption<T> {
  /// The box [value], named [label].
  const FlCheckboxGroupOption({required this.value, required this.label, this.description, this.disabled = false});

  /// The value the box adds to the selection when checked.
  final T value;

  /// The row's label, also read by the screen reader.
  final String label;

  /// A help text under the label.
  final String? description;

  /// True: this box alone does not respond.
  final bool disabled;
}

/// A group of checkboxes: a shared label
/// and description, one `FlControlField` row per box, then the group's
/// error message. The selection is the set [value] of checked values, held
/// by the parent.
///
/// The screen reader reads the group as a node named by [label] and
/// described by [description], then each box; the error is announced when
/// it appears. [invalid] outlines each box in `danger`, [disabled] disables
/// them all. A minimum or maximum number of boxes is validated by the
/// caller, through [invalid] and [error]: [required] only
/// sets the asterisk and the required state.
class FlCheckboxGroup<T> extends StatefulWidget {
  /// A group [label] whose [options] boxes are checked according to [value].
  const FlCheckboxGroup({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.options,
    this.description,
    this.error,
    this.invalid = false,
    this.required = false,
    this.disabled = false,
    this.variant = FlControlFieldVariant.primary,
    this.framed = false,
    this.selectAllLabel,
  });

  /// The group's label, in the `label` role, which names it for the screen
  /// reader.
  final String label;

  /// The background of the boxes: `primary` on the page by default,
  /// `secondary` on a surface, a sheet or a dialog.
  final FlControlFieldVariant variant;

  /// True: each box sits on its own `surfaceRaised` card, `space.sm` apart,
  /// a choice of plans or add-ons rather than a plain list.
  final bool framed;

  /// Non-null: a box of that name ("Select all") above the others, which
  /// are indented under it. It is checked when every box is, mixed when
  /// some are; tapping it checks every enabled box, or clears them all
  /// once they are all checked.
  final String? selectAllLabel;

  /// The values of the checked boxes.
  final Set<T> value;

  /// Receives the new set when a box changes; the parent passes it back in
  /// [value]. Two boxes tapped before the parent passes back the first add
  /// up: the second set starts from the first, not from [value].
  final ValueChanged<Set<T>> onChanged;

  /// The boxes, top to bottom.
  final List<FlCheckboxGroupOption<T>> options;

  /// A help text under the label, in `textSm`.
  final String? description;

  /// The error message under the boxes, shown when [invalid] is true.
  final String? error;

  /// True: the selection is rejected; the boxes take a `danger` outline, and
  /// [error] appears.
  final bool invalid;

  /// True: the label carries an asterisk and the group announces itself required.
  final bool required;

  /// True: no box responds, and the whole group fades.
  final bool disabled;

  @override
  State<FlCheckboxGroup<T>> createState() => _FlCheckboxGroupState<T>();
}

class _FlCheckboxGroupState<T> extends State<FlCheckboxGroup<T>> {
  /// The last set sent, or the parent's value when it passes one back.
  late Set<T> _latest = widget.value;

  @override
  void didUpdateWidget(FlCheckboxGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _latest = widget.value;
  }

  void _toggle(T option, bool on) {
    _latest = on ? {..._latest, option} : ({..._latest}..remove(option));
    widget.onChanged(_latest);
  }

  /// Checks every enabled box, or clears them once all are checked; a
  /// disabled box keeps its state.
  void _toggleAll() {
    final enabled = {
      for (final option in widget.options)
        if (!option.disabled) option.value,
    };
    final all = widget.options.every((option) => _latest.contains(option.value));
    _latest = all ? ({..._latest}..removeAll(enabled)) : {..._latest, ...enabled};
    widget.onChanged(_latest);
  }

  /// The box that checks them all, mixed while only some are checked: the
  /// same row as the others, its checkbox carrying the semantics.
  Widget _selectAll(FlTheme theme, String label) {
    final options = widget.options;
    final checked = options.where((option) => widget.value.contains(option.value)).length;
    final bool? state = checked == 0 ? false : (checked == options.length ? true : null);
    final enabled = !widget.disabled && options.any((option) => !option.disabled);
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final text = Text(
      label,
      style: theme.typography
          .resolve(FlTextRole.textBase)
          .copyWith(color: theme.colors.onSurface, fontWeight: theme.tokens.typography.weight.normal),
      strutStyle: theme.typography.strut(FlTextRole.textBase, inheritedFamily: family),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: theme.size.controlCompact),
      child: Row(
        spacing: theme.space.md,
        children: [
          FlCheckbox(
            value: state,
            tristate: true,
            label: label,
            invalid: widget.invalid,
            variant: widget.variant == FlControlFieldVariant.secondary
                ? FlCheckboxVariant.secondary
                : FlCheckboxVariant.primary,
            onChanged: enabled ? (_) => _toggleAll() : null,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: enabled ? _toggleAll : null,
              child: ExcludeSemantics(
                child: enabled ? text : Opacity(opacity: theme.size.disabledOpacity, child: text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final FlCheckboxGroup(:label, :description, :error, :invalid, :required, :disabled, :options, :value) = widget;
    final selectAll = widget.selectAllLabel;
    // Indented under "Select all": each box under its label.
    final indent = selectAll == null ? 0.0 : theme.size.toggle + theme.space.md;
    return FlFieldScope(
      invalid: invalid,
      disabled: disabled,
      required: required,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: label,
        hint: description,
        isRequired: required ? true : null,
        validationResult: invalid ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: _header(context, label: label, description: description, required: required, disabled: disabled),
            ),
            if (selectAll != null)
              Padding(
                padding: EdgeInsetsDirectional.only(top: theme.space.sm),
                child: _selectAll(theme, selectAll),
              ),
            for (final option in options)
              Padding(
                padding: EdgeInsetsDirectional.only(top: theme.space.sm, start: indent),
                child: FlControlField(
                  value: value.contains(option.value),
                  onChanged: disabled || option.disabled ? null : (on) => _toggle(option.value, on),
                  label: option.label,
                  description: option.description,
                  indicator: FlControlFieldIndicator.checkbox,
                  variant: widget.variant,
                  invalid: invalid,
                  framed: widget.framed,
                ),
              ),
            if (error != null)
              Padding(
                padding: EdgeInsetsDirectional.only(top: invalid ? theme.space.sm : 0),
                child: FlFieldError(error),
              ),
          ],
        ),
      ),
    );
  }
}

/// A group's header: [label] in the `label` role, `onSurface`, with a
/// `danger` asterisk when [required]; [description] in `textSm`
/// `onSurfaceMuted` under it. Neither turns `danger`: the outlines and the
/// error carry the invalid state. Disabled, it fades.
Widget _header(
  BuildContext context, {
  required String label,
  String? description,
  required bool required,
  required bool disabled,
}) {
  final theme = FlScope.of(context);
  final colors = theme.colors;
  final scale = theme.typography;
  final family = DefaultTextStyle.of(context).style.fontFamily;
  final header = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: theme.space.xs / 2,
    children: [
      Text.rich(
        TextSpan(
          text: label,
          children: [
            if (required)
              TextSpan(
                text: ' *',
                semanticsLabel: '',
                style: TextStyle(color: disabled ? colors.onSurfaceMuted : colors.danger),
              ),
          ],
        ),
        style: scale.resolve(FlTextRole.label).copyWith(color: colors.onSurface),
        strutStyle: scale.strut(FlTextRole.label, inheritedFamily: family),
      ),
      if (description != null)
        Text(
          description,
          style: scale.resolve(FlTextRole.textSm).copyWith(color: colors.onSurfaceMuted),
          strutStyle: scale.strut(FlTextRole.textSm, inheritedFamily: family),
        ),
    ],
  );
  return disabled ? Opacity(opacity: theme.size.disabledOpacity, child: header) : header;
}

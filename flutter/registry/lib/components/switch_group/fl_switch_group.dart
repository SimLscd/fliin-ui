// Modified from the SwitchGroup of HeroUI React v3, Copyright 2020 Next UI
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
import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/core/fliin.dart';

/// A switch of an [FlSwitchGroup]: a setting independent of the others, its
/// state, its label and its help text.
class FlSwitchGroupOption {
  /// The [label] switch, in the [value] state.
  const FlSwitchGroupOption({required this.value, required this.onChanged, required this.label, this.description});

  /// On or off; the parent holds it.
  final bool value;

  /// Receives the requested state. Null: this switch alone does not respond.
  final ValueChanged<bool>? onChanged;

  /// The row's label, also read by the screen reader.
  final String label;

  /// A help text under the label.
  final String? description;
}

/// A group of switches: one `FlControlField`
/// row per setting, `space.xs` apart, under a shared label and
/// description, with a shared error message. Each switch keeps its own
/// value: the group only brings them together.
///
/// The screen reader reads the group as a node named by [label] and
/// described by [description], then each switch; the error is announced
/// when it appears. [disabled] disables them all.
class FlSwitchGroup extends StatelessWidget {
  /// A [label] group of the [options] settings.
  const FlSwitchGroup({
    super.key,
    required this.label,
    required this.options,
    this.description,
    this.error,
    this.invalid = false,
    this.required = false,
    this.disabled = false,
    this.framed = false,
  });

  /// The group's label, in the `label` role, which names it for the screen
  /// reader.
  final String label;

  /// True: each setting sits on its own `surfaceRaised` card, `space.sm`
  /// apart, as settings placed on the page.
  final bool framed;

  /// The settings, top to bottom.
  final List<FlSwitchGroupOption> options;

  /// A help text under the label, in `textSm`.
  final String? description;

  /// The error message under the settings, shown when [invalid] is true.
  final String? error;

  /// True: the combination is rejected; the switches take a `danger` outline, and
  /// [error] appears.
  final bool invalid;

  /// True: the label carries an asterisk and the group announces itself as
  /// required.
  final bool required;

  /// True: no switch responds, and the whole group fades.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final description = this.description;
    final error = this.error;
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
            for (final option in options)
              Padding(
                padding: EdgeInsetsDirectional.only(top: framed ? theme.space.sm : theme.space.xs),
                child: FlControlField(
                  value: option.value,
                  onChanged: disabled ? null : option.onChanged,
                  label: option.label,
                  description: option.description,
                  invalid: invalid,
                  framed: framed,
                ),
              ),
            if (error != null)
              Padding(
                padding: EdgeInsetsDirectional.only(top: invalid ? theme.space.xs : 0),
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
    spacing: theme.space.xs,
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

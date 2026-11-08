// Modified from the form-field-context of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';

/// The state of a form field, read by its parts: label, description, error
/// message, input and controls. A field
/// (`text-field`, `control-field`, a radio group) places it around its parts;
/// a part placed alone reads a null [FlFieldScope.maybeOf] and keeps its own
/// settings.
class FlFieldScope extends InheritedWidget {
  /// The state of the field around [child].
  const FlFieldScope({
    super.key,
    this.invalid = false,
    this.disabled = false,
    this.required = false,
    this.inset = false,
    required super.child,
  });

  /// True when the field's value is rejected: the error shows, and the label
  /// and description switch to the `danger` color.
  final bool invalid;

  /// True when the field cannot be edited: its parts drop to
  /// `size.disabledOpacity`.
  final bool disabled;

  /// True when the field must be filled in: the label carries an asterisk.
  final bool required;

  /// True when the parts align with the input's text, indented by
  /// `size.fieldInset` (set by `FlTextField` and `FlSearchField`).
  final bool inset;

  /// The state of the nearest field, null outside a field; [context] rebuilds
  /// when it changes.
  static FlFieldScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FlFieldScope>();

  @override
  bool updateShouldNotify(FlFieldScope oldWidget) =>
      invalid != oldWidget.invalid ||
      disabled != oldWidget.disabled ||
      required != oldWidget.required ||
      inset != oldWidget.inset;
}

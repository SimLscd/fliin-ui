// Modified from the Fieldset of HeroUI React v3, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/field/fl_field.dart';
import 'package:fliin_ui/core/fliin.dart';

/// Fields that belong together under one title: a
/// [legend] in `textBase` medium, a [description] under it, then the
/// [children] `space.lg` apart, `space.xl` below the title, then the
/// [actions] in a row. When [error] is set, it replaces the description,
/// as in a field: a message for the whole group ("Pick at least one day"),
/// the fields keeping their own.
///
/// [trailing] sits at the end of the legend's line (an "Edit" link, a
/// badge); [actionsAlignment] moves the buttons to the end or the center,
/// and a button in a `SizedBox(width: double.infinity)` takes the full
/// width, as on a phone's form.
///
/// The screen reader reads the legend as a heading, then each field with
/// its own label.
///
/// ```dart
/// FlFieldset(
///   legend: 'Profile',
///   description: 'Shown on your public page.',
///   actions: [FlButton(label: 'Save', onPressed: save)],
///   children: [FlTextField(label: 'Name'), FlTextField(label: 'Email')],
/// )
/// ```
class FlFieldset extends StatelessWidget {
  /// A group of [children] titled [legend].
  const FlFieldset({
    super.key,
    required this.legend,
    required this.children,
    this.description,
    this.error,
    this.actions = const [],
    this.trailing,
    this.actionsAlignment = WrapAlignment.start,
  });

  /// The group's title.
  final String legend;

  /// A line under the title, in `onSurfaceMuted`.
  final String? description;

  /// The fields, in order, stretched to the group's width.
  final List<Widget> children;

  /// A message for the whole group, in `danger`, in place of [description].
  final String? error;

  /// The buttons under the fields ("Save", "Cancel"), `space.sm` apart; the
  /// row wraps when they do not fit.
  final List<Widget> actions;

  /// A widget at the end of the legend's line, centered on it: a link
  /// button, a badge, a switch for the whole group.
  final Widget? trailing;

  /// Where the [actions] sit on their row; at the start by default.
  final WrapAlignment actionsAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    const role = FlTextRole.textBase;
    final error = this.error;
    final description = this.description;
    final legend = Semantics(
      header: true,
      child: Text(
        this.legend,
        style: theme.typography
            .resolve(role)
            .copyWith(color: theme.colors.onSurface, fontWeight: theme.tokens.typography.weight.medium),
        strutStyle: theme.typography.strut(role, inheritedFamily: DefaultTextStyle.of(context).style.fontFamily),
      ),
    );
    final message = error != null
        ? FlFieldError(error, invalid: true)
        : description != null
        ? FlDescription(description, invalid: false)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tight around their text: at full width, the contrast check took
        // the field below as their background.
        if (trailing case final trailing?)
          Row(
            spacing: theme.space.sm,
            children: [
              Expanded(
                child: Align(alignment: AlignmentDirectional.centerStart, child: legend),
              ),
              trailing,
            ],
          )
        else
          Align(alignment: AlignmentDirectional.centerStart, child: legend),
        if (message != null)
          Padding(
            padding: EdgeInsetsDirectional.only(top: theme.space.xs),
            child: Align(alignment: AlignmentDirectional.centerStart, child: message),
          ),
        SizedBox(height: theme.space.xl),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.lg,
          children: children,
        ),
        if (actions.isNotEmpty)
          Padding(
            // The gap between fields, plus 4 above the actions.
            padding: EdgeInsetsDirectional.only(top: theme.space.xl + theme.space.xs),
            child: Wrap(
              alignment: actionsAlignment,
              spacing: theme.space.sm,
              runSpacing: theme.space.sm,
              children: actions,
            ),
          ),
      ],
    );
  }
}

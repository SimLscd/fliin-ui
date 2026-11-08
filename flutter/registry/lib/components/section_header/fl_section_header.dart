// The title is modified from the ListGroup examples of HeroUI Native 1.0.10,
// Copyright 2025 NextUI Inc., licensed under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/core/fliin.dart';

/// The action of an [FlSectionHeader]: a "See all" link at the end of the
/// title.
final class FlSectionHeaderAction {
  /// A link that shows [label] and calls [onPressed].
  const FlSectionHeaderAction({required this.label, required this.onPressed});

  /// The link text, read as is by the screen reader.
  final String label;

  /// Called when the link is pressed; null disables the link.
  final VoidCallback? onPressed;
}

/// The size of an [FlSectionHeader]'s title.
enum FlSectionHeaderSize {
  /// Muted `textSm`, above a group of rows: a settings screen's "Account".
  small,

  /// `title3` in `onSurface`, above a carousel or a grid that opens a part
  /// of the app: a store's "Popular near you".
  large,
}

/// The title of a section placed above an `FlListGroup` or a grid: [title] in
/// muted `textSm`, inset by `space.lg` from the group's edges, so that it
/// lines up with the rows' text, `space.sm` above it. An optional [action]
/// sits at the end, as an `sm` link in the text color, or below
/// when the two do not fit on one line.
///
/// [size] `large` makes it the title of a part of a screen, `space.md`
/// above its content, and [description] adds a muted line under it;
/// [trailing] puts another widget than a link at the end (a count, an icon
/// button).
///
/// The title is announced as a header: the screen reader jumps from section
/// to section.
class FlSectionHeader extends StatelessWidget {
  /// The [title], and an [action] at the end.
  const FlSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.size = FlSectionHeaderSize.small,
    this.description,
    this.trailing,
  }) : assert(action == null || trailing == null, 'an action or a trailing widget, not both');

  /// The section name.
  final String title;

  /// The link at the end of the title; null leaves the title alone.
  final FlSectionHeaderAction? action;

  /// Muted `textSm` above rows by default, or `large` above a carousel.
  final FlSectionHeaderSize size;

  /// A muted line under the title, across the whole width: what the
  /// section holds, or why ("Based on your recent orders"). When null,
  /// none.
  final String? description;

  /// A widget at the end of the title instead of [action], centered on its
  /// line: a count, an `sm` icon button. It brings its own semantics. When
  /// null, none.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final large = size == FlSectionHeaderSize.large;
    final role = large ? FlTextRole.title3 : FlTextRole.textSm;
    final action = this.action;
    final description = this.description;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final end = switch ((action, trailing)) {
      (final action?, _) => FlLinkButton(
        label: action.label,
        onPressed: action.onPressed,
        size: FlButtonSize.sm,
        underline: true,
      ),
      (null, final trailing?) => trailing,
      (null, null) => null,
    };
    // The link moves under the heading when they don't fit on one line:
    // beside it, the heading would be cut mid-word. The header node hugs
    // the text, so the contrast measurement finds the text there rather
    // than the group's background and shadow.
    final heading = OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      spacing: theme.space.md,
      overflowSpacing: theme.space.xs,
      overflowAlignment: OverflowBarAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.typography
                .resolve(role, heading: true)
                .copyWith(color: large ? theme.colors.onSurface : theme.colors.onSurfaceMuted),
            strutStyle: theme.typography.strut(role, inheritedFamily: family, heading: true),
          ),
        ),
        ?end,
      ],
    );
    final descriptionRole = large ? FlTextRole.textSm : FlTextRole.textXs;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.space.lg,
        end: theme.space.lg,
        bottom: large ? theme.space.md : theme.space.sm,
      ),
      child: description == null
          ? heading
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: large ? theme.space.xs : 0,
              children: [
                heading,
                Text(
                  description,
                  style: theme.typography.resolve(descriptionRole).copyWith(color: theme.colors.onSurfaceMuted),
                  strutStyle: theme.typography.strut(descriptionRole, inheritedFamily: family),
                ),
              ],
            ),
    );
  }
}

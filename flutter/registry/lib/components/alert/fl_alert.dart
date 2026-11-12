// Modified from the Alert of HeroUI Native 1.0.10, Copyright 2025 NextUI Inc.,
// licensed under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The status of a [FlAlert]: the color of its title and icon, and the icon
/// itself.
enum FlAlertStatus {
  /// `onSurface`, the info icon.
  neutral,

  /// The info icon in `accent`, the title in `onAccentSoft`: the accent
  /// reads as a mark, not as text, which it would not hold at 4.5:1 on a
  /// dark card.
  accent,

  /// `onSuccessSoft`, the check icon.
  success,

  /// `onWarningSoft`, the warning icon.
  warning,

  /// `onDangerSoft`, the cross icon.
  danger,
}

/// An inline alert: on a shadowed surface (an error on the pastel
/// `dangerSoft`, flat), the status
/// icon, a title in its color, a muted description and, at the end, an
/// action. Under the text, [content] takes what a sentence cannot hold (a
/// list of steps), and [action] a button below the text, where a phone has
/// room for it; [trailing] keeps the end of the row for a close button or a
/// short action. The screen reader announces it when it appears: on the web
/// through the `alert` role, elsewhere as a live region (the engine only
/// handles the `alert` role on the web, and refuses both together).
class FlAlert extends StatelessWidget {
  /// A [status] alert titled [title].
  const FlAlert({
    super.key,
    required this.title,
    this.description,
    this.status = FlAlertStatus.neutral,
    this.icon,
    this.showIcon = true,
    this.trailing,
    this.content,
    this.action,
  });

  /// The title, in medium-weight `textBase`, in the status color.
  final String title;

  /// The text under the title, in muted `textSm`. When null: the title alone.
  final String? description;

  /// The status.
  final FlAlertStatus status;

  /// An icon in place of the status one (`Alert.Indicator` and its
  /// children), in the status color and at its size, 20.
  final Widget? icon;

  /// When false: neither icon nor its space.
  final bool showIcon;

  /// Content after the text, most often an action (an sm button) or a
  /// `FlCloseButton`.
  final Widget? trailing;

  /// Content under the description, in `textSm` and `onSurfaceMuted` (a
  /// list of steps, a link), 8 below it.
  final Widget? content;

  /// An action under the text, 12 below it, aligned with the title (an sm
  /// button): the layout of an alert on a narrow screen, where a button at
  /// the end of the row would squeeze the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    final scale = theme.typography;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final tone = switch (status) {
      FlAlertStatus.neutral => colors.onSurface,
      FlAlertStatus.accent => colors.onAccentSoft,
      FlAlertStatus.success => colors.onSuccessSoft,
      FlAlertStatus.warning => colors.onWarningSoft,
      FlAlertStatus.danger => colors.onDangerSoft,
    };
    // An error lies on the pastel `dangerSoft`, flat, as an invalid field
    // does: every error of the registry looks the same.
    final danger = status == FlAlertStatus.danger;
    Text text(String data, FlTextRole role, Color color, {FontWeight? weight, bool? heading}) => Text(
      data,
      textAlign: TextAlign.start,
      style: scale.resolve(role, heading: heading).copyWith(color: color, fontWeight: weight),
      strutStyle: scale.strut(role, inheritedFamily: family, heading: heading),
    );
    final description = this.description;
    final trailing = this.trailing;
    final content = this.content;
    final action = this.action;
    // Izydesk's `.alert`: 16 of padding, 12 between icon, text and action.
    final gap = theme.space.md;
    return Semantics(
      container: true,
      role: kIsWeb ? SemanticsRole.alert : null,
      liveRegion: !kIsWeb,
      child: FlSurface(
        variant: danger ? FlSurfaceVariant.transparent : FlSurfaceVariant.primary,
        color: danger ? Color.alphaBlend(colors.dangerSoft, colors.surfaceRaised) : null,
        padding: EdgeInsets.all(theme.space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: [
            if (showIcon)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: _iconTop),
                child: IconTheme.merge(
                  data: IconThemeData(color: status == FlAlertStatus.accent ? colors.accent : tone, size: _iconSize),
                  child:
                      icon ??
                      FlIcon(switch (status) {
                        FlAlertStatus.success => FlIcons.circleCheck,
                        FlAlertStatus.warning => FlIcons.triangleExclamation,
                        FlAlertStatus.danger => FlIcons.circleXmark,
                        FlAlertStatus.neutral || FlAlertStatus.accent => FlIcons.circleInfo,
                      }),
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _textGap,
                children: [
                  Semantics(
                    header: true,
                    child: text(
                      title,
                      FlTextRole.textBase,
                      tone,
                      weight: theme.tokens.typography.weight.medium,
                      heading: true,
                    ),
                  ),
                  if (description != null) text(description, FlTextRole.textSm, colors.onSurfaceMuted),
                  if (content != null)
                    Padding(
                      padding: EdgeInsetsDirectional.only(top: theme.space.sm - _textGap),
                      child: DefaultTextStyle.merge(
                        style: scale.resolve(FlTextRole.textSm).copyWith(color: colors.onSurfaceMuted),
                        child: content,
                      ),
                    ),
                  if (action != null)
                    Padding(
                      padding: EdgeInsetsDirectional.only(top: gap - _textGap),
                      child: action,
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The icon of Izydesk's `.alert`, 20 square.
const double _iconSize = 20;

/// The icon sits 2 below the top, centred on the title's first line.
const double _iconTop = 2;

/// Between the title and the description.
const double _textGap = 2;

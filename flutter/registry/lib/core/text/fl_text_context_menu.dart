import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fliin_ui/core/interaction/fl_focus_ring.dart';
import 'package:fliin_ui/core/interaction/fl_pressable.dart';
import 'package:fliin_ui/core/overlay/fl_anchor.dart';
import 'package:fliin_ui/core/text/fl_selection_controls.dart';
import 'package:fliin_ui/core/theme/fl_scope.dart';
import 'package:fliin_ui/core/theme/fl_typography.dart';

/// The `contextMenuBuilder` of the field built in [field].
///
/// The toolbar is placed in the root overlay, outside the field's theme,
/// reading direction and text style: they are read here, in the field's
/// context, and put back around it. [frame] returns the field's visible frame
/// (border included) in global coordinates: the toolbar sits outside it
/// rather than against the glyphs.
///
/// On iOS, when the field allows it (`SystemContextMenu.isSupportedByField`:
/// iOS 16 and later, editable field), it is the system edit menu: its "Paste"
/// does not trigger the clipboard permission alert that a button drawn by
/// Flutter causes. Elsewhere, [FlTextSelectionToolbar].
EditableTextContextMenuBuilder flTextContextMenuBuilder(BuildContext field, {Rect? Function()? frame}) {
  final theme = FlScope.of(field);
  final direction = Directionality.of(field);
  final style = DefaultTextStyle.of(field).style;
  final overhang = FlTextSelectionControls(theme).overhang;
  return (context, state) {
    if (SystemContextMenu.isSupportedByField(state)) {
      return SystemContextMenu.editableText(editableTextState: state);
    }
    final anchors = state.contextMenuAnchors;
    final box = frame?.call();
    final below = anchors.secondaryAnchor ?? anchors.primaryAnchor;
    return FlScope(
      tokens: theme.tokens,
      brightness: theme.brightness,
      platform: theme.platform,
      density: theme.density,
      child: Directionality(
        textDirection: direction,
        child: DefaultTextStyle(
          style: style,
          child: FlTextSelectionToolbar(
            anchors: anchors,
            items: state.contextMenuButtonItems,
            clearance: (
              above: math.max(overhang.above, box == null ? 0 : anchors.primaryAnchor.dy - box.top),
              below: math.max(overhang.below, box == null ? 0 : box.bottom - below.dy),
            ),
          ),
        ),
      ),
    );
  };
}

/// The label of an action, from [WidgetsLocalizations]; null for those that
/// have no label there (delete, Live Text): they are not shown.
String? _label(WidgetsLocalizations localizations, ContextMenuButtonItem item) =>
    item.label ??
    switch (item.type) {
      ContextMenuButtonType.cut => localizations.cutButtonLabel,
      ContextMenuButtonType.copy => localizations.copyButtonLabel,
      ContextMenuButtonType.paste => localizations.pasteButtonLabel,
      ContextMenuButtonType.selectAll => localizations.selectAllButtonLabel,
      ContextMenuButtonType.lookUp => localizations.lookUpButtonLabel,
      ContextMenuButtonType.searchWeb => localizations.searchWebButtonLabel,
      ContextMenuButtonType.share => localizations.shareButtonLabel,
      ContextMenuButtonType.delete || ContextMenuButtonType.liveTextInput || ContextMenuButtonType.custom => null,
    };

/// The action toolbar of a text selection ([items], usually
/// `EditableTextState.contextMenuButtonItems`), on `surfaceOverlay`.
///
/// After a tap ([anchors] has a `secondaryAnchor`), it is a row centered above
/// the selection, flipped below it when there is not enough room at the top,
/// slid into the safe area, at least [clearance] from the selection: without
/// covering the handles or the field's frame. Too many actions for the width,
/// or enlarged text, and the row wraps: every action stays one tap away,
/// without a "more" button whose label `WidgetsLocalizations` lacks. After a
/// right click, it is a list below the pointer, like a desktop menu.
///
/// Escape closes it through `EditableText`, which has focus: a toolbar button
/// that took focus would remove it from the field, and the field closes its
/// toolbar.
class FlTextSelectionToolbar extends StatelessWidget {
  /// A toolbar for [items] placed by [anchors], with no clearance around the
  /// selection by default.
  const FlTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.items,
    this.clearance = (above: 0, below: 0),
  });

  /// The selection's points: `primaryAnchor` at the top and `secondaryAnchor`
  /// at the bottom after a tap; without `secondaryAnchor` after a right click,
  /// the toolbar sits below `primaryAnchor`, the pointer.
  final TextSelectionToolbarAnchors anchors;
  /// The offered actions. An action without a `label` takes the
  /// `WidgetsLocalizations` label for its type; those whose type has none
  /// (delete, Live Text, custom) are dropped, and the toolbar renders nothing
  /// when none remain.
  final List<ContextMenuButtonItem> items;
  /// The minimum distance between the row and the selection, in logical
  /// points: `above` above `primaryAnchor`, `below` below `secondaryAnchor`.
  /// Ignored after a right click.
  final ({double above, double below}) clearance;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final localizations = WidgetsLocalizations.of(context);
    final buttons = [
      for (final item in items)
        if (_label(localizations, item) case final label?) _Button(label: label, onPressed: item.onPressed),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    final top = anchors.primaryAnchor;
    final bottom = anchors.secondaryAnchor;
    final colors = theme.colors;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        border: Border.all(color: colors.border, width: theme.size.border),
        borderRadius: BorderRadius.circular(theme.shape.radiusCard),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.size.border),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(math.max(theme.shape.radiusCard - theme.size.border, 0)),
          child: bottom == null
              ? ConstrainedBox(
                  constraints: BoxConstraints(minWidth: theme.size.menuMinWidth, maxWidth: theme.size.menuMaxWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: buttons,
                    ),
                  ),
                )
              : Wrap(children: buttons),
        ),
      ),
    );
    return FlAnchoredLayout(
      anchor: bottom == null
          ? Rect.fromPoints(top, top)
          : Rect.fromLTRB(top.dx, top.dy - clearance.above, bottom.dx, bottom.dy + clearance.below),
      side: bottom == null ? FlSide.bottom : FlSide.top,
      align: bottom == null ? FlAlign.start : FlAlign.center,
      child: Semantics(container: true, explicitChildNodes: true, child: panel),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final colors = theme.colors;
    return FlPressable(
      onPressed: onPressed,
      label: label,
      borderRadius: BorderRadius.zero,
      scaleOnPress: false,
      focusRing: FlFocusRingPlacement.inside,
      builder: (context, states) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: theme.hitTarget,
          minHeight: math.max(theme.controlHeight, theme.hitTarget),
        ),
        child: ColoredBox(
          color: states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered)
              ? colors.surfacePressed
              : colors.surfaceOverlay,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.md, vertical: theme.space.sm),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: theme.typography.resolve(FlTextRole.body).copyWith(color: colors.onSurface),
                strutStyle: theme.typography.strut(
                  FlTextRole.body,
                  inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

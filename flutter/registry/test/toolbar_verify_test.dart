import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/button_group/fl_button_group.dart';
import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/components/toggle_button/fl_toggle_button.dart';
import 'package:fliin_ui/components/toolbar/fl_toolbar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une barre sans fond de boutons à bascule et d'actions séparés par un
/// filet, une barre flottante avec un groupe de boutons, et une barre
/// verticale, comme `verify.entry`.
Widget _toolbars(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  List<Widget> actions({required bool on}) => [
    FlToggleButton.icon(
      label: tr(rtl, 'Favorite', 'مفضلة'),
      selected: on,
      variant: FlToggleButtonVariant.ghost,
      icon: FlIcon(on ? FlIcons.heartFill : FlIcons.heart),
      onChanged: (_) {},
    ),
    FlToggleButton.icon(
      label: tr(rtl, 'Save', 'حفظ'),
      selected: false,
      variant: FlToggleButtonVariant.ghost,
      icon: FlIcon(FlIcons.bookmark),
      onChanged: (_) {},
    ),
    const FlSeparator(),
    FlButton.icon(
      label: tr(rtl, 'Edit', 'تعديل'),
      variant: FlButtonVariant.ghost,
      icon: FlIcon(FlIcons.pencil),
      onPressed: () {},
    ),
    FlButton.icon(
      label: tr(rtl, 'Share', 'مشاركة'),
      variant: FlButtonVariant.ghost,
      icon: FlIcon(FlIcons.arrowUpFromSquare),
      onPressed: () {},
    ),
  ];
  return scrollPage(context, [
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlToolbar(semanticLabel: tr(rtl, 'Actions', 'إجراءات'), children: actions(on: true)),
    ),
    Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: theme.space.md),
      child: Center(
        child: FlToolbar(
          variant: FlToolbarVariant.attached,
          children: [
            FlButtonGroup(
              items: [
                FlButtonGroupItem.icon(
                  label: tr(rtl, 'Edit', 'تعديل'),
                  icon: FlIcon(FlIcons.pencil),
                  onPressed: () {},
                ),
                FlButtonGroupItem.icon(
                  label: tr(rtl, 'Share', 'مشاركة'),
                  icon: FlIcon(FlIcons.arrowUpFromSquare),
                  onPressed: () {},
                ),
              ],
            ),
            const FlSeparator(),
            FlToggleButton.icon(
              label: tr(rtl, 'Favorite', 'مفضلة'),
              selected: true,
              icon: FlIcon(FlIcons.starFill),
              onChanged: (_) {},
            ),
            FlButton.icon(
              label: tr(rtl, 'Delete', 'حذف'),
              variant: FlButtonVariant.tertiary,
              icon: FlIcon(FlIcons.trashBin),
              onPressed: () {},
            ),
          ],
        ),
      ),
    ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlToolbar(axis: Axis.vertical, children: actions(on: false)),
    ),
  ]);
}

void main() => verifyItem(
  item: 'toolbar',
  testFile: 'test/toolbar_verify_test.dart',
  size: const Size(390, 560),
  showcase: _toolbars,
);

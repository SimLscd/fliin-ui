import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/button_group/fl_button_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les variantes d'un groupe de trois, un groupe d'icônes, un groupe
/// vertical au chevron final, un groupe de bascules sur toute la largeur
/// dont l'une est choisie, et un groupe désactivé, comme `verify.entry`.
Widget _groups(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  List<FlButtonGroupItem> three() => [
    FlButtonGroupItem(label: tr(rtl, 'Copy', 'نسخ'), onPressed: () {}),
    FlButtonGroupItem(label: tr(rtl, 'Paste', 'لصق'), onPressed: () {}),
    FlButtonGroupItem(label: tr(rtl, 'Cut', 'قص'), onPressed: () {}),
  ];
  return scrollPage(context, [
    Wrap(
      spacing: theme.space.sm,
      runSpacing: theme.space.sm,
      children: [
        for (final look in [
          FlButtonVariant.primary,
          FlButtonVariant.tertiary,
          FlButtonVariant.outline,
          FlButtonVariant.ghost,
          FlButtonVariant.danger,
        ])
          FlButtonGroup(variant: look, items: three()),
        FlButtonGroup(
          semanticLabel: tr(rtl, 'Edit', 'تحرير'),
          items: [
            FlButtonGroupItem.icon(label: tr(rtl, 'Edit', 'تعديل'), icon: FlIcon(FlIcons.pencil), onPressed: () {}),
            FlButtonGroupItem.icon(
              label: tr(rtl, 'Share', 'مشاركة'),
              icon: FlIcon(FlIcons.arrowUpFromSquare),
              onPressed: () {},
            ),
            FlButtonGroupItem.icon(label: tr(rtl, 'Delete', 'حذف'), icon: FlIcon(FlIcons.trashBin), onPressed: null),
          ],
        ),
        FlButtonGroup(
          axis: Axis.vertical,
          variant: FlButtonVariant.outline,
          items: [
            FlButtonGroupItem(
              label: tr(rtl, 'Previous', 'السابق'),
              leading: FlIcon(FlIcons.chevronLeft),
              onPressed: () {},
            ),
            FlButtonGroupItem(
              label: tr(rtl, 'Next', 'التالي'),
              trailing: FlIcon(FlIcons.chevronRight),
              onPressed: () {},
            ),
          ],
        ),
      ],
    ),
    FlButtonGroup(
      expanded: true,
      items: [
        FlButtonGroupItem(label: tr(rtl, 'Day', 'يوم'), selected: false, onPressed: () {}),
        FlButtonGroupItem(label: tr(rtl, 'Week', 'أسبوع'), selected: true, onPressed: () {}),
        FlButtonGroupItem(label: tr(rtl, 'Month', 'شهر'), selected: false, onPressed: () {}),
      ],
    ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlButtonGroup(enabled: false, variant: FlButtonVariant.primary, items: three()),
    ),
  ]);
}

void main() => verifyItem(
  item: 'button-group',
  testFile: 'test/button_group_verify_test.dart',
  size: const Size(390, 600),
  showcase: _groups,
);

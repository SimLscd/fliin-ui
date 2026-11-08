import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/menu/fl_menu.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un menu ouvert sous son bouton : titre de groupe et options cochées,
/// action avec texte, action désactivée, filet, sous-menu et action
/// destructive.
Widget _menu(BuildContext context, {required bool rtl}) {
  MenuController? menu;
  return OnMount(
    open: () => menu?.open(),
    child: overlayPage(
      context,
      (context) => Align(
        alignment: AlignmentDirectional.topCenter,
        child: FlMenu(
          items: [
            FlMenuLabel(tr(rtl, 'View', 'العرض')),
            FlMenuGroup<int>(
              selection: FlMenuSelection.multiple,
              selected: const {0},
              onChanged: (_) {},
              options: [
                FlMenuOption(value: 0, label: tr(rtl, 'Previews', 'معاينات')),
                FlMenuOption(value: 1, label: tr(rtl, 'Dates', 'التواريخ')),
              ],
            ),
            const FlMenuDivider(),
            FlMenuItem(
              label: tr(rtl, 'Copy', 'نسخ'),
              description: tr(rtl, 'To the clipboard', 'إلى الحافظة'),
              onPressed: () {},
            ),
            FlMenuItem(label: tr(rtl, 'Paste', 'لصق'), onPressed: null),
            FlMenuItem(label: tr(rtl, 'Duplicate', 'تكرار'), onPressed: () {}),
            const FlMenuDivider(),
            FlSubmenu(
              label: tr(rtl, 'Share', 'مشاركة'),
              items: [FlMenuItem(label: tr(rtl, 'By email', 'بالبريد'), onPressed: () {})],
            ),
            FlMenuItem(label: tr(rtl, 'Delete', 'حذف'), destructive: true, onPressed: () {}),
          ],
          builder: (context, controller) {
            menu = controller;
            return FlButton(
              label: tr(rtl, 'Options', 'خيارات'),
              variant: FlButtonVariant.secondary,
              onPressed: controller.open,
            );
          },
        ),
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'menu',
  testFile: 'test/menu_verify_test.dart',
  size: const Size(390, 600),
  settle: overlaySettle,
  showcase: _menu,
);

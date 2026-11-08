import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/drawer/fl_drawer.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un tiroir de navigation ouvert sur une page voilée, routes posées
/// d'emblée : titre, bouton de fermeture, liens et une action en bas.
Widget _drawer(BuildContext context, {required bool rtl}) => Navigator(
  onGenerateInitialRoutes: (navigator, _) => [
    PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => columnPage(context, [
        showcaseText(context, tr(rtl, 'Recent orders', 'الطلبات الأخيرة')),
        FlButton(label: tr(rtl, 'Menu', 'القائمة'), onPressed: () {}),
      ]),
    ),
    FlDrawerRoute<void>(
      context: context,
      barrierLabel: tr(rtl, 'Close the menu', 'إغلاق القائمة'),
      builder: (context) => FlDrawer(
        title: tr(rtl, 'Navigation', 'التنقل'),
        closeLabel: tr(rtl, 'Close', 'إغلاق'),
        actions: [
          FlButton(
            label: tr(rtl, 'Sign out', 'تسجيل الخروج'),
            size: FlButtonSize.sm,
            onPressed: () => Navigator.pop(context),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: FlScope.of(context).space.lg,
          children: [
            for (final (fr, ar) in const [
              ('Home', 'الرئيسية'),
              ('Orders', 'الطلبات'),
              ('Messages', 'الرسائل'),
              ('Settings', 'الإعدادات'),
            ])
              showcaseText(context, tr(rtl, fr, ar)),
          ],
        ),
      ),
    ),
  ],
);

void main() => verifyItem(
  item: 'drawer',
  testFile: 'test/drawer_verify_test.dart',
  size: const Size(390, 640),
  settle: overlaySettle,
  showcase: _drawer,
  frameAllowances: (theme) => squareFillOnPage(theme, (c) => c.control, 1.11),
);

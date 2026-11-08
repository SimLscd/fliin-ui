import 'package:fliin_ui/components/alert/fl_alert.dart';
import 'package:fliin_ui/components/app_bar/fl_app_bar.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/page/fl_page.dart';
import 'package:fliin_ui/components/section_header/fl_section_header.dart';
import 'package:fliin_ui/components/tab_bar/fl_tab_bar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un disque à la couleur et à la taille de l'`IconTheme`.
Widget _disc() => Builder(
  builder: (context) => SizedBox.square(
    dimension: IconTheme.of(context).size! * 0.75,
    child: DecoratedBox(
      decoration: ShapeDecoration(color: IconTheme.of(context).color, shape: const CircleBorder()),
    ),
  ),
);

/// L'écran de démonstration dans un téléphone : la zone sûre de la
/// plateforme, un grand titre, deux sections de lignes et la barre
/// d'onglets.
Widget _screen(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final ios = theme.platform == TargetPlatform.iOS;
  final media = MediaQuery.of(context);
  FlListRow row(String fr, String ar, {String? value}) =>
      FlListRow(title: tr(rtl, fr, ar), value: value, trailing: const FlListRowChevron(), onPressed: () {});
  return MediaQuery(
    data: media.copyWith(
      padding: EdgeInsets.only(top: ios ? 47 : 24, bottom: ios ? 34 : 16),
      viewPadding: EdgeInsets.only(top: ios ? 47 : 24, bottom: ios ? 34 : 16),
    ),
    child: FlPage(
      appBar: FlAppBar(
        title: tr(rtl, 'Settings', 'الإعدادات'),
        titleSize: FlAppBarTitleSize.large,
        actions: [FlAppBarAction(icon: _disc(), label: tr(rtl, 'Profile', 'الملف'), onPressed: () {})],
      ),
      refresh: FlPageRefresh(label: tr(rtl, 'Refresh', 'تحديث'), onRefresh: () async {}),
      tabBar: FlBottomTabBar(
        index: 2,
        onSelected: (_) {},
        tabs: [
          for (final (fr, ar) in [('Home', 'الرئيسية'), ('Messages', 'الرسائل'), ('Settings', 'الإعدادات')])
            FlBottomTab(icon: _disc(), label: tr(rtl, fr, ar)),
        ],
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(theme.space.lg, theme.space.sm, theme.space.lg, theme.space.xl),
          sliver: SliverList.list(
            children: [
              FlSectionHeader(title: tr(rtl, 'Account', 'الحساب')),
              FlListGroup(
                children: [
                  row('Profile', 'الملف الشخصي'),
                  row('Security', 'الأمان'),
                  row('Abonnement', 'الاشتراك', value: 'Pro'),
                ],
              ),
              SizedBox(height: theme.space.xl),
              FlSectionHeader(
                title: tr(rtl, 'Preferences', 'التفضيلات'),
                action: FlSectionHeaderAction(label: tr(rtl, 'See all', 'عرض الكل'), onPressed: () {}),
              ),
              FlListGroup(
                children: [
                  row('Notifications', 'الإشعارات'),
                  row('Language', 'اللغة', value: tr(rtl, 'English', 'العربية')),
                  row('Apparence', 'المظهر'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Un écran de paiement : la barre d'action du bas, un avis au-dessus de
/// l'action.
Widget _barScreen(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final ios = theme.platform == TargetPlatform.iOS;
  final media = MediaQuery.of(context);
  return MediaQuery(
    data: media.copyWith(
      padding: EdgeInsets.only(top: ios ? 47 : 24, bottom: ios ? 34 : 16),
      viewPadding: EdgeInsets.only(top: ios ? 47 : 24, bottom: ios ? 34 : 16),
    ),
    child: FlPage(
      appBar: FlAppBar(title: tr(rtl, 'Cart', 'السلة')),
      tabBar: FlPageBar(
        info: [
          FlAlert(
            title: tr(rtl, 'Payment declined. You weren’t charged.', 'تم رفض الدفع. لم يُخصم أي مبلغ.'),
            status: FlAlertStatus.danger,
          ),
        ],
        action: FlButton(label: tr(rtl, 'Pay €137.90', 'ادفع 137٫90 €'), onPressed: () {}),
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.all(theme.space.lg),
          sliver: SliverList.list(
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: EdgeInsetsDirectional.only(bottom: theme.space.sm),
                  child: SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: theme.colors.surfaceRaised,
                        shape: FlContinuousBorder(radius: theme.shape.radiusCard),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Deux téléphones côte à côte : la page et ses onglets, puis la barre
/// d'action du bas.
Widget _screens(BuildContext context, {required bool rtl}) {
  final media = MediaQuery.of(context);
  final phone = Size(media.size.width / 2, media.size.height);
  Widget slot(Widget Function(BuildContext context, {required bool rtl}) screen) => SizedBox.fromSize(
    size: phone,
    child: MediaQuery(
      data: media.copyWith(size: phone),
      child: Builder(builder: (context) => screen(context, rtl: rtl)),
    ),
  );
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [slot(_screen), slot(_barScreen)]);
}

void main() =>
    verifyItem(item: 'page', testFile: 'test/page_verify_test.dart', size: const Size(780, 844), showcase: _screens);

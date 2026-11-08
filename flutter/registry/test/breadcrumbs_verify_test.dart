import 'package:fliin_ui/components/breadcrumbs/fl_breadcrumbs.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

List<FlBreadcrumb> _levels(List<(String, String)> names, {required bool rtl}) => [
  for (final (fr, ar) in names) FlBreadcrumb(label: tr(rtl, fr, ar), onPressed: () {}),
];

/// Un fil de quatre niveaux, un fil aux noms longs qui défile et coupe,
/// un fil replié derrière « … », et un fil désactivé, comme `verify.entry`.
Widget _trails(BuildContext context, {required bool rtl}) => scrollPage(context, [
  FlBreadcrumbs(
    semanticLabel: tr(rtl, 'Breadcrumbs', 'مسار التنقل'),
    items: _levels(const [
      ('Home', 'الرئيسية'),
      ('Products', 'المنتجات'),
      ('Electronics', 'الإلكترونيات'),
      ('Computer', 'حاسوب'),
    ], rtl: rtl),
  ),
  FlBreadcrumbs(
    items: _levels(const [
      ('Home', 'الرئيسية'),
      ('Home and garden, furniture and decor', 'المنزل والحديقة والأثاث والديكور'),
      ('Outdoor furniture', 'أثاث خارجي'),
      ('Oiled solid teak garden lounge set', 'طقم حديقة من خشب الساج'),
    ], rtl: rtl),
  ),
  FlBreadcrumbs(
    maxItems: 3,
    expandLabel: tr(rtl, 'Show the whole path', 'عرض المسار كاملا'),
    items: _levels(const [
      ('Home', 'الرئيسية'),
      ('Documents', 'المستندات'),
      ('Projects', 'المشاريع'),
      ('2026', '٢٠٢٦'),
      ('Quotes', 'العروض'),
      ('Client A', 'العميل أ'),
    ], rtl: rtl),
  ),
  FlBreadcrumbs(
    enabled: false,
    items: _levels(const [('Home', 'الرئيسية'), ('Settings', 'الإعدادات'), ('Account', 'الحساب')], rtl: rtl),
  ),
]);

void main() => verifyItem(
  item: 'breadcrumbs',
  testFile: 'test/breadcrumbs_verify_test.dart',
  size: const Size(390, 300),
  showcase: _trails,
);

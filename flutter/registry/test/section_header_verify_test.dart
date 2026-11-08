import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/section_header/fl_section_header.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Deux sections : un titre seul au-dessus d'un groupe de lignes, puis un
/// titre et son lien « Tout voir », sans autre écart que le leur.
Widget _sections(BuildContext context, {required bool rtl}) => ColoredBox(
  color: FlScope.of(context).colors.surface,
  child: Padding(
    padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlSectionHeader(title: tr(rtl, 'Account', 'الحساب')),
        FlListGroup(
          children: [
            FlListRow(title: tr(rtl, 'Profile', 'الملف الشخصي'), onPressed: () {}),
            FlListRow(title: tr(rtl, 'Security', 'الأمان'), onPressed: () {}),
          ],
        ),
        SizedBox(height: FlScope.of(context).space.xl),
        FlSectionHeader(
          title: tr(rtl, 'Recent', 'الأخيرة'),
          action: FlSectionHeaderAction(label: tr(rtl, 'See all', 'عرض الكل'), onPressed: () {}),
        ),
        FlListGroup(
          children: [FlListRow(title: tr(rtl, 'March invoice', 'فاتورة مارس'), onPressed: () {})],
        ),
      ],
    ),
  ),
);

void main() => verifyItem(
  item: 'section-header',
  testFile: 'test/section_header_verify_test.dart',
  size: const Size(390, 640),
  showcase: _sections,
);

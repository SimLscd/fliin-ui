import 'package:fliin_ui/components/table/fl_table.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  String tr(String fr, String ar) => rtl ? ar : fr;
  final people = [
    (tr('Kate Moore', 'كيت مور'), tr('CEO', 'المديرة'), tr('Active', 'نشطة'), 'kate@acme.com'),
    (tr('John Smith', 'جون سميث'), tr('CTO', 'المدير التقني'), tr('Active', 'نشط'), 'john@acme.com'),
    (tr('Sara Johnson', 'سارة جونسون'), tr('CMO', 'مديرة التسويق'), tr('On leave', 'في إجازة'), 'sara@acme.com'),
  ];
  final columns = [
    FlTableColumn<(String, String, String, String)>(
      id: 'name',
      label: tr('Name', 'الاسم'),
      text: (p) => p.$1,
      width: 132,
      sortable: true,
    ),
    FlTableColumn<(String, String, String, String)>(
      id: 'role',
      label: tr('Role', 'الدور'),
      text: (p) => p.$2,
      width: 112,
      sortable: true,
    ),
    FlTableColumn<(String, String, String, String)>(
      id: 'status',
      label: tr('Status', 'الحالة'),
      text: (p) => p.$3,
      width: 104,
    ),
    FlTableColumn<(String, String, String, String)>(
      id: 'email',
      label: tr('Email', 'البريد'),
      text: (p) => p.$4,
      width: 152,
    ),
  ];
  final labels = FlTableLabels(
    ascending: tr('Ascending', 'تصاعدي'),
    descending: tr('Descending', 'تنازلي'),
    selectAll: tr('Select all', 'تحديد الكل'),
    loading: tr('Loading', 'جارٍ التحميل'),
    empty: tr('No results', 'لا توجد نتائج'),
  );
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.lg,
        children: [
          FlTable<(String, String, String, String)>(
            label: tr('Team', 'الفريق'),
            columns: columns,
            rows: people,
            rowKey: (p) => p.$4,
            labels: labels,
            sort: (column: 'name', direction: FlSortDirection.ascending),
            onSortChanged: (_) {},
            selected: const {'john@acme.com'},
            onSelectionChanged: (_) {},
          ),
          FlTable<(String, String, String, String)>(
            label: tr('Roles', 'الأدوار'),
            variant: FlTableVariant.secondary,
            columns: columns.take(2).toList(),
            rows: people,
            rowKey: (p) => p.$4,
            labels: labels,
            sort: (column: 'role', direction: FlSortDirection.descending),
            onSortChanged: (_) {},
            loading: true,
          ),
          FlTable<(String, String, String, String)>(
            label: tr('Team', 'الفريق'),
            layout: FlTableLayout.stacked,
            columns: columns,
            rows: people.take(2).toList(),
            rowKey: (p) => p.$4,
            labels: labels,
            selected: const {'kate@acme.com'},
            onSelectionChanged: (_) {},
          ),
          FlTable<(String, String, String, String)>(
            label: tr('Invitations', 'الدعوات'),
            columns: columns.take(2).toList(),
            rows: const [],
            rowKey: (p) => p.$4,
            labels: labels,
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'table',
  testFile: 'test/table_verify_test.dart',
  size: const Size(390, 1000),
  settle: const Duration(milliseconds: 400),
  showcase: _showcase,
);

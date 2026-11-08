import 'package:fliin_ui/components/pagination/fl_pagination.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

String _digits(bool rtl, int n) =>
    rtl ? '$n'.replaceAllMapped(RegExp('[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]) : '$n';

/// La première page avec les libellés de précédent et suivant, une page au
/// milieu de vingt entre deux ellipses, les petites et grandes tailles, un
/// résumé au-dessus, précédent et suivant seuls, et une pagination
/// désactivée, comme `verify.entry`.
Widget _paginations(BuildContext context, {required bool rtl}) {
  FlPagination pages(
    int page,
    int count, {
    FlPaginationSize size = FlPaginationSize.md,
    bool labels = false,
    bool numbers = true,
    String? summary,
    bool enabled = true,
  }) => FlPagination(
    page: page,
    pageCount: count,
    onChanged: enabled ? (_) {} : null,
    previousLabel: tr(rtl, 'Previous', 'السابق'),
    nextLabel: tr(rtl, 'Next', 'التالي'),
    pageLabel: (n) => tr(rtl, 'Page ${_digits(rtl, n)}', 'الصفحة ${_digits(rtl, n)}'),
    format: (n) => _digits(rtl, n),
    size: size,
    showNavLabels: labels,
    showPages: numbers,
    summary: summary,
  );
  // `space.xl` apart: a compact row is shorter than its touch targets, which
  // would otherwise reach the row above.
  return scrollPage(context, [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: FlScope.of(context).space.xl,
      children: [
        pages(1, 3, labels: true),
        pages(6, 20),
        pages(2, 3, size: FlPaginationSize.sm),
        pages(2, 3, size: FlPaginationSize.lg),
        pages(3, 12, summary: tr(rtl, '21–30 of 120 results', '٢١–٣٠ من ١٢٠ نتيجة')),
        pages(2, 5, numbers: false),
        pages(2, 5, enabled: false),
      ],
    ),
  ]);
}

void main() => verifyItem(
  item: 'pagination',
  testFile: 'test/pagination_verify_test.dart',
  size: const Size(390, 600),
  showcase: _paginations,
);

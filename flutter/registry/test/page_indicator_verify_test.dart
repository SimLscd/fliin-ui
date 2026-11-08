import 'package:fliin_ui/components/page_indicator/fl_page_indicator.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// La première page, une page du milieu et la dernière, puis une suite de
/// sept pages, toutes au toucher.
Widget _indicators(BuildContext context, {required bool rtl}) {
  String label(int page, int count) => tr(rtl, 'Page $page of $count', 'الصفحة $page من $count');
  final name = tr(rtl, 'Introduction', 'العرض');
  return columnPage(context, [
    for (final (count, index) in [(3, 0), (3, 1), (3, 2), (7, 4)])
      // Une rangée par cible tactile : les cibles ne se chevauchent pas.
      SizedBox(
        height: FlScope.of(context).hitTarget,
        child: Center(
          child: FlPageIndicator(count: count, index: index, semanticLabel: name, pageLabel: label, onChanged: (_) {}),
        ),
      ),
  ]);
}

void main() => verifyItem(
  item: 'page-indicator',
  testFile: 'test/page_indicator_verify_test.dart',
  size: const Size(390, 600),
  showcase: _indicators,
);

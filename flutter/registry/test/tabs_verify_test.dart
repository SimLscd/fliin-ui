import 'package:fliin_ui/components/tabs/fl_tabs.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les deux variantes, le deuxième onglet choisi et son contenu dessous, puis
/// un onglet désactivé entre deux séparateurs.
Widget _tabs(BuildContext context, {required bool rtl}) {
  final labels = [tr(rtl, 'Messages', 'الرسائل'), tr(rtl, 'Calls', 'المكالمات'), tr(rtl, 'Contacts', 'جهات الاتصال')];
  final controller = FlTabController(length: labels.length, initialIndex: 1);
  return columnPage(context, [
    FlTabs(controller: controller, labels: labels),
    FlTabView(
      controller: controller,
      children: [
        for (final label in labels)
          showcaseText(context, tr(rtl, 'Nothing in “$label”.', 'لا توجد عناصر في «$label».')),
      ],
    ),
    SizedBox(height: FlScope.of(context).space.md),
    FlTabs(
      controller: FlTabController(length: labels.length),
      labels: labels,
      variant: FlTabsVariant.secondary,
    ),
    SizedBox(height: FlScope.of(context).space.md),
    FlTabs(
      controller: FlTabController(length: labels.length),
      labels: labels,
      disabled: const {1},
      separators: true,
    ),
  ]);
}

void main() =>
    verifyItem(item: 'tabs', testFile: 'test/tabs_verify_test.dart', size: const Size(390, 720), showcase: _tabs);

import 'package:fliin_ui/components/combo_box/fl_combo_box.dart';
import 'package:fliin_ui/components/select/fl_select.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un combo-box désactivé sur un choix, puis un combo-box qui a le focus,
/// sa liste ouverte sur toutes les villes, dont une avec sa région.
Widget _comboBoxes(BuildContext context, {required bool rtl}) {
  final cities = rtl
      ? const [('بريستول', null), ('ليدز', null), ('يورك', null), ('لندن', 'إنجلترا')]
      : const [('Bristol', null), ('Leeds', null), ('York', null), ('London', 'England')];
  String count(int count) => tr(rtl, '$count suggestions', '$count اقتراحات');
  final empty = tr(rtl, 'No city', 'لا توجد مدينة');
  final loading = tr(rtl, 'Searching…', 'جارٍ البحث…');
  final failed = tr(rtl, 'The search failed', 'تعذّر البحث');
  return overlayPage(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: FlScope.of(context).space.md,
      children: [
        FlComboBox<int>(
          label: tr(rtl, 'Country', 'البلد'),
          triggerLabel: tr(rtl, 'All countries', 'كل البلدان'),
          value: FlSelectOption(value: 0, label: tr(rtl, 'United Kingdom', 'المملكة المتحدة')),
          onChanged: null,
          suggestions: (_) => const [],
          countText: count,
          emptyText: empty,
          loadingText: loading,
          errorText: failed,
        ),
        FlComboBox<int>(
          autofocus: true,
          label: tr(rtl, 'City', 'المدينة'),
          placeholder: tr(rtl, 'Search for a city', 'ابحث عن مدينة'),
          triggerLabel: tr(rtl, 'All cities', 'كل المدن'),
          value: FlSelectOption(value: 0, label: cities.first.$1),
          onChanged: (_) {},
          suggestions: (query) => [
            for (final (i, (name, region)) in cities.indexed)
              if (name.toLowerCase().contains(query.toLowerCase()))
                FlSelectOption(value: i, label: name, description: region),
          ],
          countText: count,
          emptyText: empty,
          loadingText: loading,
          errorText: failed,
        ),
      ],
    ),
  );
}

void main() => verifyItem(
  item: 'combo-box',
  testFile: 'test/combo_box_verify_test.dart',
  size: const Size(390, 600),
  settle: overlaySettle,
  showcase: _comboBoxes,
);

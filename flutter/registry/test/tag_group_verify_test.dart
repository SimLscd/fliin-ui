import 'package:fliin_ui/components/tag_group/fl_tag_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

const _fr = ['News', 'Travel', 'Games', 'Cooking', 'Sports'];
const _ar = ['أخبار', 'سفر', 'ألعاب', 'طبخ', 'رياضة'];

/// Les trois tailles en sélection multiple, une étiquette désactivée, et
/// des étiquettes retirables sur le fond `surface`, puis un groupe nommé à
/// icônes et son aide, et un groupe en erreur.
Widget _groups(BuildContext context, {required bool rtl}) {
  final labels = rtl ? _ar : _fr;
  final space = FlScope.of(context).space;
  return columnPage(context, [
    for (final size in FlTagSize.values)
      FlTagGroup<int>(
        tags: [for (final (i, label) in labels.indexed) FlTag(i, label, disabled: i == 4)],
        size: size,
        selection: FlTagSelection.multiple,
        selected: const {1, 2},
        onSelectionChanged: (_) {},
      ),
    SizedBox(height: space.sm),
    FlTagGroup<int>(
      tags: [for (final (i, label) in labels.take(3).indexed) FlTag(i, label)],
      variant: FlTagGroupVariant.surface,
      onRemove: (_) {},
      removeLabel: (label) => tr(rtl, 'Remove $label', 'إزالة $label'),
    ),
    SizedBox(height: space.sm),
    FlTagGroup<int>(
      label: tr(rtl, 'Categories', 'الفئات'),
      description: tr(rtl, 'One at a time', 'فئة واحدة في كل مرة'),
      tags: [
        for (final (i, (label, icon)) in [
          (labels[0], FlIcons.bell),
          (labels[1], FlIcons.mapPin),
          (labels[3], FlIcons.heart),
        ].indexed)
          FlTag(i, label, leading: FlIcon(icon)),
      ],
      selection: FlTagSelection.single,
      selected: const {1},
      onSelectionChanged: (_) {},
    ),
    FlTagGroup<int>(
      label: tr(rtl, 'Amenities', 'المرافق'),
      error: tr(rtl, 'Choose at least one', 'اختر واحدًا على الأقل'),
      tags: [for (final (i, label) in labels.take(3).indexed) FlTag(i, label)],
      selection: FlTagSelection.multiple,
      onSelectionChanged: (_) {},
    ),
  ]);
}

void main() => verifyItem(
  item: 'tag-group',
  testFile: 'test/tag_group_verify_test.dart',
  size: const Size(390, 1900),
  showcase: _groups,
);

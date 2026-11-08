import 'package:fliin_ui/components/segmented/fl_segmented.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une pastille ronde à la couleur et à la moitié de la taille de
/// l'`IconTheme`, à la place d'une icône d'app.
Widget _dot(BuildContext context) {
  final icon = IconTheme.of(context);
  return Center(
    child: SizedBox.square(
      dimension: icon.size! / 2,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: icon.color, shape: const CircleBorder()),
      ),
    ),
  );
}

/// Les trois tailles, deux, trois et cinq segments, les icônes, un segment
/// désactivé, un groupe désactivé, puis deux groupes à leur propre largeur,
/// dont un d'icônes seules.
Widget _groups(BuildContext context, {required bool rtl}) {
  List<FlSegment<String>> segments(List<(String, String)> labels, {Set<int> disabled = const {}, bool icons = false}) =>
      [
        for (final (i, (fr, ar)) in labels.indexed)
          FlSegment(
            value: fr,
            label: tr(rtl, fr, ar),
            disabled: disabled.contains(i),
            icon: icons ? Builder(builder: _dot) : null,
          ),
      ];
  return columnPage(context, [
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'Period', 'الفترة'),
      value: 'Week',
      onChanged: (_) {},
      segments: segments([('Day', 'يوم'), ('Week', 'أسبوع'), ('Month', 'شهر')]),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'Billing', 'الفوترة'),
      value: 'Yearly',
      size: FlSegmentedSize.sm,
      onChanged: (_) {},
      segments: segments([('Monthly', 'شهري'), ('Yearly', 'سنوي')]),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'View', 'العرض'),
      value: 'Grid',
      size: FlSegmentedSize.lg,
      onChanged: (_) {},
      segments: segments([('List', 'قائمة'), ('Grid', 'شبكة'), ('Map', 'خريطة')], icons: true),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'Duration', 'المدة'),
      value: '30 d',
      onChanged: (_) {},
      segments: segments(
        [('7 d', '٧ أيام'), ('30 d', '٣٠ يومًا'), ('90 d', '٩٠ يومًا'), ('6 mo', '٦ أشهر'), ('1 year', 'سنة')],
        disabled: {3},
      ),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'Theme', 'السمة'),
      value: 'Light',
      enabled: false,
      onChanged: (_) {},
      segments: segments([('Light', 'فاتح'), ('Dark', 'داكن')]),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'Sort', 'الترتيب'),
      value: 'Recent',
      expand: false,
      onChanged: (_) {},
      segments: segments([('Recent', 'الأحدث'), ('Populaires', 'الأشهر')]),
    ),
    FlSegmented<String>(
      semanticLabel: tr(rtl, 'View', 'العرض'),
      value: 'Grid',
      expand: false,
      onChanged: (_) {},
      segments: [
        for (final (fr, ar) in [('List', 'قائمة'), ('Grid', 'شبكة'), ('Map', 'خريطة')])
          FlSegment(
            value: fr,
            label: tr(rtl, fr, ar),
            icon: Builder(builder: _dot),
            iconOnly: true,
          ),
      ],
    ),
  ]);
}

void main() => verifyItem(
  item: 'segmented',
  testFile: 'test/segmented_verify_test.dart',
  size: const Size(390, 1100),
  showcase: _groups,
);

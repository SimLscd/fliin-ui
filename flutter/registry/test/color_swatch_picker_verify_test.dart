import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// La palette de démonstration : les sept teintes de la doc de HeroUI, un
/// blanc et un noir.
const _palette = [
  ('Pink', 'وردي', Color(0xFFF43F5E)),
  ('Fuchsia', 'فوشيا', Color(0xFFD946EF)),
  ('Purple', 'بنفسجي', Color(0xFF8B5CF6)),
  ('Blue', 'أزرق', Color(0xFF3B82F6)),
  ('Cyan', 'سماوي', Color(0xFF06B6D4)),
  ('Emerald', 'زمردي', Color(0xFF10B981)),
  ('Lime', 'ليموني', Color(0xFF84CC16)),
  ('White', 'أبيض', Color(0xFFFAFAFA)),
  ('Black', 'أسود', Color(0xFF18181B)),
];

/// Ronde md avec une teinte désactivée, carrée lg, sm désactivée, et deux
/// pastilles seules.
Widget _pickers(BuildContext context, {required bool rtl}) {
  final items = [
    for (final (fr, ar, color) in _palette)
      FlColorSwatchItem(value: fr, color: color, label: tr(rtl, fr, ar), disabled: fr == 'Cyan'),
  ];
  return Localizations(
    locale: Locale(rtl ? 'ar' : 'en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Directionality(
      textDirection: Directionality.of(context),
      child: Builder(
        builder: (context) => ColoredBox(
          color: FlScope.of(context).colors.surface,
          child: Padding(
            padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FlScope.of(context).space.xl,
              children: [
                FlColorSwatchPicker<String>(
                  semanticLabel: tr(rtl, 'Color', 'اللون'),
                  value: 'Purple',
                  onChanged: (_) {},
                  items: items,
                ),
                FlColorSwatchPicker<String>(
                  semanticLabel: tr(rtl, 'Label color', 'لون الملصق'),
                  value: 'Lime',
                  size: FlColorSwatchSize.lg,
                  shape: FlColorSwatchShape.square,
                  onChanged: (_) {},
                  items: items,
                ),
                FlColorSwatchPicker<String>(
                  semanticLabel: tr(rtl, 'Calendar color', 'لون التقويم'),
                  value: 'White',
                  size: FlColorSwatchSize.sm,
                  enabled: false,
                  onChanged: (_) {},
                  items: items,
                ),
                Row(
                  spacing: FlScope.of(context).space.sm,
                  children: [
                    FlColorSwatch(color: const Color(0xFF3B82F6), label: tr(rtl, 'Blue', 'أزرق')),
                    FlColorSwatch(
                      color: const Color(0xFFFAFAFA),
                      label: tr(rtl, 'White', 'أبيض'),
                      shape: FlColorSwatchShape.square,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'color-swatch-picker',
  testFile: 'test/color_swatch_picker_verify_test.dart',
  size: const Size(390, 520),
  showcase: _pickers,
);

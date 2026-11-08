import 'package:fliin_ui/components/color_picker/fl_color_picker.dart';
import 'package:fliin_ui/components/color_swatch_picker/fl_color_swatch_picker.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  String tr(String fr, String ar) => rtl ? ar : fr;
  final labels = FlColorPickerLabels(
    saturation: tr('Saturation', 'التشبع'),
    brightness: tr('Brightness', 'السطوع'),
    hue: tr('Hue', 'الصبغة'),
    alpha: tr('Opacity', 'العتامة'),
    hex: tr('Hexadecimal', 'ست عشري'),
    swatches: tr('Presets', 'ألوان جاهزة'),
  );
  final presets = [
    for (final (fr, ar, hue, s, v) in const [
      ('Pink', 'وردي', 350.0, 0.74, 0.96),
      ('Purple', 'بنفسجي', 258.0, 0.64, 0.96),
      ('Blue', 'أزرق', 217.0, 0.76, 0.96),
      ('Cyan', 'سماوي', 189.0, 0.97, 0.83),
      ('Emerald', 'زمردي', 160.0, 0.9, 0.73),
      ('Amber', 'كهرماني', 38.0, 0.92, 0.96),
    ])
      FlColorSwatchItem<Color>(
        value: HSVColor.fromAHSV(1, hue, s, v).toColor(),
        color: HSVColor.fromAHSV(1, hue, s, v).toColor(),
        label: tr(fr, ar),
      ),
  ];
  return Localizations(
    locale: Locale(rtl ? 'ar' : 'en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => ColoredBox(
            color: FlScope.of(context).colors.surface,
            child: Padding(
              padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: FlScope.of(context).space.lg,
                  children: [
                    FlColorPicker(
                      label: tr('Choose a color', 'اختر لونًا'),
                      value: const HSVColor.fromAHSV(1, 217, 0.76, 0.96),
                      labels: labels,
                      swatches: presets,
                      showField: true,
                      showAlpha: true,
                      defaultOpen: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 520),
                    FlColorPicker(
                      label: tr('Label color', 'لون الملصق'),
                      value: const HSVColor.fromAHSV(1, 160, 0.9, 0.73),
                      labels: labels,
                      onChanged: (_) {},
                    ),
                    FlColorPicker(
                      label: tr('Locked color', 'لون مقفل'),
                      value: const HSVColor.fromAHSV(1, 350, 0.74, 0.96),
                      labels: labels,
                      onChanged: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() => verifyItem(
  item: 'color-picker',
  testFile: 'test/color_picker_verify_test.dart',
  size: const Size(390, 900),
  settle: const Duration(milliseconds: 400),
  showcase: _showcase,
);

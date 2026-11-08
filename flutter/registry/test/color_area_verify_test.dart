import 'package:fliin_ui/components/color_area/fl_color_area.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  String tr(String fr, String ar) => rtl ? ar : fr;
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.lg,
        children: [
          FlColorArea(
            value: const HSVColor.fromAHSV(1, 291, 0.45, 0.8),
            xLabel: tr('Saturation', 'التشبع'),
            yLabel: tr('Brightness', 'السطوع'),
            onChanged: (_) {},
          ),
          Row(
            spacing: theme.space.lg,
            children: [
              Expanded(
                child: FlColorArea(
                  value: const HSVColor.fromAHSV(1, 200, 1, 0.9),
                  xChannel: FlColorChannel.hue,
                  yChannel: FlColorChannel.saturation,
                  showDots: true,
                  xLabel: tr('Hue', 'الصبغة'),
                  yLabel: tr('Saturation', 'التشبع'),
                  onChanged: (_) {},
                ),
              ),
              Expanded(
                child: FlColorArea(
                  value: const HSVColor.fromAHSV(1, 140, 0.6, 0.7),
                  xLabel: tr('Saturation', 'التشبع'),
                  yLabel: tr('Brightness', 'السطوع'),
                  onChanged: null,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'color-area',
  testFile: 'test/color_area_verify_test.dart',
  size: const Size(390, 600),
  showcase: _showcase,
);

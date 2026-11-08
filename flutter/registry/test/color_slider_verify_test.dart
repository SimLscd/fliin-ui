import 'package:fliin_ui/components/color_slider/fl_color_slider.dart';
import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  String tr(String fr, String ar) => rtl ? ar : fr;
  const red = HSVColor.fromAHSV(1, 0, 1, 1);
  const blue = HSVColor.fromAHSV(0.5, 217, 0.76, 0.96);
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.lg,
        children: [
          FlColorSlider(value: red, channel: FlColorChannel.hue, label: tr('Hue', 'الصبغة'), onChanged: (_) {}),
          FlColorSlider(
            value: red,
            channel: FlColorChannel.saturation,
            space: FlColorSpace.hsl,
            label: tr('Saturation', 'التشبع'),
            onChanged: (_) {},
          ),
          FlColorSlider(
            value: red,
            channel: FlColorChannel.lightness,
            space: FlColorSpace.hsl,
            label: tr('Lightness', 'الإضاءة'),
            onChanged: (_) {},
          ),
          FlColorSlider(value: blue, channel: FlColorChannel.alpha, label: tr('Opacity', 'العتامة'), onChanged: (_) {}),
          FlColorSlider(
            value: blue,
            channel: FlColorChannel.brightness,
            label: tr('Brightness', 'السطوع'),
            onChanged: null,
          ),
          SizedBox(
            height: 160,
            child: Row(
              spacing: theme.space.xl,
              children: [
                FlColorSlider(
                  value: blue,
                  channel: FlColorChannel.hue,
                  axis: Axis.vertical,
                  showLabel: false,
                  label: tr('Hue', 'الصبغة'),
                  onChanged: (_) {},
                ),
                FlColorSlider(
                  value: blue,
                  channel: FlColorChannel.alpha,
                  axis: Axis.vertical,
                  label: tr('Opacity', 'العتامة'),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'color-slider',
  testFile: 'test/color_slider_verify_test.dart',
  size: const Size(390, 700),
  showcase: _showcase,
);

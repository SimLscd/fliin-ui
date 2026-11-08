import 'package:fliin_ui/components/slider/fl_slider.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

void _noop(Object _) {}

/// Légendé, à crans, désactivé, focalisé au clavier, une plage, des repères
/// sous la piste, et trois curseurs verticaux, dont un à repères.
Widget _sliders(BuildContext context, {required bool rtl}) => columnPage(context, [
  for (final (fr, ar, value, divisions, enabled, autofocus) in [
    ('Volume', 'مستوى الصوت', 0.4, null, true, false),
    ('Brightness', 'السطوع', 0.75, 4, true, false),
    ('Contrast', 'التباين', 0.6, null, false, false),
    ('Vitesse', 'السرعة', 0.2, null, true, true),
  ])
    FlSlider(
      value: value,
      divisions: divisions,
      label: tr(rtl, fr, ar),
      showLabel: true,
      autofocus: autofocus,
      onChanged: enabled ? _noop : null,
    ),
  FlRangeSlider(
    values: (start: 20, end: 70),
    min: 0,
    max: 100,
    label: tr(rtl, 'Price', 'السعر'),
    startLabel: tr(rtl, 'Minimum price', 'أدنى سعر'),
    endLabel: tr(rtl, 'Maximum price', 'أعلى سعر'),
    valueLabel: (value) => tr(rtl, '€${value.round()}', '${value.round()} €'),
    showLabel: true,
    onChanged: _noop,
  ),
  FlSlider(
    value: 40,
    max: 100,
    label: tr(rtl, 'Sound', 'الصوت'),
    showLabel: true,
    valueLabel: (value) => '${value.round()}',
    marks: [
      FlSliderMark(0, tr(rtl, 'Mute', 'صامت')),
      FlSliderMark(50, tr(rtl, 'Medium', 'متوسط')),
      FlSliderMark(100, tr(rtl, 'Max', 'الأقصى')),
    ],
    onChanged: _noop,
  ),
  SizedBox(
    height: 120,
    child: Row(
      spacing: FlScope.of(context).space.xl,
      children: [
        FlSlider(value: 0.6, label: tr(rtl, 'Bass', 'الجهير'), axis: Axis.vertical, onChanged: _noop),
        FlRangeSlider(
          values: (start: 0.3, end: 0.8),
          label: tr(rtl, 'Range', 'النطاق'),
          startLabel: tr(rtl, 'Low', 'الأدنى'),
          endLabel: tr(rtl, 'High', 'الأعلى'),
          axis: Axis.vertical,
          onChanged: _noop,
        ),
        FlSlider(
          value: 0.4,
          divisions: 10,
          label: tr(rtl, 'Treble', 'الحدة'),
          axis: Axis.vertical,
          marks: const [FlSliderMark(0), FlSliderMark(0.5), FlSliderMark(1)],
          onChanged: _noop,
        ),
      ],
    ),
  ),
]);

void main() => verifyItem(
  item: 'slider',
  testFile: 'test/slider_verify_test.dart',
  size: const Size(390, 1100),
  showcase: _sliders,
);

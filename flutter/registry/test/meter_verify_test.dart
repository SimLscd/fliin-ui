import 'package:fliin_ui/components/meter/fl_meter.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une jauge à la valeur écrite en clair, une par taille et par couleur
/// d'état, la neutre, et une sans libellé, comme `verify.entry`.
Widget _meters(BuildContext context, {required bool rtl}) => scrollPage(context, [
  FlMeter(
    label: tr(rtl, 'Storage', 'التخزين'),
    value: 64,
    valueLabel: (_) => tr(rtl, '6.4 GB of 10', '٦٫٤ من ١٠ غ.ب'),
  ),
  for (final (size, color, value, fr, ar) in [
    (FlMeterSize.sm, FlMeterColor.success, 82.0, 'Battery', 'البطارية'),
    (FlMeterSize.md, FlMeterColor.warning, 88.0, 'Data plan', 'الباقة'),
    (FlMeterSize.lg, FlMeterColor.danger, 97.0, 'Disk', 'القرص'),
  ])
    FlMeter(label: tr(rtl, fr, ar), value: value, size: size, color: color),
  FlMeter(label: tr(rtl, 'Strong passwords', 'كلمات مرور قوية'), value: 3, max: 4, color: FlMeterColor.neutral),
  FlMeter(label: tr(rtl, 'Memory', 'الذاكرة'), value: 40, showLabel: false),
]);

void main() =>
    verifyItem(item: 'meter', testFile: 'test/meter_verify_test.dart', size: const Size(390, 400), showcase: _meters);

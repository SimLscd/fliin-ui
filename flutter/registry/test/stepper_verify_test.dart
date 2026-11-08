import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/stepper/fl_stepper.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

String _digits(bool rtl, int n) =>
    rtl ? '$n'.replaceAllMapped(RegExp('[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]) : '$n';

/// Quatre compteurs au bout de leur ligne, comme `verify.entry` : au milieu,
/// à la borne basse, à la borne haute, désactivé ; puis deux compteurs à
/// boutons ronds cernés, l'un à la borne basse, l'autre par pas de 15.
Widget _steppers(BuildContext context, {required bool rtl}) => scrollPage(context, [
  FlListGroup(
    children: [
      for (final (title, subtitle, value, min, max, enabled) in [
        (tr(rtl, 'Adults', 'البالغون'), tr(rtl, '13 and older', '١٣ سنة فأكثر'), 2, 1, 6, true),
        (tr(rtl, 'Children', 'الأطفال'), tr(rtl, 'Ages 2 to 12', 'من ٢ إلى ١٢ سنة'), 0, 0, 4, true),
        (tr(rtl, 'Infants', 'الرضّع'), tr(rtl, 'Under 2', 'أقل من سنتين'), 2, 0, 2, true),
        (tr(rtl, 'Pets', 'الحيوانات'), null, 1, 0, 2, false),
      ])
        FlListRow(
          title: title,
          subtitle: subtitle,
          enabled: enabled,
          trailing: FlStepper(
            label: title,
            value: value,
            min: min,
            max: max,
            decrementLabel: tr(rtl, 'Fewer', 'أقل'),
            incrementLabel: tr(rtl, 'Plus', 'أكثر'),
            format: (n) => _digits(rtl, n),
            onChanged: enabled ? (_) {} : null,
          ),
        ),
    ],
  ),
  FlListGroup(
    children: [
      for (final (title, value, min) in [
        (tr(rtl, 'Rooms', 'الغرف'), 1, 1),
        (tr(rtl, 'Duration (min)', 'المدة (دقيقة)'), 30, 15),
      ])
        FlListRow(
          title: title,
          trailing: FlStepper(
            label: title,
            value: value,
            min: min,
            max: 120,
            step: min,
            variant: FlStepperVariant.outline,
            decrementLabel: tr(rtl, 'Fewer', 'أقل'),
            incrementLabel: tr(rtl, 'Plus', 'أكثر'),
            format: (n) => _digits(rtl, n),
            onChanged: (_) {},
          ),
        ),
    ],
  ),
]);

void main() => verifyItem(
  item: 'stepper',
  testFile: 'test/stepper_verify_test.dart',
  settle: overlaySettle,
  size: const Size(390, 600),
  showcase: _steppers,
);

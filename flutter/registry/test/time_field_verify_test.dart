import 'package:fliin_ui/components/time_field/fl_time_field.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Sur 24 heures en français, sur 12 en arabe : un champ au focus sur son
/// premier segment vide, un champ rempli, un champ requis décrit, un
/// invalide et un désactivé.
Widget _fields(BuildContext context, {required bool rtl}) {
  final strings = FlDateFieldStrings.language(rtl ? 'ar' : 'en');
  return scrollPage(context, [
    FlTimeField(
      label: tr(rtl, 'Appointment time', 'وقت الموعد'),
      value: null,
      onChanged: (_) {},
      autofocus: true,
      strings: strings,
    ),
    FlTimeField(label: tr(rtl, 'Alarm', 'المنبّه'), value: const FlTime(7, 30), onChanged: (_) {}, strings: strings),
    FlTimeField(
      label: tr(rtl, 'Arrival time', 'وقت الوصول'),
      description: tr(rtl, 'Local time', 'التوقيت المحلي'),
      required: true,
      value: null,
      onChanged: (_) {},
      strings: strings,
    ),
    FlTimeField(
      label: tr(rtl, 'Pickup', 'الاستلام'),
      error: tr(rtl, 'The store closes at 7 PM', 'يغلق المتجر الساعة ٧ مساءً'),
      value: const FlTime(20, 15),
      onChanged: (_) {},
      strings: strings,
    ),
    FlTimeField(label: tr(rtl, 'Departure', 'المغادرة'), value: const FlTime(14, 5), onChanged: null, strings: strings),
  ]);
}

void main() => verifyItem(
  item: 'time-field',
  testFile: 'test/time_field_verify_test.dart',
  size: const Size(390, 640),
  showcase: _fields,
);

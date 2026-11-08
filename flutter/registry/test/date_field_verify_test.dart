import 'package:fliin_ui/components/date_field/fl_date_field.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un champ au focus sur son premier segment vide, un champ rempli, un
/// champ requis décrit, un invalide, un désactivé, et un champ secondaire
/// précédé d'un mot, sans icône.
Widget _fields(BuildContext context, {required bool rtl}) {
  final strings = FlDateFieldStrings.language(rtl ? 'ar' : 'en');
  return scrollPage(context, [
    FlDateField(
      label: tr(rtl, 'Date of birth', 'تاريخ الميلاد'),
      value: null,
      onChanged: (_) {},
      autofocus: true,
      strings: strings,
    ),
    FlDateField(
      label: tr(rtl, 'Expiry date', 'تاريخ الانتهاء'),
      value: DateTime(2031, 3, 9),
      onChanged: (_) {},
      strings: strings,
    ),
    FlDateField(
      label: tr(rtl, 'Arrival date', 'تاريخ الوصول'),
      description: tr(rtl, 'As shown on the ticket', 'كما هو مدوّن على التذكرة'),
      required: true,
      value: null,
      onChanged: (_) {},
      strings: strings,
    ),
    FlDateField(
      label: tr(rtl, 'Delivery date', 'تاريخ التسليم'),
      error: tr(rtl, 'This date has passed', 'هذا التاريخ مضى'),
      value: DateTime(2026, 10, 2),
      onChanged: (_) {},
      strings: strings,
    ),
    FlDateField(
      label: tr(rtl, 'Send date', 'تاريخ الإرسال'),
      value: DateTime(2026, 10, 14),
      onChanged: null,
      strings: strings,
    ),
    FlDateField(
      label: tr(rtl, 'Due date', 'الموعد النهائي'),
      value: DateTime(2026, 11, 30),
      onChanged: (_) {},
      leading: Text(tr(rtl, 'On', 'في')),
      showIcon: false,
      variant: FlInputVariant.secondary,
      strings: strings,
    ),
  ]);
}

void main() => verifyItem(
  item: 'date-field',
  testFile: 'test/date_field_verify_test.dart',
  size: const Size(390, 760),
  showcase: _fields,
);

import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un sélecteur ouvert sur sa date, en popover ; puis un sélecteur requis
/// sans date, un invalide et un désactivé.
Widget _pickers(BuildContext context, {required bool rtl}) {
  final strings = FlCalendarStrings.language(rtl ? 'ar' : 'en');
  final today = DateTime(2026, 10, 24);
  return overlayPage(
    context,
    (context) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: FlScope.of(context).space.lg,
        children: [
          FlDatePicker(
            label: tr(rtl, 'Appointment date', 'تاريخ الموعد'),
            placeholder: tr(rtl, 'Choose a date', 'اختر تاريخًا'),
            clearLabel: tr(rtl, 'Clear the date', 'مسح التاريخ'),
            value: DateTime(2026, 10, 14),
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            defaultOpen: true,
            today: today,
            strings: strings,
          ),
          const SizedBox(height: 330),
          FlDatePicker(
            label: tr(rtl, 'Delivery date', 'تاريخ التسليم'),
            placeholder: tr(rtl, 'Choose a date', 'اختر تاريخًا'),
            description: tr(rtl, 'Monday to Friday', 'من الاثنين إلى الجمعة'),
            required: true,
            value: null,
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            today: today,
            strings: strings,
          ),
          FlDatePicker(
            label: tr(rtl, 'Return date', 'تاريخ العودة'),
            placeholder: tr(rtl, 'Choose a date', 'اختر تاريخًا'),
            error: tr(rtl, 'This date has passed', 'هذا التاريخ مضى'),
            value: DateTime(2026, 10, 2),
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            today: today,
            strings: strings,
          ),
          FlDatePicker(
            label: tr(rtl, 'Send date', 'تاريخ الإرسال'),
            placeholder: tr(rtl, 'Choose a date', 'اختر تاريخًا'),
            value: DateTime(2026, 10, 14),
            onChanged: null,
            presentation: FlDatePickerPresentation.popover,
            today: today,
            strings: strings,
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'date-picker',
  testFile: 'test/date_picker_verify_test.dart',
  size: const Size(390, 900),
  settle: overlaySettle,
  showcase: _pickers,
);

import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/components/date_range_picker/fl_date_range_picker.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un sélecteur de période ouvert sur sa période, en popover ; puis un
/// sélecteur requis sans période, un invalide et un désactivé.
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
          FlDateRangePicker(
            label: tr(rtl, 'Stay dates', 'تواريخ الإقامة'),
            placeholder: tr(rtl, 'Check-in – check-out', 'الوصول – المغادرة'),
            clearLabel: tr(rtl, 'Clear the dates', 'مسح التواريخ'),
            value: FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16)),
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            defaultOpen: true,
            today: today,
            strings: strings,
          ),
          const SizedBox(height: 360),
          FlDateRangePicker(
            label: tr(rtl, 'Time off', 'الإجازة'),
            placeholder: tr(rtl, 'Start – end', 'البداية – النهاية'),
            description: tr(rtl, 'Five days at most', 'خمسة أيام على الأكثر'),
            required: true,
            value: null,
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            today: today,
            strings: strings,
          ),
          FlDateRangePicker(
            label: tr(rtl, 'Rental', 'الاستئجار'),
            placeholder: tr(rtl, 'Start – end', 'البداية – النهاية'),
            error: tr(rtl, 'The vehicle is already rented', 'السيارة مستأجرة بالفعل'),
            value: FlDateRange(DateTime(2026, 10, 20), DateTime(2026, 10, 22)),
            onChanged: (_) {},
            presentation: FlDatePickerPresentation.popover,
            today: today,
            strings: strings,
          ),
          FlDateRangePicker(
            label: tr(rtl, 'Report period', 'فترة التقرير'),
            placeholder: tr(rtl, 'Start – end', 'البداية – النهاية'),
            value: FlDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 7)),
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
  item: 'date-range-picker',
  testFile: 'test/date_range_picker_verify_test.dart',
  size: const Size(390, 1000),
  settle: overlaySettle,
  showcase: _pickers,
);

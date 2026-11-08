import 'package:fliin_ui/components/calendar/fl_calendar.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Le jour choisi et aujourd'hui, les bornes et les week-ends indisponibles,
/// la grille des années ouverte, le calendrier désactivé, et les points des
/// jours prévus (`indicatorOf`), dont le jour choisi.
Widget _calendars(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final strings = FlCalendarStrings.language(rtl ? 'ar' : 'en');
  final today = DateTime(2026, 10, 24);
  Widget box(Widget child) => SizedBox(width: 320, child: child);
  return ColoredBox(
    color: theme.colors.surface,
    child: Padding(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Wrap(
        spacing: theme.space.lg,
        runSpacing: theme.space.lg,
        children: [
          box(
            FlCalendar(
              value: DateTime(2026, 10, 14),
              onChanged: (_) {},
              today: today,
              strings: strings,
              semanticLabel: tr(rtl, 'Appointment date', 'تاريخ الموعد'),
            ),
          ),
          box(
            FlCalendar(
              value: null,
              onChanged: (_) {},
              today: today,
              focusedDate: today,
              minDate: DateTime(2026, 10, 8),
              maxDate: DateTime(2026, 10, 28),
              isUnavailable: (day) => day.weekday == DateTime.saturday || day.weekday == DateTime.sunday,
              strings: strings,
              semanticLabel: tr(rtl, 'Delivery date', 'تاريخ التسليم'),
            ),
          ),
          box(
            FlCalendar(
              value: DateTime(2026, 10, 14),
              onChanged: (_) {},
              today: today,
              defaultYearPickerOpen: true,
              strings: strings,
              semanticLabel: tr(rtl, 'Date of birth', 'تاريخ الميلاد'),
            ),
          ),
          box(
            FlCalendar(
              value: DateTime(2026, 10, 14),
              onChanged: (_) {},
              today: today,
              enabled: false,
              strings: strings,
              semanticLabel: tr(rtl, 'Date', 'التاريخ'),
            ),
          ),
          box(
            FlCalendar(
              value: DateTime(2026, 10, 15),
              onChanged: (_) {},
              today: today,
              indicatorOf: (day) => const {3, 7, 15, 21, 28}.contains(day.day) ? tr(rtl, 'Meeting', 'اجتماع') : null,
              strings: strings,
              semanticLabel: tr(rtl, 'Meeting date', 'تاريخ الاجتماع'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'calendar',
  testFile: 'test/calendar_verify_test.dart',
  size: const Size(760, 1780),
  showcase: _calendars,
);

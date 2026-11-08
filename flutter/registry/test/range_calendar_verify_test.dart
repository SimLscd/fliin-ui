import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une période sur deux semaines, une période qui finit le mois suivant, une
/// semaine entre deux week-ends indisponibles, et une période d'un jour près
/// d'une borne, et un début posé en attente de la fin.
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
            FlRangeCalendar(
              value: FlDateRange(DateTime(2026, 10, 8), DateTime(2026, 10, 19)),
              onChanged: (_) {},
              today: today,
              strings: strings,
              semanticLabel: tr(rtl, 'Stay dates', 'تواريخ الإقامة'),
            ),
          ),
          box(
            FlRangeCalendar(
              value: FlDateRange(DateTime(2026, 10, 27), DateTime(2026, 11, 4)),
              onChanged: (_) {},
              today: today,
              focusedDate: DateTime(2026, 10, 27),
              weeksInMonth: 6,
              strings: strings,
              semanticLabel: tr(rtl, 'Rental dates', 'تواريخ الاستئجار'),
            ),
          ),
          box(
            FlRangeCalendar(
              value: FlDateRange(DateTime(2026, 10, 12), DateTime(2026, 10, 16)),
              onChanged: (_) {},
              today: today,
              isUnavailable: (day) => day.weekday == DateTime.saturday || day.weekday == DateTime.sunday,
              strings: strings,
              semanticLabel: tr(rtl, 'Work week', 'أسبوع العمل'),
            ),
          ),
          box(
            FlRangeCalendar(
              value: FlDateRange(DateTime(2026, 10, 21), DateTime(2026, 10, 21)),
              onChanged: (_) {},
              today: today,
              minDate: DateTime(2026, 10, 5),
              strings: strings,
              semanticLabel: tr(rtl, 'Period', 'الفترة'),
            ),
          ),
          box(
            FlRangeCalendar(
              value: null,
              initialStart: DateTime(2026, 10, 12),
              onChanged: (_) {},
              today: today,
              strings: strings,
              semanticLabel: tr(rtl, 'Vacation dates', 'تواريخ الإجازة'),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'range-calendar',
  testFile: 'test/range_calendar_verify_test.dart',
  size: const Size(760, 2000),
  showcase: _calendars,
);

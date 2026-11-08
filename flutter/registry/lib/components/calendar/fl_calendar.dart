// Modified from the Calendar of HeroUI React v3, Copyright 2020 Next UI Inc.,
// licensed under the MIT license below and under Apache 2.0:
// https://www.apache.org/licenses/LICENSE-2.0
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_view.dart';

/// The choice of a day in a month's grid: the
/// month and year at the top (which open the year choice), the previous and
/// next month buttons, the days of the week, then the days. The chosen day
/// is a `selected` disc, today a semibold digit without a disc; the days of
/// neighboring months are faded, those outside [minDate] and [maxDate]
/// struck through, and those [isUnavailable] refuses faded.
///
/// The names of the months and days, the first day of the week and the
/// digits come from [strings] (`FlCalendarStrings`), in the app's language
/// by default. The keyboard, the screen reader and the motion are those of
/// [FlCalendarView].
class FlCalendar extends StatelessWidget {
  /// A calendar whose chosen day is [value].
  const FlCalendar({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusedDate,
    this.today,
    this.minDate,
    this.maxDate,
    this.isUnavailable,
    this.firstDayOfWeek,
    this.strings,
    this.weeksInMonth,
    this.showYearPicker = true,
    this.defaultYearPickerOpen = false,
    this.enabled = true,
    this.autofocus = false,
    this.semanticLabel,
    this.onMonthChanged,
    this.indicatorOf,
  });

  /// The chosen day, without time; null before the first choice.
  final DateTime? value;

  /// Receives the tapped day, `DateTime(year, month, day)` in local time;
  /// the parent passes it back in [value].
  final ValueChanged<DateTime> onChanged;

  /// The cursor's day at the start, and its month; [value], otherwise
  /// today, by default.
  final DateTime? focusedDate;

  /// See [FlCalendarView.today].
  final DateTime? today;

  /// See [FlCalendarView.minDate].
  final DateTime? minDate;

  /// See [FlCalendarView.maxDate].
  final DateTime? maxDate;

  /// See [FlCalendarView.isUnavailable].
  final bool Function(DateTime day)? isUnavailable;

  /// See [FlCalendarView.firstDayOfWeek].
  final int? firstDayOfWeek;

  /// See [FlCalendarView.strings].
  final FlCalendarStrings? strings;

  /// See [FlCalendarView.weeksInMonth].
  final int? weeksInMonth;

  /// See [FlCalendarView.showYearPicker].
  final bool showYearPicker;

  /// See [FlCalendarView.defaultYearPickerOpen].
  final bool defaultYearPickerOpen;

  /// See [FlCalendarView.enabled].
  final bool enabled;

  /// See [FlCalendarView.autofocus].
  final bool autofocus;

  /// See [FlCalendarView.semanticLabel].
  final String? semanticLabel;

  /// See [FlCalendarView.onMonthChanged].
  final ValueChanged<DateTime>? onMonthChanged;

  /// See [FlCalendarView.indicatorOf].
  final String? Function(DateTime day)? indicatorOf;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return FlCalendarView(
      markOf: (day) => selected != null && flSameDay(day, selected) ? FlDayMark.selected : FlDayMark.none,
      onDayPressed: onChanged,
      focusedDate: focusedDate ?? selected,
      today: today,
      minDate: minDate,
      maxDate: maxDate,
      isUnavailable: isUnavailable,
      firstDayOfWeek: firstDayOfWeek,
      strings: strings,
      weeksInMonth: weeksInMonth,
      showYearPicker: showYearPicker,
      defaultYearPickerOpen: defaultYearPickerOpen,
      enabled: enabled,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
      onMonthChanged: onMonthChanged,
      indicatorOf: indicatorOf,
    );
  }
}

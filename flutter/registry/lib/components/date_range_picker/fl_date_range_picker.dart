// Modified from the DateRangePicker of HeroUI React v3, Copyright 2020 Next UI
// Inc., licensed under the MIT license below and under Apache 2.0:
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
import 'package:fliin_ui/components/date_picker/fl_date_picker.dart';
import 'package:fliin_ui/components/range_calendar/fl_range_calendar.dart';

/// What joins the start and the end in the field
/// (`date-range-picker__range-separator`): an en dash, with no word to
/// translate.
const String _rangeSeparator = ' – ';

/// The choice of a period from a form field: the field of `FlDatePicker`, which writes the start
/// and the end in full ("Monday, October 12, 2026 – Friday, October 16,
/// 2026") and opens a [FlRangeCalendar], as a sheet on a phone and as a
/// popover on a tablet.
///
/// The first tap sets the start: the calendar circles it and reads it as
/// "start set, choose the end", and nothing is sent to the app. The second
/// returns the period to [onChanged] and closes the calendar. A start set
/// without an end is not a value: the field keeps the app's period, and
/// closing the calendar (barrier, swipe, Escape) abandons it; reopened, the
/// calendar starts again from the app's period. The clear button returns
/// `null`.
class FlDateRangePicker extends StatelessWidget {
  /// A picker whose selected period is [value].
  const FlDateRangePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.placeholder,
    this.description,
    this.error,
    this.required = false,
    this.clearLabel,
    this.barrierLabel,
    this.presentation,
    this.strings,
    this.today,
    this.minDate,
    this.maxDate,
    this.isUnavailable,
    this.unit = FlRangeUnit.days,
    this.firstDayOfWeek,
    this.defaultOpen = false,
    this.onMonthChanged,
    this.format,
    this.variant = FlInputVariant.primary,
    this.indicatorOf,
  }) : assert(
         presentation == FlDatePickerPresentation.popover || barrierLabel != null,
         'the sheet closes through its barrier, which must be named',
       );

  /// The field's name, and that of the open calendar.
  final String label;

  /// True: the calendar opens on first render (React Aria's `defaultOpen`).
  final bool defaultOpen;

  /// The selected period; null with no selection.
  final FlDateRange? value;

  /// Receives the period on the second tap, or `null` when the user
  /// clears; null disables the field.
  final ValueChanged<FlDateRange?>? onChanged;

  /// The field's text with no period.
  final String placeholder;

  /// The help under the field.
  final String? description;

  /// When non-null: the field is invalid, and this text replaces [description].
  final String? error;

  /// True: an asterisk follows the label, and the field announces itself required.
  final bool required;

  /// The name of the button that clears the period; when null, no button.
  final String? clearLabel;

  /// The name of the sheet's barrier, which closes it; required except as a popover.
  final String? barrierLabel;

  /// Where the calendar opens; when null, [flDatePickerPresentationOf].
  final FlDatePickerPresentation? presentation;

  /// The texts of the calendar and the field; those of the app's language by
  /// default.
  final FlCalendarStrings? strings;

  /// See `FlCalendarView.today`.
  final DateTime? today;

  /// See `FlCalendarView.minDate`.
  final DateTime? minDate;

  /// See `FlCalendarView.maxDate`.
  final DateTime? maxDate;

  /// See [FlRangeCalendar.isUnavailable].
  final bool Function(DateTime day)? isUnavailable;

  /// See [FlRangeCalendar.unit]: in nights, the day whose night is taken
  /// remains a possible departure.
  final FlRangeUnit unit;

  /// See `FlCalendarView.firstDayOfWeek`.
  final int? firstDayOfWeek;

  /// Receives the month the open calendar shows, on opening then on each
  /// change: the app loads that month's unavailable days into it, and they
  /// arrive in the open calendar. See `FlCalendarView.onMonthChanged`.
  final ValueChanged<DateTime>? onMonthChanged;

  /// How the field writes each end of the period, joined by an en dash; by default in full,
  /// `FlCalendarStrings.date`.
  final String Function(DateTime date)? format;

  /// The field's look: `primary` on the page, `secondary` on a surface.
  final FlInputVariant variant;

  /// See `FlCalendarView.indicatorOf`.
  final String? Function(DateTime day)? indicatorOf;

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? FlCalendarStrings.of(context);
    final format = this.format ?? strings.date;
    final value = this.value;
    final onChanged = this.onChanged;
    return FlDatePickerOverlay(
      label: label,
      barrierLabel: barrierLabel,
      presentation: presentation,
      defaultOpen: defaultOpen,
      calendar: (context, close) => FlRangeCalendar(
        value: value,
        onChanged: (range) {
          onChanged?.call(range);
          close();
        },
        autofocus: true,
        today: today,
        minDate: minDate,
        maxDate: maxDate,
        isUnavailable: isUnavailable,
        unit: unit,
        firstDayOfWeek: firstDayOfWeek,
        strings: strings,
        semanticLabel: label,
        onMonthChanged: onMonthChanged,
        indicatorOf: indicatorOf,
      ),
      field: (context, open, toggle) => FlDatePickerField(
        label: label,
        text: value == null ? null : '${format(value.start)}$_rangeSeparator${format(value.end)}',
        variant: variant,
        placeholder: placeholder,
        open: open,
        onOpen: onChanged == null ? null : toggle,
        description: description,
        error: error,
        required: required,
        clearLabel: clearLabel,
        onClear: clearLabel == null || onChanged == null ? null : () => onChanged(null),
      ),
    );
  }
}

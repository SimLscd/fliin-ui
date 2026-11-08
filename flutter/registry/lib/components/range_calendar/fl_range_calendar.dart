// Modified from the RangeCalendar of HeroUI React v3, Copyright 2020 Next UI
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
import 'package:fliin_ui/components/calendar/fl_calendar_view.dart';

/// The farthest an unavailable day is searched for around the start of a
/// range: ten years.
const int _gapSearch = 3660;

/// What a range consumes, and therefore what `isUnavailable` means.
enum FlRangeUnit {
  /// Its days, both ends included (time off): an unavailable day neither
  /// starts, ends, nor is crossed by any range.
  days,

  /// Its nights, from the start's night to the eve of the end (a stay):
  /// `isUnavailable` says a night is taken, named by the day it starts on.
  /// The end doesn't consume its night: a day whose night is taken remains a
  /// possible departure when the previous night is free. That "departure
  /// only" day can't be an arrival, and a range crosses no taken night.
  nights,
}

/// A range from [start] to [end], both included, in days without time.
final class FlDateRange {
  /// A range whose [end] isn't before [start].
  FlDateRange(DateTime start, DateTime end) : start = flDateOnly(start), end = flDateOnly(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError.value(end, 'end', 'before the start $start');
    }
  }

  /// The range between two days, whichever order they come in.
  factory FlDateRange.between(DateTime a, DateTime b) => b.isBefore(a) ? FlDateRange(b, a) : FlDateRange(a, b);

  /// The first day.
  final DateTime start;

  /// The last day, [start] for a one-day range.
  final DateTime end;

  /// True when [day] is in the range, both ends included.
  bool contains(DateTime day) {
    final date = flDateOnly(day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  @override
  bool operator ==(Object other) => other is FlDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'FlDateRange($start, $end)';
}

/// The choice of a range in a month's grid:
/// the first tap sets the start, the second the end, and the range is
/// painted as a `surfaceSecondary` ribbon between two `selected` discs. The
/// ribbon rounds off at the edge of each week.
///
/// A second tap before the start swaps the two: the range runs from the
/// tapped day to the first one. That's what React Aria does, and the two
/// taps always state the intended range; starting over would silently
/// discard the first. While picking, the first day is only circled and read
/// "start set": nothing is highlighted until the app has received the
/// range. Escape abandons it. A range doesn't pass over an unavailable day:
/// after the first tap, days beyond the nearest unavailable one can no
/// longer be picked. In nights ([unit]), the day whose night is taken can
/// still be picked as the end, if it is reached without crossing a taken
/// night.
///
/// The rest (month, year, keyboard, screen reader, motion, texts) is that
/// of [FlCalendarView], the grid of `FlCalendar`.
class FlRangeCalendar extends StatefulWidget {
  /// A calendar whose picked range is [value].
  const FlRangeCalendar({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusedDate,
    this.initialStart,
    this.today,
    this.minDate,
    this.maxDate,
    this.isUnavailable,
    this.unit = FlRangeUnit.days,
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

  /// The picked range; null before the first pick.
  final FlDateRange? value;

  /// Receives the range on the second tap; the parent passes it back in
  /// [value].
  final ValueChanged<FlDateRange> onChanged;

  /// The cursor's initial day, and its month; by default the start of
  /// [value], otherwise today. A range set by the app in another month also
  /// takes the grid there.
  final DateTime? focusedDate;

  /// A first day already tapped at the outset, awaiting the second (a sheet
  /// reopened mid-pick); null by default. In nights, a day whose night is
  /// taken isn't an arrival: it is ignored.
  final DateTime? initialStart;

  /// See [FlCalendarView.today].
  final DateTime? today;

  /// See [FlCalendarView.minDate].
  final DateTime? minDate;

  /// See [FlCalendarView.maxDate].
  final DateTime? maxDate;

  /// True for a day no range takes; in nights ([unit]), for a day whose
  /// night is taken. See [FlCalendarView.isUnavailable].
  final bool Function(DateTime day)? isUnavailable;

  /// What a range consumes: its days by default, its nights for a stay,
  /// where the day whose night is taken remains a possible departure,
  /// underlined and read "departure only" ([FlCalendarStrings.departureOnly],
  /// then required).
  final FlRangeUnit unit;

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
  State<FlRangeCalendar> createState() => _FlRangeCalendarState();
}

class _FlRangeCalendarState extends State<FlRangeCalendar> {
  /// The month shown: the start of [FlRangeCalendar.value] at first, then
  /// that of a range set by the app. A range returned through `onChanged`
  /// doesn't change it: the grid stays where the user closed the range.
  late DateTime? _focus = widget.initialStart ?? widget.value?.start;

  /// The last range returned through `onChanged`.
  FlDateRange? _emitted;

  /// The first day tapped, awaiting the second. It is only circled: the app
  /// hasn't received it, and the screen never shows a range the app doesn't
  /// have.
  late DateTime? _anchor = switch (widget.initialStart) {
    final start? when _canStart(flDateOnly(start)) => flDateOnly(start),
    _ => null,
  };

  /// The nearest unavailable days before and after [_anchor].
  DateTime? _gapBefore;
  DateTime? _gapAfter;

  @override
  void initState() {
    super.initState();
    final anchor = _anchor;
    if (anchor != null) _findGaps(anchor);
  }

  bool _unavailable(DateTime day) => widget.isUnavailable?.call(day) ?? false;

  bool get _nights => widget.unit == FlRangeUnit.nights;

  /// True when [day] can be the set start: available (in nights, its night
  /// is free) and within bounds.
  bool _canStart(DateTime day) {
    final min = widget.minDate;
    final max = widget.maxDate;
    return !_unavailable(day) &&
        (min == null || !day.isBefore(flDateOnly(min))) &&
        (max == null || !day.isAfter(flDateOnly(max)));
  }

  /// In nights, a day whose night is taken and whose previous night is free,
  /// within bounds: a range can end there.
  bool _departureOnly(DateTime day) {
    if (!_nights || !_unavailable(day)) return false;
    final eve = DateTime(day.year, day.month, day.day - 1);
    final min = widget.minDate;
    final max = widget.maxDate;
    return !_unavailable(eve) &&
        (min == null || !eve.isBefore(flDateOnly(min))) &&
        (max == null || !day.isAfter(flDateOnly(max)));
  }

  /// The nearest unavailable day after [from] in the direction of [step],
  /// searched up to the bound, or ten years at most.
  DateTime? _nearestGap(DateTime from, int step) {
    final bound = step > 0 ? widget.maxDate : widget.minDate;
    for (var i = 1; i <= _gapSearch; i++) {
      final day = DateTime(from.year, from.month, from.day + step * i);
      if (bound != null && (step > 0 ? day.isAfter(flDateOnly(bound)) : day.isBefore(flDateOnly(bound)))) {
        break;
      }
      if (_unavailable(day)) return day;
    }
    return null;
  }

  void _findGaps(DateTime anchor) {
    _gapBefore = _nearestGap(anchor, -1);
    _gapAfter = _nearestGap(anchor, 1);
  }

  void _forget() => _anchor = _gapBefore = _gapAfter = null;

  @override
  void didUpdateWidget(FlRangeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != oldWidget.value) {
      _forget();
      if (value != null && value != _emitted) _focus = value.start;
      return;
    }
    final anchor = _anchor;
    if (anchor != null &&
        (widget.isUnavailable != oldWidget.isUnavailable ||
            widget.minDate != oldWidget.minDate ||
            widget.maxDate != oldWidget.maxDate)) {
      // A start that became taken or out of bounds is dropped, as on
      // closing: the range it would open would start on it.
      if (_canStart(anchor)) {
        _findGaps(anchor);
      } else {
        _forget();
      }
    }
  }

  FlDayMark _markOf(DateTime day) {
    final range = widget.value;
    if (range == null || !range.contains(day)) return FlDayMark.none;
    final start = flSameDay(day, range.start);
    final end = flSameDay(day, range.end);
    return switch ((start, end)) {
      (true, true) => FlDayMark.rangeSingle,
      (true, false) => FlDayMark.rangeStart,
      (false, true) => FlDayMark.rangeEnd,
      (false, false) => FlDayMark.rangeMiddle,
    };
  }

  void _press(DateTime day) {
    final anchor = _anchor;
    if (anchor == null) {
      setState(() {
        _anchor = day;
        _findGaps(day);
      });
      return;
    }
    // In nights, the same day twice would make a stay with no night: the
    // second tap drops the start, like Escape.
    if (_nights && flSameDay(anchor, day)) {
      setState(_forget);
      return;
    }
    final range = FlDateRange.between(anchor, day);
    setState(_forget);
    _emitted = range;
    widget.onChanged(range);
  }

  /// True for a day that can't be picked now: unavailable, or, after the
  /// first tap, beyond the nearest unavailable one. In nights, that nearest
  /// one after the start is the farthest end: the range doesn't consume its
  /// night.
  bool _blocked(DateTime day) {
    final before = _gapBefore;
    final after = _gapAfter;
    final anchor = _anchor;
    if (anchor == null) return _unavailable(day);
    if (after != null && _nights && day.isAfter(anchor)) {
      return day.isAfter(after);
    }
    return _unavailable(day) || (before != null && !day.isAfter(before)) || (after != null && !day.isBefore(after));
  }

  @override
  Widget build(BuildContext context) {
    assert(
      !_nights || (widget.strings ?? FlCalendarStrings.of(context)).departureOnly != null,
      'FlRangeCalendar in nights: strings.departureOnly reads the "departure only" day',
    );
    return FlCalendarView(
      range: true,
      markOf: _markOf,
      pendingStart: _anchor,
      onDayPressed: _press,
      onEscape: () {
        if (_anchor == null) return false;
        setState(_forget);
        return true;
      },
      focusedDate: widget.focusedDate ?? _focus,
      today: widget.today,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      isUnavailable: _blocked,
      isDepartureOnly: _nights ? _departureOnly : null,
      firstDayOfWeek: widget.firstDayOfWeek,
      strings: widget.strings,
      weeksInMonth: widget.weeksInMonth,
      showYearPicker: widget.showYearPicker,
      defaultYearPickerOpen: widget.defaultYearPickerOpen,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      semanticLabel: widget.semanticLabel,
      onMonthChanged: widget.onMonthChanged,
      indicatorOf: widget.indicatorOf,
    );
  }
}

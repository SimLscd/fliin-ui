// Modified from the Calendar, RangeCalendar and CalendarYearPicker of HeroUI
// React v3, Copyright 2020 Next UI Inc., licensed under the MIT license below
// and under Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0
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
//
// Also modified from the theme colors of HeroUI Native 1.0.10, Copyright 2025
// NextUI Inc., licensed under Apache 2.0.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fliin_ui/components/calendar/fl_calendar_strings.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

/// The side of a day (Izydesk's `.cal-d > span`), and of a column when the
/// width is unbounded. A wider column centers it.
const double _cell = 40;

/// The height of the month row (Izydesk's `.cal-head`).
const double _headHeight = 40;

/// The velocity beyond which a drag shorter than a column still changes
/// the month, in logical points per second.
const double _flingVelocity = 300;

/// The top and bottom margin of a day cell (`my-[2px]`, Izydesk's
/// `row-gap: 4px`).
const double _rangeGap = 2;

/// The scale of a pressed day: `scale(0.95)` for a day, `scale: 0.9` for a
/// period day.
const double _pressedScale = 0.95;
const double _rangePressedScale = 0.9;

/// The side of the month buttons' icon, of their round button and of the
/// year chevron (Izydesk's `.cal-nav` and `.cal-month`).
const double _navIcon = 16;
const double _navButton = 32;
const double _yearChevron = 16;

/// The minimum height of a year (Izydesk's `.cal-years`) and the number of
/// columns of the year grid.
const double _yearHeight = 40;
const int _yearColumns = 3;

/// The share of `selected` in the period ribbon and today's disc: 15 % in
/// light, a little more in dark, where 12 % barely shows on the warm grays.
const double _softLight = 0.15;
const double _softDark = 0.2;

/// The soft `selected`: `selected` at [_softLight] or [_softDark].
Color _soft(FlTheme theme) => theme.colors.selected.withValues(
  alpha: theme.colors.selected.a * (theme.brightness == Brightness.dark ? _softDark : _softLight),
);

/// The years offered without bounds.
const int _firstYear = 1900;
const int _lastYear = 2099;

/// The delay of the years' appearance relative to the days' disappearance
/// (`opacity 200ms … 50ms`), as a share of their total duration.
const double _yearsDelay = 0.2;

/// A day without time, in local time: that of `DateTime(year, month,
/// day)`, the form of the dates that the calendars receive and return.
DateTime flDateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

/// True when [a] and [b] are the same day.
bool flSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

DateTime _addMonths(DateTime month, int count) => DateTime(month.year, month.month + count);

int _monthIndex(DateTime day) => day.year * 12 + day.month - 1;

int _daysIn(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// Day [day] of [month], clamped to the last day of a shorter month.
DateTime _dayIn(DateTime month, int day) => DateTime(month.year, month.month, math.min(day, _daysIn(month)));

/// The number of days of the previous month shown before the first.
int _lead(DateTime month, int firstDay) => (month.weekday - firstDay + 7) % 7;

int _weeksOf(DateTime month, int firstDay) => ((_lead(month, firstDay) + _daysIn(month)) / 7).ceil();

/// What a day is in the selection: the grid paints it accordingly.
enum FlDayMark {
  /// Outside the selection.
  none,

  /// The chosen day of a single calendar: a `selected` disc.
  selected,

  /// The first day of a period, an end of the band.
  rangeStart,

  /// A day inside a range, on the soft `selected` ribbon.
  rangeMiddle,

  /// The last day of a period, an end of the band.
  rangeEnd,

  /// A single-day period: a disc, without a band.
  rangeSingle;

  bool get _cap => this != none && this != rangeMiddle;

  bool get _track => this == rangeStart || this == rangeMiddle || this == rangeEnd;
}

/// The grid of a month and its header, shared by `FlCalendar` and
/// `FlRangeCalendar`: the month and the year (which open the year choice),
/// the previous and next month buttons, the days of the week, then the
/// days. It does not know what is chosen: [markOf] tells it for each day,
/// and [onDayPressed] receives the day tapped or activated by keyboard.
///
/// The month slides to the next or the previous one on the `spatialSlow`
/// spring, through the button, a finger drag and the keyboard; under
/// reduced motion, it changes at once. A month change is announced to the
/// screen reader.
///
/// On the keyboard, the grid is a single Tab stop, on the cursor's day: the
/// arrows move from day to day (left and right flipped in RTL), up and down
/// by a week, Page Up and Page Down by a month (by a year with Shift), Home
/// and End to the bounds of the week, Enter and Space select. A key that
/// would change nothing bubbles up.
///
/// The grid takes the whole given width, in seven equal columns; each day
/// is a disc of 40 centered in its column (the column's width when
/// narrower), and its touch target extends to 44 or 48 through
/// `FlHitTarget`. Without a bounded width, the grid is 280 wide.
class FlCalendarView extends StatefulWidget {
  /// A grid that paints each day according to [markOf].
  const FlCalendarView({
    super.key,
    required this.markOf,
    required this.onDayPressed,
    this.pendingStart,
    this.onEscape,
    this.range = false,
    this.focusedDate,
    this.today,
    this.minDate,
    this.maxDate,
    this.isUnavailable,
    this.isDepartureOnly,
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
  }) : assert(weeksInMonth == null || weeksInMonth >= 4 && weeksInMonth <= 6, 'from 4 to 6 weeks'),
       assert(
         firstDayOfWeek == null || firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'from 1 (Monday) to 7',
       );

  /// What [day] is in the selection.
  final FlDayMark Function(DateTime day) markOf;

  /// Receives the day tapped, or activated by keyboard, when it can be chosen.
  final ValueChanged<DateTime> onDayPressed;

  /// The first day of a range tapped, waiting for the second: ringed in
  /// `selected`, read "start set". It is not a selection: the app has not
  /// received it, and [markOf] does not mark it.
  final DateTime? pendingStart;

  /// Called on Escape; returns true if it did something, and the key
  /// bubbles up otherwise.
  final bool Function()? onEscape;

  /// True: the shape of a period (40-high cells, band, month buttons with
  /// `xl` corners, pressed day at 0.9).
  final bool range;

  /// The cursor's day at the start, and the month shown; today by default.
  /// Another value given later takes the grid there, without sliding.
  final DateTime? focusedDate;

  /// The day marked as today; the clock's by default.
  final DateTime? today;

  /// The first and the last day that can be chosen. The others are struck
  /// through, and the months outside the bounds are not shown.
  final DateTime? minDate;

  /// See [minDate].
  final DateTime? maxDate;

  /// True for a day that cannot be chosen (full, closed): faded, not
  /// tappable, read as "unavailable".
  final bool Function(DateTime day)? isUnavailable;

  /// True for a day whose night is taken but which remains a possible
  /// departure (`FlRangeCalendar` in nights): its number is underlined, and
  /// it is read as "departure only". Whether it can be chosen remains up to
  /// [isUnavailable].
  final bool Function(DateTime day)? isDepartureOnly;

  /// The first day of the week, from `DateTime.monday` to `DateTime.sunday`;
  /// that of [strings] by default.
  final int? firstDayOfWeek;

  /// The names and words of the calendar; those of the language of the
  /// nearest `Localizations` by default.
  final FlCalendarStrings? strings;

  /// The number of weeks of each month, for a fixed height from one month
  /// to the next (6); when null, the month's own.
  final int? weeksInMonth;

  /// True: the month and the year open the year grid.
  final bool showYearPicker;

  /// True: the year grid is open at the start, in place of the days.
  final bool defaultYearPickerOpen;

  /// False: the whole calendar is faded and struck through, with no touch or focus.
  final bool enabled;

  /// True: the grid takes the focus on first render, on the cursor's day,
  /// if nothing else in its scope has it (a calendar that opens in a
  /// popover or a sheet).
  final bool autofocus;

  /// The grid's name for the screen reader ("Appointment date"), read
  /// before the month.
  final String? semanticLabel;

  /// Receives the first day of the month the grid shows, on first render
  /// then on each month change (buttons, drag, keyboard, year grid, value or
  /// bounds changed by the app), after the frame: the app loads into it
  /// what depends on the month, like its unavailable days. The same month
  /// is reported only once in a row.
  final ValueChanged<DateTime>? onMonthChanged;

  /// A dot under the number of [day] when it returns a text (a day with
  /// events), in `onSurfaceMuted`, in
  /// `onSelected` on a chosen day. The screen reader reads the text after
  /// the date ("2 events"); an empty text draws the dot alone. Null: no dot.
  final String? Function(DateTime day)? indicatorOf;

  @override
  State<FlCalendarView> createState() => _FlCalendarViewState();
}

class _FlCalendarViewState extends State<FlCalendarView> with TickerProviderStateMixin {
  late DateTime _cursor = _clamp(flDateOnly(widget.focusedDate ?? widget.today ?? DateTime.now()));
  late DateTime _month = _monthOf(_cursor);

  /// The month that leaves during a slide; when null, nothing slides.
  DateTime? _from;
  late final AnimationController _slide = AnimationController(vsync: this, value: 1);

  late bool _yearsOpen = widget.showYearPicker && widget.defaultYearPickerOpen;
  late final AnimationController _days = AnimationController(vsync: this, value: _yearsOpen ? 0 : 1);
  late final AnimationController _years = AnimationController(vsync: this, value: _yearsOpen ? 1 : 0);
  ScrollController? _yearScroll;
  late int _yearCursor = _month.year;

  late final FocusNode _grid = FocusNode(debugLabel: 'FlCalendarView grid', onKeyEvent: _gridKey);
  late final FocusNode _yearGrid = FocusNode(debugLabel: 'FlCalendarView years', onKeyEvent: _yearKey);
  late final FocusNode _previous = FocusNode(debugLabel: 'FlCalendarView previous');
  late final FocusNode _next = FocusNode(debugLabel: 'FlCalendarView next');
  bool _gridHighlight = false;

  /// Rereads the clock at the next midnight when the app does not give [today].
  Timer? _midnight;
  bool _yearHighlight = false;
  DateTime? _pressed;
  DateTime? _hovered;
  int? _pressedYear;
  double _drag = 0;

  DateTime? get _min => widget.minDate == null ? null : flDateOnly(widget.minDate!);
  DateTime? get _max => widget.maxDate == null ? null : flDateOnly(widget.maxDate!);

  DateTime _clamp(DateTime day) {
    final min = _min;
    final max = _max;
    if (min != null && day.isBefore(min)) return min;
    if (max != null && day.isAfter(max)) return max;
    return day;
  }

  bool _outOfBounds(DateTime day) {
    final min = _min;
    final max = _max;
    return !widget.enabled || (min != null && day.isBefore(min)) || (max != null && day.isAfter(max));
  }

  bool _selectable(DateTime day) => !_outOfBounds(day) && !(widget.isUnavailable?.call(day) ?? false);

  bool _canShow(DateTime month) {
    final min = _min;
    final max = _max;
    return (min == null || _monthIndex(month) >= _monthIndex(min)) &&
        (max == null || _monthIndex(month) <= _monthIndex(max));
  }

  @override
  void didUpdateWidget(FlCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focused = widget.focusedDate;
    final before = oldWidget.focusedDate;
    final bounds = widget.minDate != oldWidget.minDate || widget.maxDate != oldWidget.maxDate;
    if (focused != null && (before == null || !flSameDay(focused, before))) {
      _jump(flDateOnly(focused));
    } else if (bounds && !_canShow(_month)) {
      _jump(_cursor);
    } else if (bounds) {
      _cursor = _clamp(_cursor);
    }
    if (_yearsOpen && (!widget.enabled || !widget.showYearPicker)) {
      _yearsOpen = false;
      _years.value = 0;
      _days.value = 1;
      _yearScroll?.dispose();
      _yearScroll = null;
    }
    if ((widget.today == null) != (oldWidget.today == null)) _armMidnight();
  }

  @override
  void initState() {
    super.initState();
    _armMidnight();
  }

  /// Without [FlCalendarView.today], the grid rebuilds at the next local
  /// midnight to move today (and a bound set from the clock by the app,
  /// which rebuilds with it).
  void _armMidnight() {
    _midnight?.cancel();
    _midnight = null;
    if (widget.today != null) return;
    final now = DateTime.now();
    _midnight = Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      if (!mounted) return;
      setState(() {});
      _armMidnight();
    });
  }

  /// Takes the cursor to [day], clamped, and the grid to its month, without sliding.
  void _jump(DateTime day) {
    _cursor = _clamp(day);
    _month = _monthOf(_cursor);
    _from = null;
    _slide.value = 1;
  }

  @override
  void dispose() {
    _slide.dispose();
    _days.dispose();
    _years.dispose();
    _yearScroll?.dispose();
    _grid.dispose();
    _yearGrid.dispose();
    _previous.dispose();
    _next.dispose();
    _midnight?.cancel();
    super.dispose();
  }

  FlCalendarStrings get _strings => widget.strings ?? FlCalendarStrings.of(context);

  int get _firstDay => widget.firstDayOfWeek ?? _strings.firstDayOfWeek;

  int _weeks(DateTime month) => math.max(widget.weeksInMonth ?? 0, _weeksOf(month, _firstDay));

  void _show(DateTime month) {
    if (_monthIndex(month) == _monthIndex(_month) || !_canShow(month)) return;
    final reduced = FlMotion.of(context).reduced;
    setState(() {
      _from = reduced ? null : _month;
      _month = month;
    });
    _announce(_strings.monthYear(month.year, month.month));
    if (reduced) {
      _slide.value = 1;
      return;
    }
    _slide.value = 0;
    unawaited(
      _slide.driveTo(1, FlSpringMotion(FlMotion.of(context).tokens.spatialSlow)).then((done) {
        if (done && mounted) setState(() => _from = null);
      }),
    );
  }

  void _announce(String text) {
    if (!MediaQuery.supportsAnnounceOf(context)) return;
    unawaited(SemanticsService.sendAnnouncement(View.of(context), text, Directionality.of(context)));
  }

  /// Takes the cursor to [day], and the grid to its month.
  void _moveCursor(DateTime day) {
    setState(() => _cursor = day);
    _show(_monthOf(day));
  }

  /// Moves to the month [step] further, the cursor on the same day.
  void _page(int step) {
    final month = _addMonths(_month, step);
    if (!widget.enabled || !_canShow(month)) return;
    _cursor = _clamp(_dayIn(month, _cursor.day));
    _show(month);
    // The button that just reached the bound is disabled and loses the
    // focus: it returns to the grid, as in React Aria.
    final button = step < 0 ? _previous : _next;
    if (button.hasFocus && !_canShow(_addMonths(month, step))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _grid.requestFocus());
    }
  }

  void _press(DateTime day) {
    if (!_selectable(day)) return;
    setState(() => _cursor = day);
    widget.onDayPressed(day);
  }

  KeyEventResult _gridKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      if (!_selectable(_cursor)) return KeyEventResult.ignored;
      _press(_cursor);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      return widget.onEscape?.call() ?? false ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    final forward = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final day = _cursor;
    final weekStart = DateTime(day.year, day.month, day.day - (day.weekday - _firstDay + 7) % 7);
    final target = switch (key) {
      LogicalKeyboardKey.arrowRight => DateTime(day.year, day.month, day.day + forward),
      LogicalKeyboardKey.arrowLeft => DateTime(day.year, day.month, day.day - forward),
      LogicalKeyboardKey.arrowDown => DateTime(day.year, day.month, day.day + 7),
      LogicalKeyboardKey.arrowUp => DateTime(day.year, day.month, day.day - 7),
      LogicalKeyboardKey.pageDown => _dayIn(_addMonths(_monthOf(day), shift ? 12 : 1), day.day),
      LogicalKeyboardKey.pageUp => _dayIn(_addMonths(_monthOf(day), shift ? -12 : -1), day.day),
      LogicalKeyboardKey.home => weekStart,
      LogicalKeyboardKey.end => DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    final next = _clamp(target);
    if (flSameDay(next, day)) return KeyEventResult.ignored;
    _moveCursor(next);
    return KeyEventResult.handled;
  }

  (int, int) get _yearSpan {
    final now = (widget.today ?? DateTime.now()).year;
    final first = _min?.year ?? math.min(_firstYear, math.min(now, _max?.year ?? now));
    final last = _max?.year ?? math.max(_lastYear, math.max(now, first));
    return (first, last);
  }

  void _toggleYears() => _yearsOpen ? _closeYears() : _openYears();

  void _openYears() {
    final motion = FlMotion.of(context);
    setState(() {
      _yearsOpen = true;
      _yearCursor = _month.year;
    });
    if (motion.reduced) {
      _days.value = 0;
      _years.value = 1;
    } else {
      unawaited(_days.animateTo(0, duration: motion.tokens.short3, curve: motion.tokens.easeOut));
      _years.value = 0;
      unawaited(
        _years.animateTo(
          1,
          duration: motion.tokens.short4 * (1 / (1 - _yearsDelay)),
          curve: Interval(_yearsDelay, 1, curve: motion.tokens.easeOut),
        ),
      );
    }
    _yearGrid.requestFocus();
  }

  /// The years disappear at once; the days fade back in.
  void _closeYears({bool focusGrid = false}) {
    final motion = FlMotion.of(context);
    setState(() => _yearsOpen = false);
    _years.value = 0;
    _yearScroll?.dispose();
    _yearScroll = null;
    if (motion.reduced) {
      _days.value = 1;
    } else {
      unawaited(_days.animateTo(1, duration: motion.tokens.short3, curve: motion.tokens.easeOut));
    }
    // The day grid accepts the focus only once out of ExcludeFocus.
    if (focusGrid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _grid.requestFocus());
    }
  }

  void _chooseYear(int year) {
    if (!widget.enabled) return;
    final day = _clamp(_dayIn(DateTime(year, _month.month), _cursor.day));
    _cursor = day;
    final month = _monthOf(day);
    if (_monthIndex(month) != _monthIndex(_month)) {
      setState(() => _month = month);
      _announce(_strings.monthYear(month.year, month.month));
    }
    _closeYears(focusGrid: true);
  }

  KeyEventResult _yearKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closeYears(focusGrid: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      _chooseYear(_yearCursor);
      return KeyEventResult.handled;
    }
    final (first, last) = _yearSpan;
    final forward = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final target = switch (key) {
      LogicalKeyboardKey.arrowRight => _yearCursor + forward,
      LogicalKeyboardKey.arrowLeft => _yearCursor - forward,
      LogicalKeyboardKey.arrowDown => _yearCursor + _yearColumns,
      LogicalKeyboardKey.arrowUp => _yearCursor - _yearColumns,
      LogicalKeyboardKey.home => first,
      LogicalKeyboardKey.end => last,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    final next = target.clamp(first, last);
    if (next == _yearCursor) return KeyEventResult.ignored;
    setState(() => _yearCursor = next);
    _revealYear(next);
    return KeyEventResult.handled;
  }

  /// Scrolls the year grid to [year] if it is hidden.
  void _revealYear(int year) {
    final scroll = _yearScroll;
    if (scroll == null || !scroll.hasClients) return;
    final look = _YearLook.of(context);
    final top = _yearTop(year, look);
    final position = scroll.position;
    final target = top < position.pixels
        ? top - look.gap
        : top + look.row > position.pixels + position.viewportDimension
        ? top + look.row + look.gap - position.viewportDimension
        : null;
    if (target != null) {
      scroll.jumpTo(target.clamp(position.minScrollExtent, position.maxScrollExtent));
    }
  }

  double _yearTop(int year, _YearLook look) =>
      look.gap + ((year - _yearSpan.$1) ~/ _yearColumns) * (look.row + look.gap);

  /// The last month reported to [FlCalendarView.onMonthChanged].
  DateTime? _reportedMonth;

  /// Reports the shown month to the app after the frame: it can then change
  /// its state without rebuilding during the build.
  void _reportMonth() {
    final month = _month;
    if (widget.onMonthChanged == null || _reportedMonth == month) return;
    _reportedMonth = month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _reportedMonth == month) {
        widget.onMonthChanged?.call(month);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final strings = _strings;
    _reportMonth();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 7 * _cell;
        final look = _Look.of(context, theme, cell: width / 7);
        final view = SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(theme, strings, look),
              Stack(
                children: [
                  FadeTransition(
                    opacity: _days,
                    child: ExcludeFocus(
                      excluding: _yearsOpen,
                      child: ExcludeSemantics(
                        excluding: _yearsOpen,
                        child: IgnorePointer(ignoring: _yearsOpen, child: _dayArea(theme, strings, look)),
                      ),
                    ),
                  ),
                  if (_yearsOpen)
                    Positioned.fill(
                      child: FadeTransition(opacity: _years, child: _yearArea(theme, strings)),
                    ),
                ],
              ),
            ],
          ),
        );
        return widget.enabled ? view : Opacity(opacity: theme.size.disabledOpacity, child: view);
      },
    );
  }

  Widget _header(FlTheme theme, FlCalendarStrings strings, _Look look) {
    final colors = theme.colors;
    final title = strings.monthYear(_month.year, _month.month);
    // Izydesk's year grid is headed by the year alone.
    final heading = Text(
      _yearsOpen ? strings.number(_month.year) : title,
      style: look.heading.copyWith(color: colors.onSurface),
      strutStyle: look.headingStrut,
    );
    final iconScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: theme.size.iconMaxScale);
    final Widget start = widget.showYearPicker
        ? _Button(
            label: title,
            hint: strings.chooseYear,
            expanded: _yearsOpen,
            liveRegion: !MediaQuery.supportsAnnounceOf(context),
            onPressed: widget.enabled ? _toggleYears : null,
            radius: theme.shape.radiusLg,
            builder: (context, hovered) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: theme.space.xs,
              children: [
                // Yoga rounds a text's box to the pixel: the chevron follows it.
                Flexible(child: FlPixelSnap(child: heading)),
                // Down while the days show, up while the years do.
                AnimatedRotation(
                  turns: _yearsOpen ? 0.5 : 0,
                  duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.short3,
                  curve: theme.motion.easeOut,
                  child: FlIcon(FlIcons.chevronDown, size: iconScaler.scale(_yearChevron), color: colors.link),
                ),
              ],
            ),
          )
        : Semantics(liveRegion: !MediaQuery.supportsAnnounceOf(context), child: heading);
    Widget nav(int step) {
      final enabled = widget.enabled && _canShow(_addMonths(_month, step));
      final icon = iconScaler.scale(_navIcon);
      return _Button(
        label: step < 0 ? strings.previousMonth : strings.nextMonth,
        focusNode: step < 0 ? _previous : _next,
        onPressed: enabled && !_yearsOpen ? () => _page(step) : null,
        radius: theme.shape.radiusXxl,
        builder: (context, hovered) => Opacity(
          // A disabled calendar fades as a whole.
          opacity: enabled || !widget.enabled ? 1 : theme.size.disabledOpacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hovered ? colors.control : null,
              borderRadius: BorderRadius.circular(theme.shape.radiusXxl),
            ),
            child: SizedBox.square(
              dimension: icon + _navButton - _navIcon,
              child: Center(
                child: FlIcon(step < 0 ? FlIcons.chevronLeft : FlIcons.chevronRight, size: icon, color: colors.link),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      // Izydesk's `.cal` gap.
      padding: EdgeInsetsDirectional.only(bottom: theme.space.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _headHeight),
        child: Row(
          children: [
            Expanded(
              child: Align(alignment: AlignmentDirectional.centerStart, child: start),
            ),
            FadeTransition(
              opacity: _days,
              child: ExcludeSemantics(
                excluding: _yearsOpen,
                child: Row(mainAxisSize: MainAxisSize.min, spacing: theme.space.xs, children: [nav(-1), nav(1)]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayArea(FlTheme theme, FlCalendarStrings strings, _Look look) {
    final weekdays = [for (var i = 0; i < 7; i++) (_firstDay - 1 + i) % 7];
    final labels = _weekdayLabels(strings, weekdays);
    final header = ExcludeSemantics(
      child: Row(
        children: [
          for (final label in labels)
            SizedBox(
              width: look.cell,
              child: Padding(
                // Izydesk's `.cal-wd`: 4 above, 6 below.
                padding: EdgeInsetsDirectional.only(top: theme.space.xs, bottom: theme.space.xs * 1.5),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: look.weekday, strutStyle: look.weekdayStrut, maxLines: 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final forward = Directionality.of(context) == TextDirection.ltr;
    final direction = _from == null ? 0 : (_monthIndex(_month) - _monthIndex(_from!)).sign;
    final body = AnimatedBuilder(
      animation: _slide,
      builder: (context, _) {
        final t = _slide.value;
        final from = _from;
        final shift = 7 * look.cell * direction;
        // The first week's top margin and the last's bottom one are the
        // grid's row gap only between weeks.
        return SizedBox(
          height:
              (from == null
                  ? _weeks(_month) * look.row
                  : lerpDouble(_weeks(from) * look.row, _weeks(_month) * look.row, t)!) -
              2 * _rangeGap,
          child: Stack(
            clipBehavior: from == null ? Clip.none : Clip.hardEdge,
            children: [
              if (from != null)
                PositionedDirectional(
                  top: -_rangeGap,
                  start: -shift * t,
                  width: 7 * look.cell,
                  child: ExcludeSemantics(child: IgnorePointer(child: _monthGrid(theme, strings, look, from))),
                ),
              PositionedDirectional(
                top: -_rangeGap,
                start: from == null ? 0 : shift * (1 - t),
                width: 7 * look.cell,
                child: _monthGrid(theme, strings, look, _month),
              ),
            ],
          ),
        );
      },
    );
    final label = [?widget.semanticLabel, strings.monthYear(_month.year, _month.month)].join(strings.separator);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        // Izydesk's `row-gap` under the days of the week.
        SizedBox(height: theme.space.xs),
        Semantics(
          container: true,
          label: label,
          explicitChildNodes: true,
          child: FocusableActionDetector(
            focusNode: _grid,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            onShowFocusHighlight: (visible) => setState(() => _gridHighlight = visible),
            // The cursor's day carries the focus in the semantics.
            onFocusChange: (_) => setState(() {}),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _drag = 0,
              onHorizontalDragUpdate: (details) => _drag += details.primaryDelta ?? 0,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final towards = _drag.abs() > look.cell
                    ? _drag
                    : velocity.abs() > _flingVelocity
                    ? velocity
                    : 0.0;
                if (towards == 0) return;
                _page(towards < 0 == forward ? 1 : -1);
              },
              child: body,
            ),
          ),
        ),
      ],
    );
  }

  /// The initials of the days, as Izydesk's `.cal-wd` writes them.
  List<String> _weekdayLabels(FlCalendarStrings strings, List<int> weekdays) => [
    for (final i in weekdays) strings.weekdaysNarrow[i],
  ];

  Widget _monthGrid(FlTheme theme, FlCalendarStrings strings, _Look look, DateTime month) {
    final start = DateTime(month.year, month.month, 1 - _lead(month, _firstDay));
    final today = flDateOnly(widget.today ?? DateTime.now());
    final weeks = _weeks(month);
    final days = [for (var i = 0; i < weeks * 7; i++) DateTime(start.year, start.month, start.day + i)];
    // The neighboring months' days keep their mark, faded with them
    // (Izydesk's `.cal-d.out`).
    final marks = [for (final day in days) widget.markOf(day)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < weeks; row++)
          SizedBox(
            height: look.row,
            child: Stack(
              children: [
                ..._ribbon(theme, look, [
                  for (var column = 0; column < 7; column++)
                    (mark: marks[row * 7 + column], inMonth: days[row * 7 + column].month == month.month),
                ]),
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      _day(
                        theme,
                        strings,
                        look,
                        days[row * 7 + column],
                        mark: marks[row * 7 + column],
                        inMonth: days[row * 7 + column].month == month.month,
                        today: today,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// A week's period ribbon: soft
  /// `selected`, as high as a day, from the middle of the first day to the
  /// middle of the last, its ends rounded at `shape.radiusLg` where the week
  /// or the month cuts it (`rounded-s-lg`, `rounded-e-lg`); in one piece per
  /// month, so that no seam shows between the columns, faded over the
  /// neighboring months.
  List<Widget> _ribbon(FlTheme theme, _Look look, List<({FlDayMark mark, bool inMonth})> week) {
    final pieces = <Widget>[];
    var column = 0;
    while (column < week.length) {
      if (!week[column].mark._track) {
        column++;
        continue;
      }
      final first = column;
      final inMonth = week[first].inMonth;
      while (column + 1 < week.length && week[column + 1].mark._track && week[column + 1].inMonth == inMonth) {
        column++;
      }
      final capped = week[first].mark == FlDayMark.rangeStart;
      final ended = week[column].mark == FlDayMark.rangeEnd;
      final start = first * look.cell + (capped ? look.cell / 2 : 0);
      final end = (column + 1) * look.cell - (ended ? look.cell / 2 : 0);
      // Under a cap the end hides behind the disc and stays square.
      final cut = Radius.circular(theme.shape.radiusLg);
      // A cap alone on its side of the week has no ribbon: the half cell
      // would show beside the disc, so the cell is rounded whole.
      if (end > start && !(first == column && (capped || ended))) {
        pieces.add(
          PositionedDirectional(
            start: start,
            width: end - start,
            top: (look.row - look.disc) / 2,
            height: look.disc,
            child: Opacity(
              opacity: inMonth ? 1 : theme.size.disabledOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _soft(theme),
                  borderRadius: BorderRadiusDirectional.horizontal(
                    start: capped ? Radius.zero : cut,
                    end: ended ? Radius.zero : cut,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      column++;
    }
    return pieces;
  }

  Widget _day(
    FlTheme theme,
    FlCalendarStrings strings,
    _Look look,
    DateTime day, {
    required FlDayMark mark,
    required bool inMonth,
    required DateTime today,
  }) {
    final colors = theme.colors;
    final outOfBounds = _outOfBounds(day);
    final unavailable = widget.isUnavailable?.call(day) ?? false;
    // Izydesk's `.cal-d.off`: a day beyond the bounds or refused is struck
    // through and faded, in or out of the month, and loses today's mark. A
    // disabled calendar fades as a whole instead (see build).
    final min = _min;
    final max = _max;
    final beyond = (min != null && day.isBefore(min)) || (max != null && day.isAfter(max));
    final departureOnly = inMonth && (widget.isDepartureOnly?.call(day) ?? false);
    // The chosen end of a stay does not start the next one, and so cannot
    // be chosen; yet it remains the end the app received. At the start or
    // in the middle of a period, its taken night remains unavailable.
    final chosenEnd = departureOnly && mark == FlDayMark.rangeEnd;
    final off = (beyond || unavailable) && !chosenEnd;
    final isToday = flSameDay(day, today) && !off;
    final selectable = inMonth && !outOfBounds && !unavailable;
    final pressed = selectable && _pressed != null && flSameDay(_pressed!, day);
    final hovered = selectable && _hovered != null && flSameDay(_hovered!, day);
    final cap = mark._cap;
    final pending = inMonth && widget.pendingStart != null && flSameDay(widget.pendingStart!, day);
    final indicator = inMonth ? widget.indicatorOf?.call(day) : null;
    // The chosen day has no pressed tint: `selected` has none, and the
    // scale of the pressed day is enough to show it. Today sits on a soft
    // `selected` disc, its digit in `link`; on
    // the ribbon, only the digit marks it.
    final Color? disc = switch ((cap, pressed, hovered)) {
      (true, _, _) => colors.selected,
      (false, true, _) when !widget.range => colors.control,
      (false, _, true) => colors.control,
      _ when isToday && inMonth && !mark._track => _soft(theme),
      _ => null,
    };
    final ink = cap
        ? colors.onSelected
        : isToday && inMonth
        ? colors.link
        : inMonth
        ? colors.onSurface
        : colors.onSurfaceMuted;
    final radius = Radius.circular(theme.shape.radiusButton);
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        strings.number(day.day),
        maxLines: 1,
        style: look.day.copyWith(
          color: ink,
          fontWeight: isToday || cap ? theme.tokens.typography.weight.medium : null,
          decoration: off && !cap && !departureOnly
              ? TextDecoration.lineThrough
              : departureOnly
              ? TextDecoration.underline
              : null,
          decorationColor: ink,
        ),
        strutStyle: look.dayStrut,
      ),
    );
    Widget content = AnimatedScale(
      scale: pressed ? (widget.range ? _rangePressedScale : _pressedScale) : 1,
      duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.medium1,
      curve: theme.motion.easeOut,
      child: FlFocusRing(
        visible: _gridHighlight && !_yearsOpen && inMonth && flSameDay(day, _cursor),
        borderRadius: BorderRadius.all(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: disc,
            border: pending ? Border.all(color: colors.selected, width: theme.size.focusRing) : null,
            borderRadius: BorderRadius.all(radius),
          ),
          child: SizedBox.square(
            dimension: look.disc,
            child: indicator == null
                ? Center(child: text)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      text,
                      // `calendar__cell-indicator`: a dot at the bottom
                      // centre of the cell.
                      PositionedDirectional(
                        bottom: theme.space.xs,
                        child: SizedBox.square(
                          dimension: theme.space.xs,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color: cap ? colors.onSelected : colors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    content = Opacity(
      opacity: !inMonth || off ? theme.size.disabledOpacity : 1,
      child: SizedBox(
        width: look.cell,
        height: look.row,
        child: Center(child: content),
      ),
    );
    if (!inMonth) return ExcludeSemantics(child: content);
    final label = [
      strings.date(day),
      if (isToday) strings.today,
      if (pending) strings.pendingStart,
      if (mark == FlDayMark.rangeStart || mark == FlDayMark.rangeSingle) strings.rangeStart,
      if (mark == FlDayMark.rangeEnd || mark == FlDayMark.rangeSingle) strings.rangeEnd,
      if (departureOnly) ?strings.departureOnly,
      if (indicator != null && indicator.isNotEmpty) indicator,
      if (!selectable && !chosenEnd) strings.unavailable,
    ].join(strings.separator);
    return FlHitTarget(
      child: Semantics(
        button: true,
        selected: mark != FlDayMark.none,
        focusable: true,
        focused: _grid.hasFocus && !_yearsOpen && flSameDay(day, _cursor),
        enabled: selectable,
        label: label,
        onTap: selectable ? () => _press(day) : null,
        child: MouseRegion(
          cursor: selectable ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: selectable && theme.hovers ? (_) => setState(() => _hovered = day) : null,
          onExit: (_) {
            if (_hovered != null && flSameDay(_hovered!, day)) {
              setState(() => _hovered = null);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: selectable ? (_) => setState(() => _pressed = day) : null,
            onTapCancel: selectable ? () => setState(() => _pressed = null) : null,
            onTapUp: selectable ? (_) => setState(() => _pressed = null) : null,
            onTap: selectable ? () => _press(day) : null,
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }

  Widget _yearArea(FlTheme theme, FlCalendarStrings strings) {
    final colors = theme.colors;
    final (first, last) = _yearSpan;
    final look = _YearLook.of(context);
    return Semantics(
      container: true,
      label: strings.years,
      explicitChildNodes: true,
      child: FocusableActionDetector(
        focusNode: _yearGrid,
        onShowFocusHighlight: (visible) => setState(() => _yearHighlight = visible),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scroll = _yearScroll ??= ScrollController(
              initialScrollOffset: math.max(0, _yearTop(_month.year, look) - (constraints.maxHeight - look.row) / 2),
            );
            // Izydesk's `.cal-years` fills the width; the focus ring of an
            // edge year still shows past it, clipped only above and below.
            return ClipRect(
              clipper: const _VerticalClip(),
              child: GridView.builder(
                controller: scroll,
                clipBehavior: Clip.none,
                padding: EdgeInsetsDirectional.symmetric(vertical: look.gap),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _yearColumns,
                  mainAxisSpacing: look.gap,
                  crossAxisSpacing: look.gap,
                  mainAxisExtent: look.row,
                ),
                itemCount: last - first + 1,
                itemBuilder: (context, index) {
                  final year = first + index;
                  final selected = year == _month.year;
                  final pressed = _pressedYear == year;
                  return FlHitTarget(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: strings.number(year),
                      onTap: () => _chooseYear(year),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTapDown: (_) => setState(() => _pressedYear = year),
                        onTapCancel: () => setState(() => _pressedYear = null),
                        onTapUp: (_) => setState(() => _pressedYear = null),
                        onTap: () => _chooseYear(year),
                        child: FlFocusRing(
                          visible: _yearHighlight && year == _yearCursor,
                          borderRadius: BorderRadius.circular(theme.shape.radiusButton),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected ? colors.selected : (pressed ? colors.control : null),
                              borderRadius: BorderRadius.circular(theme.shape.radiusButton),
                            ),
                            child: Padding(
                              // px-2.5
                              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.xs * 2.5),
                              child: Center(
                                child: ExcludeSemantics(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      strings.number(year),
                                      maxLines: 1,
                                      style: look.text.copyWith(color: selected ? colors.onSelected : colors.onSurface),
                                      strutStyle: look.strut,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Clips above and below only.
class _VerticalClip extends CustomClipper<Rect> {
  const _VerticalClip();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-size.width, 0, size.width * 2, size.height);

  @override
  bool shouldReclip(_VerticalClip oldClipper) => false;
}

/// The grid's measurements for a column width: texts and row height.
final class _Look {
  const _Look({
    required this.cell,
    required this.disc,
    required this.row,
    required this.heading,
    required this.headingStrut,
    required this.weekday,
    required this.weekdayStrut,
    required this.day,
    required this.dayStrut,
  });

  factory _Look.of(BuildContext context, FlTheme theme, {required double cell}) {
    final medium = theme.tokens.typography.weight.medium;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final text = theme.typography;
    // 40, or the enlarged line when it is taller, up to the column.
    final line = MediaQuery.textScalerOf(context).scale(text.style(FlTextRole.textBase).lineHeight);
    final disc = math.min(cell, math.max(_cell, line));
    return _Look(
      cell: cell,
      disc: disc,
      // Izydesk's `.cal-grid` keeps `space.xs` between the weeks, a single
      // day's calendar as a period's.
      row: disc + 2 * _rangeGap,
      heading: text.resolve(FlTextRole.textBase).copyWith(fontWeight: medium),
      headingStrut: text.strut(FlTextRole.textBase, inheritedFamily: family),
      weekday: text.resolve(FlTextRole.textXs).copyWith(fontWeight: medium, color: theme.colors.onSurfaceMuted),
      weekdayStrut: text.strut(FlTextRole.textXs, inheritedFamily: family),
      day: text.resolve(FlTextRole.textBase),
      dayStrut: text.strut(FlTextRole.textBase, inheritedFamily: family),
    );
  }

  /// The width of a column.
  final double cell;

  /// The side of a day: 40, or the enlarged line when taller, up to [cell].
  final double disc;

  /// The height of a row: [disc], plus the margins of a period.
  final double row;

  /// `textBase` medium of the month (Izydesk's `.cal-month`).
  final TextStyle heading;
  final StrutStyle headingStrut;

  /// `text-xs font-medium text-muted` of the days of the week.
  final TextStyle weekday;
  final StrutStyle weekdayStrut;

  /// `textBase` of a day (`.cal-d`), medium when chosen and today.
  final TextStyle day;
  final StrutStyle dayStrut;
}

/// The measurements of the year grid.
final class _YearLook {
  const _YearLook({required this.row, required this.gap, required this.text, required this.strut});

  factory _YearLook.of(BuildContext context) {
    final theme = FlScope.of(context);
    final style = theme.typography.style(FlTextRole.textBase);
    return _YearLook(
      row: math.max(
        _yearHeight,
        MediaQuery.textScalerOf(context).scale(style.lineHeight) + _yearHeight - style.lineHeight,
      ),
      gap: theme.space.sm,
      text: theme.typography.resolve(FlTextRole.textBase),
      strut: theme.typography.strut(
        FlTextRole.textBase,
        inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
      ),
    );
  }

  /// 40: the text's line and 8 of margin on each side, kept when the
  /// text grows.
  final double row;

  /// Between the years and around them (Izydesk's `.cal-years`).
  final double gap;
  final TextStyle text;
  final StrutStyle strut;
}

/// A header button: touch target, focus, hover, pressed scale
/// (`scale(0.95)`) and button semantics.
class _Button extends StatefulWidget {
  const _Button({
    required this.label,
    required this.onPressed,
    required this.radius,
    required this.builder,
    this.hint,
    this.expanded,
    this.liveRegion = false,
    this.focusNode,
  });

  final FocusNode? focusNode;

  final String label;
  final String? hint;
  final bool? expanded;
  final bool liveRegion;
  final VoidCallback? onPressed;
  final double radius;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;
    return FlHitTarget(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        hint: widget.hint,
        expanded: widget.expanded,
        liveRegion: widget.liveRegion,
        onTap: onPressed,
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed?.call())},
          onShowHoverHighlight: (visible) => setState(() => _hovered = visible && theme.hovers),
          onShowFocusHighlight: (visible) => setState(() => _focused = visible),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTap: onPressed,
            child: AnimatedScale(
              scale: _pressed ? _pressedScale : 1,
              duration: FlMotion.of(context).reduced ? Duration.zero : theme.motion.medium1,
              curve: theme.motion.easeOut,
              child: FlFocusRing(
                visible: _focused && enabled,
                borderRadius: BorderRadius.circular(widget.radius),
                child: ExcludeSemantics(child: widget.builder(context, _hovered && enabled)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

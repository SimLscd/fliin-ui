import 'package:flutter/widgets.dart';

/// The texts and date rules of a calendar, by key then by language: the
/// same table as the manifest's `l10n`. The names of the months (from
/// January to December) and of the days (from Monday to Sunday) are
/// comma-separated lists; `calendarFirstDay` is the first day of the week,
/// from 1 (Monday) to 7 (Sunday), like `DateTime.weekday`; `calendarDigits`
/// the digits from 0 to 9. For another language, an app passes a table
/// with the same keys to `FlCalendarStrings.fromTable`, or builds
/// `FlCalendarStrings` from `intl` (see its docs). Copying these keys into
/// ARB files wires nothing: `gen-l10n` would turn them into getters and
/// methods that the calendar does not read.
const Map<String, Map<String, String>> flCalendarL10n = {
  'calendarMonths': {
    'en': 'January,February,March,April,May,June,July,August,September,October,November,December',
    'fr': 'janvier,février,mars,avril,mai,juin,juillet,août,septembre,octobre,novembre,décembre',
    'ar': 'يناير,فبراير,مارس,أبريل,مايو,يونيو,يوليو,أغسطس,سبتمبر,أكتوبر,نوفمبر,ديسمبر',
  },
  'calendarWeekdays': {
    'en': 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
    'fr': 'lundi,mardi,mercredi,jeudi,vendredi,samedi,dimanche',
    'ar': 'الاثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت,الأحد',
  },
  'calendarWeekdaysShort': {
    'en': 'Mon,Tue,Wed,Thu,Fri,Sat,Sun',
    'fr': 'lun.,mar.,mer.,jeu.,ven.,sam.,dim.',
    'ar': 'الاثنين,الثلاثاء,الأربعاء,الخميس,الجمعة,السبت,الأحد',
  },
  'calendarWeekdaysNarrow': {'en': 'M,T,W,T,F,S,S', 'fr': 'L,M,M,J,V,S,D', 'ar': 'ن,ث,ر,خ,ج,س,ح'},
  'calendarFirstDay': {'en': '7', 'fr': '1', 'ar': '6'},
  'calendarDigits': {'en': '0123456789', 'fr': '0123456789', 'ar': '٠١٢٣٤٥٦٧٨٩'},
  'calendarMonthYear': {'en': '{month} {year}', 'fr': '{month} {year}', 'ar': '{month} {year}'},
  'calendarDate': {
    'en': '{weekday}, {month} {day}, {year}',
    'fr': '{weekday} {day} {month} {year}',
    'ar': '{weekday}، {day} {month} {year}',
  },
  'calendarSeparator': {'en': ', ', 'fr': ', ', 'ar': '، '},
  'calendarToday': {'en': 'today', 'fr': 'aujourd’hui', 'ar': 'اليوم'},
  'calendarPendingStart': {
    'en': 'start picked, choose the end',
    'fr': 'début posé, choisissez la fin',
    'ar': 'تم تحديد البداية، اختر النهاية',
  },
  'calendarUnavailable': {'en': 'unavailable', 'fr': 'indisponible', 'ar': 'غير متاح'},
  'calendarDepartureOnly': {'en': 'check-out only', 'fr': 'départ seulement', 'ar': 'المغادرة فقط'},
  'calendarRangeStart': {'en': 'start of range', 'fr': 'début de la période', 'ar': 'بداية الفترة'},
  'calendarRangeEnd': {'en': 'end of range', 'fr': 'fin de la période', 'ar': 'نهاية الفترة'},
  'calendarPreviousMonth': {'en': 'Previous month', 'fr': 'Mois précédent', 'ar': 'الشهر السابق'},
  'calendarNextMonth': {'en': 'Next month', 'fr': 'Mois suivant', 'ar': 'الشهر التالي'},
  'calendarChooseYear': {'en': 'Choose a year', 'fr': 'Choisir l’année', 'ar': 'اختيار السنة'},
  'calendarYears': {'en': 'Years', 'fr': 'Années', 'ar': 'السنوات'},
};

/// What a calendar writes and reads in a language: the names of the months
/// and days, the first day of the week, the digits, the month header and
/// the full date, and the screen reader's words.
///
/// `registry` has no `intl`. Without a given [FlCalendarStrings], the
/// calendar reads [flCalendarL10n] in the language of the nearest
/// `Localizations`: English, French or Arabic. Another language fails with
/// an assertion in debug mode (English, Sunday first, in release): the app
/// must then pass its texts, through [FlCalendarStrings.fromTable] or from
/// `intl`. With `intl`, after `await initializeDateFormatting(locale)`,
/// three traps shift a day without error: `intl`'s days start on Sunday,
/// its first day of the week counts from 0 (Monday) to 6, and its digits
/// come from `NumberFormat`, not `DateFormat`. This function avoids them;
/// `words` carries the screen reader's words, taken from the app's ARB
/// files:
///
/// ```dart
/// FlCalendarStrings calendarStringsFromIntl(String locale, FlCalendarStrings words) {
///   final symbols = DateFormat.yMMMM(locale).dateSymbols;
///   List<String> mondayFirst(List<String> sundayFirst) => [...sundayFirst.skip(1), sundayFirst.first];
///   final zero = NumberFormat.decimalPattern(locale).symbols.ZERO_DIGIT.codeUnitAt(0);
///   return FlCalendarStrings(
///     months: symbols.STANDALONEMONTHS,
///     weekdays: mondayFirst(symbols.STANDALONEWEEKDAYS),
///     weekdaysShort: mondayFirst(symbols.STANDALONESHORTWEEKDAYS),
///     weekdaysNarrow: mondayFirst(symbols.STANDALONENARROWWEEKDAYS),
///     firstDayOfWeek: symbols.FIRSTDAYOFWEEK + 1,
///     digits: String.fromCharCodes([for (var i = 0; i < 10; i++) zero + i]),
///     monthYearPattern: words.monthYearPattern,
///     datePattern: words.datePattern,
///     formatMonthYear: (year, month) => DateFormat.yMMMM(locale).format(DateTime(year, month)),
///     formatDate: DateFormat.yMMMMEEEEd(locale).format,
///     separator: words.separator,
///     today: words.today,
///     pendingStart: words.pendingStart,
///     unavailable: words.unavailable,
///     departureOnly: words.departureOnly,
///     rangeStart: words.rangeStart,
///     rangeEnd: words.rangeEnd,
///     previousMonth: words.previousMonth,
///     nextMonth: words.nextMonth,
///     chooseYear: words.chooseYear,
///     years: words.years,
///   );
/// }
/// ```
///
/// The calendar is Gregorian.
final class FlCalendarStrings {
  /// Texts given by the app. [months] has twelve names, from January to
  /// December; [weekdays], [weekdaysShort] and [weekdaysNarrow] seven, from
  /// Monday to Sunday.
  FlCalendarStrings({
    required this.months,
    required this.weekdays,
    required this.weekdaysShort,
    required this.weekdaysNarrow,
    required this.firstDayOfWeek,
    required this.digits,
    required this.monthYearPattern,
    required this.datePattern,
    required this.separator,
    required this.today,
    required this.pendingStart,
    required this.unavailable,
    required this.rangeStart,
    required this.rangeEnd,
    required this.previousMonth,
    required this.nextMonth,
    required this.chooseYear,
    required this.years,
    this.departureOnly,
    this.formatMonthYear,
    this.formatDate,
  }) : assert(months.length == 12, 'twelve months'),
       assert(weekdays.length == 7 && weekdaysShort.length == 7 && weekdaysNarrow.length == 7, 'seven days'),
       assert(firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday, 'from 1 (Monday) to 7'),
       assert(digits.length == 10, 'ten digits');

  /// The texts of a language, by key of [flCalendarL10n]: the table of a
  /// language that the app adds. Throws a [FormatException] that names the
  /// missing or malformed key; `calendarDepartureOnly` may be missing (see
  /// [departureOnly]).
  factory FlCalendarStrings.fromTable(Map<String, String> table) {
    String t(String key) =>
        table['calendar$key'] ?? (throw FormatException('key calendar$key missing from the calendar table'));
    List<String> list(String key, int length) {
      final items = t(key).split(',');
      if (items.length != length) {
        throw FormatException('calendar$key: $length comma-separated names expected, ${items.length} read');
      }
      return items;
    }

    final firstDay = int.tryParse(t('FirstDay'));
    if (firstDay == null || firstDay < DateTime.monday || firstDay > DateTime.sunday) {
      throw FormatException('calendarFirstDay: 1 (Monday) to 7 (Sunday) expected, "${t('FirstDay')}" read');
    }
    if (t('Digits').length != 10) {
      throw const FormatException('calendarDigits: ten digits expected');
    }
    return FlCalendarStrings(
      months: list('Months', 12),
      weekdays: list('Weekdays', 7),
      weekdaysShort: list('WeekdaysShort', 7),
      weekdaysNarrow: list('WeekdaysNarrow', 7),
      firstDayOfWeek: firstDay,
      digits: t('Digits'),
      monthYearPattern: t('MonthYear'),
      datePattern: t('Date'),
      separator: t('Separator'),
      today: t('Today'),
      pendingStart: t('PendingStart'),
      unavailable: t('Unavailable'),
      departureOnly: table['calendarDepartureOnly'],
      rangeStart: t('RangeStart'),
      rangeEnd: t('RangeEnd'),
      previousMonth: t('PreviousMonth'),
      nextMonth: t('NextMonth'),
      chooseYear: t('ChooseYear'),
      years: t('Years'),
    );
  }

  /// The texts of [flCalendarL10n] in [language] (`en`, `fr` or `ar`),
  /// English for another language.
  factory FlCalendarStrings.language(String language) {
    final code = languages.contains(language) ? language : 'en';
    return FlCalendarStrings.fromTable({for (final entry in flCalendarL10n.entries) entry.key: entry.value[code]!});
  }

  /// The texts in the language of the nearest `Localizations`. A language
  /// missing from [flCalendarL10n] fails with an assertion in debug mode,
  /// and takes English in release.
  factory FlCalendarStrings.of(BuildContext context) {
    final language = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    assert(
      languages.contains(language),
      'FlCalendar: no texts for "$language" ($languages only). Pass strings, '
      'built by FlCalendarStrings.fromTable or from intl (see the FlCalendarStrings docs).',
    );
    return FlCalendarStrings.language(language);
  }

  /// The languages of [flCalendarL10n].
  static final Set<String> languages = flCalendarL10n.values.first.keys.toSet();

  /// The names of the months, from January to December ("October").
  final List<String> months;

  /// The names of the days, from Monday to Sunday ("Tuesday").
  final List<String> weekdays;

  /// The short names of the days, from Monday to Sunday, as column headers
  /// ("Tue").
  final List<String> weekdaysShort;

  /// The initials of the days, from Monday to Sunday, as column headers when
  /// the short names do not fit ("T").
  final List<String> weekdaysNarrow;

  /// The first day of the week, from `DateTime.monday` to `DateTime.sunday`.
  final int firstDayOfWeek;

  /// The digits from 0 to 9 ("٠١٢٣٤٥٦٧٨٩" in Arabic).
  final String digits;

  /// The month header: `{month}` and `{year}` ("{month} {year}").
  final String monthYearPattern;

  /// The full spoken date of a day: `{weekday}`, `{day}`, `{month}` and
  /// `{year}` ("{weekday} {day} {month} {year}").
  final String datePattern;

  /// The month header written by the app (a `DateFormat`); when null,
  /// [monthYearPattern].
  final String Function(int year, int month)? formatMonthYear;

  /// The full date written by the app (a `DateFormat`); when null,
  /// [datePattern].
  final String Function(DateTime day)? formatDate;

  /// What separates the date from its states when a day is read (",").
  final String separator;

  /// The state of today's day.
  final String today;

  /// The state of the first tapped day of a period, while awaiting the second.
  final String pendingStart;

  /// The state of a day that cannot be chosen.
  final String unavailable;

  /// The state of a day whose night is taken but which remains a possible
  /// departure, in a calendar of periods in nights. It is read only there:
  /// `FlRangeCalendar` requires it through an assertion when it counts in
  /// nights, and an app that does not use it need not provide it.
  final String? departureOnly;

  /// The state of the first day of a chosen period.
  final String rangeStart;

  /// The state of the last day of a chosen period.
  final String rangeEnd;

  /// The name of the previous month button.
  final String previousMonth;

  /// The name of the next month button.
  final String nextMonth;

  /// The hint of the month header, which opens the year choice.
  final String chooseYear;

  /// The name of the list of years.
  final String years;

  /// [value] written with [digits].
  String number(int value) => value.toString().split('').map((c) => c == '-' ? c : digits[int.parse(c)]).join();

  /// The month [month] (from 1 to 12) of [year] ("October 2026").
  String monthYear(int year, int month) =>
      formatMonthYear?.call(year, month) ??
      monthYearPattern.replaceAll('{month}', months[month - 1]).replaceAll('{year}', number(year));

  /// The full date of [day] ("Tuesday, October 14, 2026").
  String date(DateTime day) =>
      formatDate?.call(day) ??
      datePattern
          .replaceAll('{weekday}', weekdays[day.weekday - 1])
          .replaceAll('{day}', number(day.day))
          .replaceAll('{month}', months[day.month - 1])
          .replaceAll('{year}', number(day.year));
}

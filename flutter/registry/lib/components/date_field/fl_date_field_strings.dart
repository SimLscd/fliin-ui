import 'package:flutter/widgets.dart';

/// A segment of a date or time field, what it counts.
enum FlDateSegment {
  /// The day of the month, from 1 to 31.
  day,

  /// The month, from 1 to 12.
  month,

  /// The year, from 1 to 9999.
  year,

  /// The hour, from 0 to 23, or from 1 to 12 with [dayPeriod].
  hour,

  /// The minute, from 0 to 59.
  minute,

  /// The morning (0) or afternoon (1) of a 12-hour time.
  dayPeriod,
}

/// The texts and rules of a date or time field, by key then by language:
/// the same table as the `l10n` of the `date-field` manifest.
/// `dateFieldOrder` is the order of the day (`d`), the month (`m`) and the
/// year (`y`); `dateFieldPlaceholders` and `dateFieldNames` are
/// comma-separated lists (day, month, year; day, month, year, hour, minute,
/// morning or afternoon); `timeFieldHourCycle` is 12 or 24. For another
/// language, an app passes a table with the same keys to
/// `FlDateFieldStrings.fromTable`.
const Map<String, Map<String, String>> flDateFieldL10n = {
  'dateFieldOrder': {'en': 'mdy', 'fr': 'dmy', 'ar': 'dmy'},
  'dateFieldSeparator': {'en': '/', 'fr': '/', 'ar': '/'},
  'dateFieldPlaceholders': {'en': 'dd,mm,yyyy', 'fr': 'jj,mm,aaaa', 'ar': 'يوم,شهر,سنة'},
  'dateFieldNames': {
    'en': 'day,month,year,hour,minute,AM/PM',
    'fr': 'jour,mois,année,heure,minute,AM/PM',
    'ar': 'اليوم,الشهر,السنة,الساعة,الدقيقة,ص/م',
  },
  'dateFieldEmpty': {'en': 'empty', 'fr': 'vide', 'ar': 'فارغ'},
  'dateFieldMonths': {
    'en': 'January,February,March,April,May,June,July,August,September,October,November,December',
    'fr': 'janvier,février,mars,avril,mai,juin,juillet,août,septembre,octobre,novembre,décembre',
    'ar': 'يناير,فبراير,مارس,أبريل,مايو,يونيو,يوليو,أغسطس,سبتمبر,أكتوبر,نوفمبر,ديسمبر',
  },
  'dateFieldDigits': {'en': '0123456789', 'fr': '0123456789', 'ar': '٠١٢٣٤٥٦٧٨٩'},
  'timeFieldHourCycle': {'en': '12', 'fr': '24', 'ar': '12'},
  'timeFieldDayPeriods': {'en': 'AM,PM', 'fr': 'AM,PM', 'ar': 'ص,م'},
  'timeFieldSeparator': {'en': ':', 'fr': ':', 'ar': ':'},
};

/// What a date or time field writes and reads in a language: the order of
/// the segments, their separators, their placeholder texts, their names for
/// the screen reader, the digits, and the 12- or 24-hour clock.
///
/// `registry` has no `intl`. Without a given [FlDateFieldStrings], the
/// field reads [flDateFieldL10n] in the language of the nearest
/// `Localizations`: English, French or Arabic. Another language fails with
/// an assertion in debug mode (English in release): the app then passes its
/// texts through [FlDateFieldStrings.fromTable]. With `intl`, the order is
/// read from the pattern of `DateFormat.yMd(locale).pattern` (the first
/// letter of each field), the 12-hour clock from `DateFormat.jm(locale).pattern`
/// (an `a`), and the digits from `NumberFormat`.
final class FlDateFieldStrings {
  /// Texts given by the app. [order] arranges [FlDateSegment.day],
  /// [FlDateSegment.month] and [FlDateSegment.year].
  FlDateFieldStrings({
    required this.order,
    required this.separator,
    required this.placeholders,
    required this.names,
    required this.empty,
    required this.months,
    required this.digits,
    required this.hour12,
    required this.dayPeriods,
    required this.timeSeparator,
  }) : assert(order.length == 3 && order.toSet().length == 3, 'day, month and year, once each'),
       assert(names.length == FlDateSegment.values.length, 'one name per segment'),
       assert(months.length == 12, 'twelve months'),
       assert(digits.length == 10, 'ten digits'),
       assert(dayPeriods.length == 2, 'morning and afternoon');

  /// The texts of a language, by key of [flDateFieldL10n]. Throws a
  /// [FormatException] that names the missing or malformed key.
  factory FlDateFieldStrings.fromTable(Map<String, String> table) {
    String t(String key) => table[key] ?? (throw FormatException('key $key missing from the date field table'));
    List<String> list(String key, int length) {
      final items = t(key).split(',');
      if (items.length != length) {
        throw FormatException('$key: $length comma-separated items expected, ${items.length} read');
      }
      return items;
    }

    const letters = {'d': FlDateSegment.day, 'm': FlDateSegment.month, 'y': FlDateSegment.year};
    final order = [for (final letter in t('dateFieldOrder').split('')) letters[letter]];
    if (order.length != 3 || order.contains(null) || order.toSet().length != 3) {
      throw FormatException('dateFieldOrder: d, m and y once each expected, "${t('dateFieldOrder')}" read');
    }
    final cycle = t('timeFieldHourCycle');
    if (cycle != '12' && cycle != '24') {
      throw FormatException('timeFieldHourCycle: 12 or 24 expected, "$cycle" read');
    }
    if (t('dateFieldDigits').length != 10) {
      throw const FormatException('dateFieldDigits: ten digits expected');
    }
    final placeholders = list('dateFieldPlaceholders', 3);
    final names = list('dateFieldNames', FlDateSegment.values.length);
    return FlDateFieldStrings(
      order: [for (final segment in order) segment!],
      separator: t('dateFieldSeparator'),
      placeholders: {
        FlDateSegment.day: placeholders[0],
        FlDateSegment.month: placeholders[1],
        FlDateSegment.year: placeholders[2],
      },
      names: {for (final (i, segment) in FlDateSegment.values.indexed) segment: names[i]},
      empty: t('dateFieldEmpty'),
      months: list('dateFieldMonths', 12),
      digits: t('dateFieldDigits'),
      hour12: cycle == '12',
      dayPeriods: list('timeFieldDayPeriods', 2),
      timeSeparator: t('timeFieldSeparator'),
    );
  }

  /// The texts of [flDateFieldL10n] in [language] (`en`, `fr` or `ar`),
  /// English for another language.
  factory FlDateFieldStrings.language(String language) {
    final code = languages.contains(language) ? language : 'en';
    return FlDateFieldStrings.fromTable({for (final entry in flDateFieldL10n.entries) entry.key: entry.value[code]!});
  }

  /// The texts in the language of the nearest `Localizations`. A language
  /// missing from [flDateFieldL10n] fails with an assertion in debug mode,
  /// and takes English in release.
  factory FlDateFieldStrings.of(BuildContext context) {
    final language = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    assert(
      languages.contains(language),
      'FlDateField: no texts for "$language" ($languages only). Pass strings, '
      'built by FlDateFieldStrings.fromTable.',
    );
    return FlDateFieldStrings.language(language);
  }

  /// The languages of [flDateFieldL10n].
  static final Set<String> languages = flDateFieldL10n.values.first.keys.toSet();

  /// The order of the day, the month and the year (`[month, day, year]` in
  /// American English).
  final List<FlDateSegment> order;

  /// What separates the segments of a date ("/").
  final String separator;

  /// The text of an empty date segment ("dd", "mm", "yyyy").
  final Map<FlDateSegment, String> placeholders;

  /// The name of each segment for the screen reader ("day").
  final Map<FlDateSegment, String> names;

  /// The spoken value of an empty segment.
  final String empty;

  /// The names of the months, from January to December, read with the month number.
  final List<String> months;

  /// The digits from 0 to 9.
  final String digits;

  /// True: the hour goes from 1 to 12, followed by the morning or the afternoon.
  final bool hour12;

  /// The morning and the afternoon ("AM", "PM").
  final List<String> dayPeriods;

  /// What separates the hour from the minute (":").
  final String timeSeparator;

  /// [value] written with [digits], padded with zeros up to [width] digits.
  String number(int value, {int width = 1}) =>
      value.toString().padLeft(width, '0').split('').map((c) => digits[int.parse(c)]).join();

  /// The digit from 0 to 9 that [character] writes, in Latin digits or in
  /// those of [digits]; null for another character.
  int? digitOf(String character) {
    final latin = int.tryParse(character);
    if (latin != null && character.length == 1) return latin;
    final local = digits.indexOf(character);
    return local < 0 ? null : local;
  }
}

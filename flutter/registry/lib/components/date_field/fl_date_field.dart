// Modified from the DateField of HeroUI React v3, Copyright 2020 Next UI Inc.,
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
import 'package:fliin_ui/components/date_field/fl_segmented_field.dart';
import 'package:fliin_ui/icons/fl_icons.dart';

export 'package:fliin_ui/components/date_field/fl_segmented_field.dart';

/// Keyboard entry of a date, by segments: the
/// day, the month and the year in the language's order ("jj/mm/aaaa" in
/// French, "mm/dd/yyyy" in English), each read by the screen reader under
/// its name and value, and adjustable through the increase and decrease
/// gestures.
///
/// For a date the user knows, which they type faster than they would look
/// it up (birth, document expiry). For a date chosen within a month,
/// `date-picker`.
///
/// The input and the keyboard are those of [FlSegmentedField]. The date is
/// sent to [onChanged] as soon as the three segments are filled, the day
/// clamped to the last of the month (February 31: 28 or 29); a segment
/// emptied afterwards returns `null`. The field shows [value]: a date the
/// app does not pass back reverts to the app's.
class FlDateField extends StatelessWidget {
  /// A field whose date is [value].
  const FlDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.error,
    this.required = false,
    this.autofocus = false,
    this.strings,
    this.leading,
    this.showIcon = true,
    this.variant = FlInputVariant.primary,
  });

  /// True: the first empty segment takes the focus on first render.
  final bool autofocus;

  /// The field's name, displayed above and read by the screen reader.
  final String label;

  /// The date, without time; null with no value.
  final DateTime? value;

  /// Receives `DateTime(year, month, day)` when the date is complete, or
  /// `null` when it stops being so; null disables the field.
  final ValueChanged<DateTime?>? onChanged;

  /// The help under the field, hidden by [error].
  final String? description;

  /// When non-null: the field is invalid (a date outside the app's bounds),
  /// and this text replaces [description].
  final String? error;

  /// True: an asterisk follows the label, and the field announces itself required.
  final bool required;

  /// The order, the texts and the digits; those of the app's language by
  /// default.
  final FlDateFieldStrings? strings;

  /// See [FlSegmentedField.leading]: an icon or a word before the segments.
  final Widget? leading;

  /// True: the `calendar` icon at the end of the field; false,
  /// none, for a field that carries its own [leading].
  final bool showIcon;

  /// See [FlSegmentedField.variant].
  final FlInputVariant variant;

  @override
  Widget build(BuildContext context) {
    final strings = this.strings ?? FlDateFieldStrings.of(context);
    final value = this.value;
    final onChanged = this.onChanged;
    return FlSegmentedField(
      label: label,
      segments: strings.order,
      values: value == null
          ? const {}
          : {FlDateSegment.day: value.day, FlDateSegment.month: value.month, FlDateSegment.year: value.year},
      strings: strings,
      description: description,
      error: error,
      icon: showIcon ? FlIcons.calendar : null,
      leading: leading,
      variant: variant,
      required: required,
      autofocus: autofocus,
      complete: (values) {
        final year = values[FlDateSegment.year]!;
        final month = values[FlDateSegment.month]!;
        final last = DateTime(year, month + 1, 0).day;
        final day = values[FlDateSegment.day]!;
        return {...values, FlDateSegment.day: day > last ? last : day};
      },
      onChanged: onChanged == null
          ? null
          : (values) => onChanged(
              values == null
                  ? null
                  : DateTime(values[FlDateSegment.year]!, values[FlDateSegment.month]!, values[FlDateSegment.day]!),
            ),
    );
  }
}

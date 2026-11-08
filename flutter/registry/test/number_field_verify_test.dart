import 'package:fliin_ui/components/number_field/fl_number_field.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une valeur, une borne atteinte, la variante `secondary`, une erreur et un
/// champ désactivé, puis un prix à deux décimales ; en arabe, les chiffres
/// arabes orientaux.
Widget _fields(BuildContext context, {required bool rtl}) {
  final digits = FlIntegerFormat(digits: rtl ? FlDigits.arabicIndic : FlDigits.latin);
  FlNumberField field(
    String fr,
    String ar,
    double value, {
    String? helper,
    String? error,
    FlInputVariant variant = FlInputVariant.primary,
    bool enabled = true,
  }) => FlNumberField(
    label: tr(rtl, fr, ar),
    value: value,
    min: 1,
    max: 10,
    format: digits,
    helper: helper,
    error: error,
    variant: variant,
    enabled: enabled,
    decrementLabel: tr(rtl, 'Decrease', 'إنقاص'),
    incrementLabel: tr(rtl, 'Increase', 'زيادة'),
    onChanged: (_) {},
  );
  return Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    // Localizations impose le sens de sa langue : la variante garde le sien.
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: overlayPage(
        context,
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: FlScope.of(context).space.md,
          children: [
            field('Quantity', 'الكمية', 2, helper: tr(rtl, '10 at most', '١٠ على الأكثر')),
            field('Travelers', 'المسافرون', 1),
            field('Nights', 'الليالي', 3, variant: FlInputVariant.secondary),
            field('Seats', 'المقاعد', 12, error: tr(rtl, '10 seats left', 'بقي ١٠ مقاعد')),
            field('Rooms', 'الغرف', 4, enabled: false),
            FlNumberField(
              label: tr(rtl, 'Price', 'السعر'),
              value: 1234.5,
              min: 0,
              step: 0.5,
              format: FlDecimalFormat(
                suffix: ' €',
                decimalSeparator: rtl ? '٫' : ',',
                groupSeparator: rtl ? '٬' : ' ',
                digits: rtl ? FlDigits.arabicIndic : FlDigits.latin,
              ),
              decrementLabel: tr(rtl, 'Decrease', 'إنقاص'),
              incrementLabel: tr(rtl, 'Increase', 'زيادة'),
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'number-field',
  testFile: 'test/number_field_verify_test.dart',
  size: const Size(390, 1240),
  settle: const Duration(milliseconds: 300),
  showcase: _fields,
);

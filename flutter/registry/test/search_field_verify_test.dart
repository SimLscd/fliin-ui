import 'package:fliin_ui/components/search_field/fl_search_field.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Vide, saisi avec son bouton d'effacement, `secondary`, invalide et
/// désactivé. `DefaultWidgetsLocalizations` pose une direction de gauche à
/// droite : celle de la variante est remise dessous.
Widget _fields(BuildContext context, {required bool rtl}) {
  final label = tr(rtl, 'Search', 'بحث');
  final clear = tr(rtl, 'Clear search', 'مسح البحث');
  final placeholder = tr(rtl, 'Search…', 'ابحث…');
  final query = tr(rtl, 'Apple', 'تفاح');
  return Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: overlayPage(
        context,
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: FlScope.of(context).space.lg,
          children: [
            FlSearchField(label: label, clearLabel: clear, placeholder: placeholder),
            FlSearchField(
              label: label,
              clearLabel: clear,
              controller: TextEditingController(text: query),
            ),
            FlSearchField(
              label: label,
              clearLabel: clear,
              controller: TextEditingController(text: query),
              variant: FlInputVariant.secondary,
              searchIcon: false,
            ),
            FlSearchField(
              label: label,
              clearLabel: clear,
              controller: TextEditingController(text: query),
              invalid: true,
            ),
            FlSearchField(
              label: label,
              clearLabel: clear,
              controller: TextEditingController(text: query),
              disabled: true,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'search-field',
  testFile: 'test/search_field_verify_test.dart',
  size: const Size(390, 600),
  showcase: _fields,
);

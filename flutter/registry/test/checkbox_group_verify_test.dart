import 'package:fliin_ui/components/checkbox_group/fl_checkbox_group.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un groupe décrit, une case cochée, une case avec son aide et une case
/// désactivée ; puis un groupe requis et invalide, avec son erreur ; un groupe
/// sous « Tout choisir » à moitié coché ; des cases sur leurs cartes.
Widget _groups(BuildContext context, {required bool rtl}) => Localizations(
  locale: Locale(rtl ? 'ar' : 'en'),
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: Directionality(
    textDirection: Directionality.of(context),
    child: Builder(
      builder: (context) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Padding(
          padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: FlScope.of(context).space.xl,
            children: [
              FlCheckboxGroup<String>(
                label: tr(rtl, 'Interests', 'الاهتمامات'),
                description: tr(rtl, 'Choose everything you like', 'اختر كل ما يناسبك'),
                value: const {'cuisine'},
                onChanged: (_) {},
                options: [
                  FlCheckboxGroupOption(value: 'cuisine', label: tr(rtl, 'Cooking', 'الطبخ')),
                  FlCheckboxGroupOption(
                    value: 'voyage',
                    label: tr(rtl, 'Travel', 'السفر'),
                    description: tr(rtl, 'Stays and deals', 'رحلات وعروض'),
                  ),
                  FlCheckboxGroupOption(value: 'sport', label: tr(rtl, 'Sports', 'الرياضة'), disabled: true),
                ],
              ),
              FlCheckboxGroup<String>(
                label: tr(rtl, 'Alerts', 'التنبيهات'),
                required: true,
                invalid: true,
                error: tr(rtl, 'Choose at least one channel', 'اختر قناة واحدة على الأقل'),
                value: const {},
                onChanged: (_) {},
                options: [
                  FlCheckboxGroupOption(value: 'mail', label: tr(rtl, 'Email', 'البريد')),
                  const FlCheckboxGroupOption(value: 'sms', label: 'SMS'),
                ],
              ),
              FlCheckboxGroup<String>(
                label: tr(rtl, 'Toppings', 'الإضافات'),
                selectAllLabel: tr(rtl, 'Select all', 'اختيار الكل'),
                value: const {'olives'},
                onChanged: (_) {},
                options: [
                  FlCheckboxGroupOption(value: 'olives', label: tr(rtl, 'Olives', 'زيتون')),
                  FlCheckboxGroupOption(value: 'basilic', label: tr(rtl, 'Basil', 'ريحان')),
                ],
              ),
              FlCheckboxGroup<String>(
                label: tr(rtl, 'Options', 'الخيارات'),
                framed: true,
                value: const {'bagage'},
                onChanged: (_) {},
                options: [
                  FlCheckboxGroupOption(
                    value: 'bagage',
                    label: tr(rtl, 'Checked bag', 'حقيبة مشحونة'),
                    description: tr(rtl, '23 kg, €35', '٢٣ كغ، ٣٥ €'),
                  ),
                  FlCheckboxGroupOption(value: 'siege', label: tr(rtl, 'Seat selection', 'مقعد مختار')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() => verifyItem(
  item: 'checkbox-group',
  testFile: 'test/checkbox_group_verify_test.dart',
  size: const Size(390, 2000),
  showcase: _groups,
);

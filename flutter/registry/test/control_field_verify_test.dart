import 'package:fliin_ui/components/control_field/fl_control_field.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un interrupteur allumé avec sa description, une case requise invalide
/// avec son erreur, un radio désactivé, et une case cochée focalisée au
/// clavier. `RawRadio` lit les localisations, que le harnais ne pose pas.
Widget _fields(BuildContext context, {required bool rtl}) => Localizations(
  locale: Locale(rtl ? 'ar' : 'en'),
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: Directionality(
    textDirection: Directionality.of(context),
    child: Builder(
      builder: (context) => columnPage(context, [
        FlControlField(
          value: true,
          onChanged: (_) {},
          label: tr(rtl, 'Notifications', 'الإشعارات'),
          description: tr(rtl, 'Sounds and banners', 'الأصوات والتنبيهات'),
        ),
        FlControlField(
          value: false,
          onChanged: (_) {},
          indicator: FlControlFieldIndicator.checkbox,
          invalid: true,
          required: true,
          label: tr(rtl, 'Terms accepted', 'قبول الشروط'),
          error: tr(rtl, 'Required', 'مطلوب'),
        ),
        FlControlField(
          value: true,
          onChanged: null,
          indicator: FlControlFieldIndicator.radio,
          label: tr(rtl, 'Airplane mode', 'وضع الطيران'),
          description: tr(rtl, 'Unavailable', 'غير متاح'),
        ),
        FlControlField(
          value: true,
          onChanged: (_) {},
          indicator: FlControlFieldIndicator.checkbox,
          label: tr(rtl, 'Remember me', 'تذكرني'),
        ),
      ]),
    ),
  ),
);

void main() => verifyItem(
  item: 'control-field',
  testFile: 'test/control_field_verify_test.dart',
  size: const Size(390, 900),
  showcase: _fields,
);

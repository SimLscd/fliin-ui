import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/fieldset/fl_fieldset.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un groupe titré et décrit avec ses deux champs et ses actions, puis un
/// groupe en erreur, comme `verify.entry`. `DefaultWidgetsLocalizations`
/// pose une direction de gauche à droite : celle de la variante est remise
/// dessous.
Widget _fieldsets(BuildContext context, {required bool rtl}) => Localizations(
  locale: const Locale('en'),
  delegates: const [DefaultWidgetsLocalizations.delegate],
  child: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: overlayPage(
      context,
      (context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: FlScope.of(context).space.xxl,
          children: [
            FlFieldset(
              legend: tr(rtl, 'Profile', 'الملف الشخصي'),
              description: tr(rtl, 'Visible on your public page.', 'يظهر في صفحتك العامة.'),
              actions: [
                FlButton(label: tr(rtl, 'Save', 'حفظ'), onPressed: () {}),
                FlButton(label: tr(rtl, 'Cancel', 'إلغاء'), variant: FlButtonVariant.tertiary, onPressed: () {}),
              ],
              children: [
                FlTextField(
                  label: tr(rtl, 'Name', 'الاسم'),
                  required: true,
                  controller: TextEditingController(text: tr(rtl, 'Camille Martin', 'ليلى حداد')),
                ),
                FlTextField(label: tr(rtl, 'Email', 'البريد الإلكتروني'), placeholder: 'camille@example.com'),
              ],
            ),
            FlFieldset(
              legend: tr(rtl, 'Shipping', 'التوصيل'),
              description: tr(rtl, 'Where to send the order.', 'أين نرسل الطلب.'),
              error: tr(rtl, 'Enter a shipping address.', 'أدخل عنوان التوصيل.'),
              children: [FlTextField(label: tr(rtl, 'Address', 'العنوان'))],
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() => verifyItem(
  item: 'fieldset',
  testFile: 'test/fieldset_verify_test.dart',
  size: const Size(390, 640),
  showcase: _fieldsets,
);

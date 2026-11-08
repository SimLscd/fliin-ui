import 'package:fliin_ui/components/input_otp/fl_input_otp.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// En cours de saisie (case active), un code PIN à placeholder, invalide et
/// désactivé. `DefaultWidgetsLocalizations` pose une direction de gauche à
/// droite : celle de la variante est remise dessous.
Widget _codes(BuildContext context, {required bool rtl}) {
  final label = tr(rtl, 'Verification code', 'رمز التحقق');
  return Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultWidgetsLocalizations.delegate],
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: overlayPage(
        context,
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: FlScope.of(context).space.lg,
          children: [
            FlInputOtp(
              label: label,
              groups: const [3, 3],
              controller: TextEditingController(text: '12'),
              autofocus: true,
            ),
            FlInputOtp(label: tr(rtl, 'PIN code', 'الرمز السري'), groups: const [4], placeholder: '0000'),
            FlInputOtp(
              label: label,
              groups: const [3, 3],
              controller: TextEditingController(text: '123456'),
              invalid: true,
            ),
            FlInputOtp(
              label: label,
              groups: const [3, 3],
              controller: TextEditingController(text: '123'),
              disabled: true,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'input-otp',
  testFile: 'test/input_otp_verify_test.dart',
  size: const Size(390, 320),
  showcase: _codes,
);

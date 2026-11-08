import 'package:fliin_ui/components/input_group/fl_input_group.dart';
import 'package:fliin_ui/components/text_field/fl_text_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Préfixe, suffixe, les deux en erreur, et le groupe désactivé.
/// `DefaultWidgetsLocalizations` pose une direction de gauche à droite : celle
/// de la variante est remise dessous.
Widget _groups(BuildContext context, {required bool rtl}) => Localizations(
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
          FlInputGroup(
            prefix: const Text('https://'),
            decorativePrefix: true,
            child: FlInput(label: tr(rtl, 'Website', 'الموقع'), placeholder: tr(rtl, 'example', 'مثال')),
          ),
          FlInputGroup(
            suffix: const Text('€'),
            decorativeSuffix: true,
            child: FlInput(
              label: tr(rtl, 'Amount', 'المبلغ'),
              controller: TextEditingController(text: '42'),
            ),
          ),
          FlInputGroup(
            prefix: const Text('https://'),
            suffix: const Text('.com'),
            decorativePrefix: true,
            decorativeSuffix: true,
            child: FlInput(
              label: tr(rtl, 'Website', 'الموقع'),
              controller: TextEditingController(text: 'fliin'),
              invalid: true,
            ),
          ),
          FlInputGroup(
            prefix: const Text('@'),
            decorativePrefix: true,
            disabled: true,
            child: FlInput(
              label: tr(rtl, 'Username', 'المعرّف'),
              controller: TextEditingController(text: 'demo'),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() => verifyItem(
  item: 'input-group',
  testFile: 'test/input_group_verify_test.dart',
  size: const Size(390, 520),
  showcase: _groups,
);

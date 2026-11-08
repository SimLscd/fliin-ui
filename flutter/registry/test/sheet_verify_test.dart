import 'package:fliin_ui/components/progress/fl_progress.dart';
import 'package:fliin_ui/components/sheet/fl_sheet.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une feuille modale ouverte sur son premier arrêt, au-dessus d'une liste :
/// titre, texte et bouton de fermeture en tête, comme chez HeroUI.
Widget _sheet(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  return Stack(
    fit: StackFit.expand,
    children: [
      columnPage(context, [
        for (final (fr, ar) in [('Vacation photo', 'صورة العطلة'), ('Facture', 'فاتورة'), ('Notes', 'ملاحظات')])
          showcaseText(context, tr(rtl, fr, ar)),
      ]),
      FlSheet(
        label: tr(rtl, 'Share', 'مشاركة'),
        title: tr(rtl, 'Share', 'مشاركة'),
        description: tr(rtl, 'Send a copy or copy the link.', 'أرسل نسخة أو انسخ الرابط.'),
        closeLabel: tr(rtl, 'Close', 'إغلاق'),
        barrierLabel: tr(rtl, 'Close the sheet', 'إغلاق الورقة'),
        snaps: const [0.6, 1],
        onDismiss: () {},
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.md,
            children: [
              showcaseText(context, tr(rtl, 'Send a copy', 'إرسال نسخة')),
              showcaseText(context, tr(rtl, 'Copy link', 'نسخ الرابط')),
              FlProgress.linear(value: 0.3, label: tr(rtl, 'Preparing the link', 'تحضير الرابط')),
            ],
          ),
        ),
      ),
    ],
  );
}

void main() => verifyItem(
  item: 'sheet',
  testFile: 'test/sheet_verify_test.dart',
  size: const Size(390, 700),
  showcase: _sheet,
  frameAllowances: (theme) => squareFillOnPage(theme, (c) => c.control, 1.11),
);

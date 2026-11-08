import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/dialog/fl_dialog.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un dialogue ouvert sur une page voilée, routes posées d'emblée : la
/// route du dialogue est alors à son terme. Bouton de fermeture en tête,
/// actions sm comme chez HeroUI, titre long. Le corps tient sans défiler à
/// 2,0×, pour que le golden le montre entier. Le défilement est dans
/// fl_dialog_test.
Widget _dialog(BuildContext context, {required bool rtl}) => Navigator(
  onGenerateInitialRoutes: (navigator, _) => [
    PageRouteBuilder<void>(
      pageBuilder: (context, _, _) => ColoredBox(
        color: FlScope.of(context).colors.surface,
        child: Padding(
          padding: EdgeInsetsDirectional.all(FlScope.of(context).space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: FlScope.of(context).space.md,
            children: [
              showcaseText(context, tr(rtl, 'report.pdf', 'التقرير.pdf')),
              FlButton(label: tr(rtl, 'Delete the file', 'حذف الملف'), onPressed: () {}),
            ],
          ),
        ),
      ),
    ),
    FlDialogRoute<bool>(
      context: context,
      barrierLabel: tr(rtl, 'Close', 'إغلاق'),
      builder: (context) => FlDialog(
        title: tr(
          rtl,
          'Permanently delete “annual report 2026.pdf”?',
          'حذف «التقرير السنوي 2026.pdf» نهائيًا؟',
        ),
        content: Text(
          tr(rtl, 'The file will stay in the trash for 30 days.', 'سينقل الملف إلى سلة المهملات لمدة 30 يومًا.'),
        ),
        closeLabel: tr(rtl, 'Close', 'إغلاق'),
        actions: [
          FlButton(
            label: tr(rtl, 'Cancel', 'إلغاء'),
            variant: FlButtonVariant.ghost,
            size: FlButtonSize.sm,
            onPressed: () {},
          ),
          FlButton(label: tr(rtl, 'Delete', 'حذف'), size: FlButtonSize.sm, onPressed: () {}),
        ],
      ),
    ),
  ],
);

void main() => verifyItem(
  item: 'dialog',
  testFile: 'test/dialog_verify_test.dart',
  size: const Size(390, 640),
  settle: overlaySettle,
  showcase: _dialog,
);

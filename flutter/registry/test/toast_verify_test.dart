import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/toast/fl_toast.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Trois variantes, posées comme un toaster les affiche : un bouton de
/// fermeture, une icône et une description, une action ; puis l'icône du
/// statut (`showIcon`) avec une action `danger`, et un toast en chargement.
Widget _toasts(BuildContext context, {required bool rtl}) => columnPage(context, [
  FlToast(title: tr(rtl, 'Link copied', 'تم نسخ الرابط'), closeLabel: tr(rtl, 'Close', 'إغلاق')),
  FlToast(
    title: tr(rtl, 'Profile saved', 'تم حفظ الملف'),
    description: tr(rtl, 'Visible to the team.', 'يراه فريقك.'),
    variant: FlToastVariant.success,
    icon: Builder(
      builder: (context) => SizedBox.square(
        dimension: IconTheme.of(context).size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: IconTheme.of(context).color, shape: BoxShape.circle),
        ),
      ),
    ),
  ),
  FlToast(
    title: tr(rtl, 'Couldn’t send', 'تعذّر الإرسال'),
    variant: FlToastVariant.danger,
    action: FlToastAction(label: tr(rtl, 'Try again', 'إعادة'), onPressed: () {}),
  ),
  FlToast(
    title: tr(rtl, 'Storage full', 'التخزين ممتلئ'),
    variant: FlToastVariant.warning,
    showIcon: true,
    action: FlToastAction(label: tr(rtl, 'Empty', 'إفراغ'), variant: FlButtonVariant.danger, onPressed: () {}),
  ),
  FlToast(title: tr(rtl, 'Sending…', 'جارٍ الإرسال…'), loading: true),
]);

void main() => verifyItem(
  item: 'toast',
  testFile: 'test/toast_verify_test.dart',
  size: const Size(390, 1300),
  settle: const Duration(milliseconds: 400),
  showcase: _toasts,
);

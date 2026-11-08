import 'package:fliin_ui/components/alert/fl_alert.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les cinq statuts, titre et description ; le dernier avec sa propre
/// icône, sans description.
Widget _alerts(BuildContext context, {required bool rtl}) => columnPage(context, [
  for (final (status, title, description) in [
    (
      FlAlertStatus.neutral,
      tr(rtl, 'New features', 'ميزات جديدة'),
      tr(rtl, 'Dark mode is available.', 'الوضع الداكن متاح.'),
    ),
    (
      FlAlertStatus.accent,
      tr(rtl, 'Update ready', 'التحديث جاهز'),
      tr(rtl, 'Restart to install it.', 'أعد التشغيل لتثبيته.'),
    ),
    (
      FlAlertStatus.success,
      tr(rtl, 'Profile saved', 'تم حفظ الملف'),
      tr(rtl, 'Your team can see it.', 'يراه فريقك.'),
    ),
    (
      FlAlertStatus.warning,
      tr(rtl, 'Scheduled maintenance', 'صيانة مجدولة'),
      tr(rtl, 'Sunday from 2 AM to 4 AM.', 'الأحد من 2 إلى 4.'),
    ),
    (
      FlAlertStatus.danger,
      tr(rtl, 'Can’t connect', 'تعذر الاتصال'),
      tr(rtl, 'Check your network.', 'تحقق من شبكتك.'),
    ),
  ])
    FlAlert(status: status, title: title, description: description),
  FlAlert(status: FlAlertStatus.success, title: tr(rtl, 'Copied', 'تم النسخ'), showIcon: false),
  FlAlert(
    status: FlAlertStatus.danger,
    title: tr(rtl, 'Couldn’t send', 'تعذّر الإرسال'),
    description: tr(rtl, 'Try this:', 'جرّب ما يلي:'),
    content: Text(tr(rtl, '• Check the network', '• تحقق من الشبكة')),
    action: FlButton(
      label: tr(rtl, 'Try again', 'إعادة'),
      size: FlButtonSize.sm,
      variant: FlButtonVariant.danger,
      onPressed: () {},
    ),
    trailing: FlCloseButton(label: tr(rtl, 'Close', 'إغلاق'), onPressed: () {}),
  ),
]);

void main() =>
    verifyItem(item: 'alert', testFile: 'test/alert_verify_test.dart', size: const Size(390, 2400), showcase: _alerts);

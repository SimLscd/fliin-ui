import 'package:fliin_ui/components/text/fl_text.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un titre, un paragraphe, un texte atténué et du code.
Widget _texts(BuildContext context, {required bool rtl}) => columnPage(context, [
  FlText(tr(rtl, 'Settings', 'الإعدادات'), type: FlTextType.h2),
  FlText(tr(rtl, 'Privacy', 'الخصوصية'), type: FlTextType.h5),
  FlText(tr(rtl, 'Your data stays on this device.', 'تبقى بياناتك على هذا الجهاز.')),
  FlText(
    tr(rtl, 'Last synced at 9:41', 'آخر مزامنة الساعة 9:41'),
    type: FlTextType.bodySm,
    tone: FlTextTone.muted,
  ),
  const FlText('flutter pub get', type: FlTextType.code),
]);

void main() =>
    verifyItem(item: 'text', testFile: 'test/text_verify_test.dart', size: const Size(390, 820), showcase: _texts);

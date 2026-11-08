import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/link_button/fl_link_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les trois tailles, un lien désactivé, et deux liens dans une phrase.
Widget _links(BuildContext context, {required bool rtl}) {
  return columnPage(context, [
    for (final size in FlButtonSize.values)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FlLinkButton(label: tr(rtl, 'Learn more', 'معرفة المزيد'), size: size, underline: true, onPressed: () {}),
      ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlLinkButton(label: tr(rtl, 'Privacy', 'سياسة الخصوصية'), underline: true, onPressed: null),
    ),
    Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        showcaseText(context, tr(rtl, 'I accept the ', 'أوافق على '), role: FlTextRole.textSm),
        FlLinkButton(label: tr(rtl, 'terms', 'الشروط'), size: FlButtonSize.sm, link: true, underline: true, onPressed: () {}),
        showcaseText(context, tr(rtl, ' and the ', ' وكذلك '), role: FlTextRole.textSm),
        FlLinkButton(
          label: tr(rtl, 'privacy policy', 'الخصوصية'),
          size: FlButtonSize.sm,
          link: true,
          underline: true,
          onPressed: () {},
        ),
      ],
    ),
  ]);
}

void main() => verifyItem(
  item: 'link-button',
  testFile: 'test/link_button_verify_test.dart',
  size: const Size(390, 560),
  showcase: _links,
);

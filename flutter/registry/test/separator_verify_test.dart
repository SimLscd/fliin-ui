import 'package:fliin_ui/components/separator/fl_separator.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un trait fin entre deux lignes, un trait épais entre deux blocs, un
/// trait vertical entre deux mots.
Widget _separators(BuildContext context, {required bool rtl}) => columnPage(context, [
  showcaseText(context, tr(rtl, 'Dark mode', 'الوضع الداكن')),
  Padding(
    padding: EdgeInsetsDirectional.symmetric(vertical: FlScope.of(context).space.sm),
    child: const FlSeparator(),
  ),
  showcaseText(context, tr(rtl, 'Notifications', 'الإشعارات')),
  Padding(
    padding: EdgeInsetsDirectional.symmetric(vertical: FlScope.of(context).space.sm),
    child: const FlSeparator(variant: FlSeparatorVariant.thick),
  ),
  SizedBox(
    height: 32,
    child: Row(
      spacing: FlScope.of(context).space.sm,
      children: [
        Flexible(child: showcaseText(context, tr(rtl, 'Wi-Fi', 'واي فاي'))),
        const FlSeparator(axis: Axis.vertical),
        Flexible(child: showcaseText(context, tr(rtl, 'Bluetooth', 'بلوتوث'))),
      ],
    ),
  ),
]);

void main() => verifyItem(
  item: 'separator',
  testFile: 'test/separator_verify_test.dart',
  size: const Size(390, 420),
  showcase: _separators,
);

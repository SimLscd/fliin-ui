import 'package:fliin_ui/components/close_button/fl_close_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Actif, pressé et désactivé.
Widget _closeButtons(BuildContext context, {required bool rtl}) {
  final label = tr(rtl, 'Close', 'إغلاق');
  return columnPage(context, [
    Row(
      spacing: FlScope.of(context).space.lg,
      children: [
        FlCloseButton(label: label, onPressed: () {}),
        FlCloseButton(label: label, onPressed: () {}, statesController: WidgetStatesController({WidgetState.pressed})),
        FlCloseButton(label: label, onPressed: null),
      ],
    ),
  ]);
}

void main() => verifyItem(
  item: 'close-button',
  testFile: 'test/close_button_verify_test.dart',
  size: const Size(390, 120),
  settle: const Duration(milliseconds: 400),
  showcase: _closeButtons,
);

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/tooltip/fl_tooltip.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Deux infobulles visibles : au-dessus d'un bouton, et retournée sous un
/// bouton collé en haut.
Widget _tooltips(BuildContext context, {required bool rtl}) {
  final help = FlTooltipController();
  final save = FlTooltipController();
  return OnMount(
    open: () {
      help.show();
      save.show();
    },
    child: overlayPage(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: FlTooltip(
              message: tr(rtl, 'Help and shortcuts', 'المساعدة والاختصارات'),
              controller: help,
              child: FlButton(label: tr(rtl, 'Help', 'مساعدة'), variant: FlButtonVariant.ghost, onPressed: () {}),
            ),
          ),
          Center(
            child: FlTooltip(
              message: tr(rtl, 'Save draft', 'حفظ المسودة'),
              controller: save,
              child: FlButton(label: tr(rtl, 'Save', 'حفظ'), onPressed: () {}),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'tooltip',
  testFile: 'test/tooltip_verify_test.dart',
  size: const Size(390, 520),
  settle: overlaySettle,
  showcase: _tooltips,
);

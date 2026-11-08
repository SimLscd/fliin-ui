import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/popover/fl_popover.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Deux popovers ouverts : l'un sous son ancre en haut, avec titre, texte,
/// bouton de fermeture et action, l'autre retourné au-dessus de la sienne en
/// bas, aligné sur sa fin, avec sa flèche.
Widget _popovers(BuildContext context, {required bool rtl}) {
  final filters = FlPopoverController();
  final help = FlPopoverController();
  return OnMount(
    open: () {
      filters.open();
      help.open();
    },
    child: overlayPage(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: FlPopover(
              controller: filters,
              label: tr(rtl, 'Filters', 'عوامل التصفية'),
              title: tr(rtl, 'Filters', 'عوامل التصفية'),
              description: tr(rtl, 'Newest first', 'الأحدث أولاً'),
              closeLabel: tr(rtl, 'Close', 'إغلاق'),
              content: FlButton(label: tr(rtl, 'Apply', 'تطبيق'), onPressed: () {}),
              child: FlButton(
                label: tr(rtl, 'Filters', 'عوامل التصفية'),
                variant: FlButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: FlPopover(
              controller: help,
              label: tr(rtl, 'Help', 'مساعدة'),
              align: FlAlign.end,
              arrow: true,
              description: tr(rtl, 'Drag to reorder', 'اسحب لإعادة الترتيب'),
              child: FlButton(label: tr(rtl, 'Help', 'مساعدة'), variant: FlButtonVariant.ghost, onPressed: () {}),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'popover',
  testFile: 'test/popover_verify_test.dart',
  size: const Size(390, 840),
  settle: overlaySettle,
  showcase: _popovers,
);

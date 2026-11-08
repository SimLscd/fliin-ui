import 'package:fliin_ui/components/select/fl_select.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Un select sans choix, désactivé, puis un select ouvert, l'option choisie
/// cochée et une option avec texte.
Widget _selects(BuildContext context, {required bool rtl}) {
  final controller = FlSelectController();
  return OnMount(
    open: controller.open,
    child: overlayPage(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: FlScope.of(context).space.md,
        children: [
          FlSelect<int>(
            label: tr(rtl, 'Size', 'الحجم'),
            placeholder: tr(rtl, 'Choose a size', 'اختر حجمًا'),
            options: const [],
            selection: const FlSingleSelection(value: null, onChanged: null),
          ),
          FlSelect<int>(
            controller: controller,
            label: tr(rtl, 'Fruit', 'الفاكهة'),
            placeholder: tr(rtl, 'Choose a fruit', 'اختر فاكهة'),
            listLabel: tr(rtl, 'Fruits', 'الفواكه'),
            options: [
              FlSelectOption(value: 0, label: tr(rtl, 'Apple', 'تفاح')),
              FlSelectOption(
                value: 1,
                label: tr(rtl, 'Orange', 'برتقال'),
                description: tr(rtl, 'Full of vitamin C', 'غني بفيتامين سي'),
              ),
              FlSelectOption(value: 2, label: tr(rtl, 'Banana', 'موز')),
            ],
            selection: FlSingleSelection(value: 0, onChanged: (_) {}),
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'select',
  testFile: 'test/select_verify_test.dart',
  size: const Size(390, 600),
  settle: overlaySettle,
  showcase: _selects,
);

import 'package:fliin_ui/components/chip/fl_chip.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

const _fr = ['New', 'Draft', 'Paid', 'Pending', 'Declined'];
const _ar = ['جديد', 'مسودة', 'مدفوع', 'قيد الانتظار', 'مرفوض'];

/// Toute la matrice des remplissages et des couleurs, puis les trois tailles
/// d'une puce pressable. La matrice est en lg : en md, la marge de 12 est
/// plus courte que le rayon de 14, les coins de la page entrent dans le cadre
/// du libellé, et la règle de contraste de Flutter, qui partage les couleurs
/// du cadre à la clarté moyenne, oppose alors la page au fond d'un libellé
/// sombre (thème de torture B, 2,19 au lieu de 8). La pressable est neutre :
/// sa cible de 44 met la page dans le cadre du nœud.
Widget _chips(BuildContext context, {required bool rtl}) {
  final gap = FlScope.of(context).space.sm;
  final labels = rtl ? _ar : _fr;
  return columnPage(context, [
    for (final variant in FlChipVariant.values)
      Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final color in FlChipColor.values)
            FlChip(label: labels[color.index], variant: variant, color: color, size: FlChipSize.lg),
        ],
      ),
    Wrap(
      spacing: gap,
      runSpacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final size in FlChipSize.values)
          FlChip(
            label: labels[1],
            variant: FlChipVariant.secondary,
            color: FlChipColor.neutral,
            size: size,
            onPressed: () {},
          ),
      ],
    ),
  ]);
}

void main() => verifyItem(
  item: 'chip',
  testFile: 'test/chip_verify_test.dart',
  size: const Size(390, 2400),
  showcase: _chips,
  frameAllowances: (theme) => squareFillOnPage(theme, (c) => c.success, 3.9),
);

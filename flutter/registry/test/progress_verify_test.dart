import 'package:fliin_ui/components/progress/fl_progress.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// L'indéterminé rendu immobile, comme en mouvement réduit : le harnais
/// capture au premier frame, où l'animé n'a encore rien dessiné.
Widget _still(BuildContext context, Widget child) =>
    MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child);

/// Une barre légendée, les trois tailles en trois couleurs, l'indéterminé, et
/// les trois anneaux, puis un anneau légendé.
Widget _progress(BuildContext context, {required bool rtl}) => columnPage(context, [
  FlProgress.linear(value: 0.4, label: tr(rtl, 'Uploading', 'الرفع'), showLabel: true),
  for (final size in FlProgressSize.values)
    FlProgress.linear(
      value: 0.7,
      size: size,
      color: FlProgressColor.values[size.index + 2],
      label: tr(rtl, 'Storage', 'التخزين'),
    ),
  _still(context, FlProgress.linear(label: tr(rtl, 'Preparing', 'التحضير'))),
  Row(
    spacing: FlScope.of(context).space.lg,
    children: [
      for (final (i, size) in FlProgressSize.values.indexed)
        FlProgress.circular(
          value: 0.7,
          size: size,
          color: FlProgressColor.values[i],
          label: tr(rtl, 'Syncing', 'المزامنة'),
        ),
    ],
  ),
  FlProgress.circular(value: 0.75, size: FlProgressSize.sm, label: tr(rtl, 'Profile', 'الملف'), showLabel: true),
]);

void main() => verifyItem(
  item: 'progress',
  testFile: 'test/progress_verify_test.dart',
  size: const Size(390, 430),
  showcase: _progress,
);

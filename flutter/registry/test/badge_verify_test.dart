import 'package:fliin_ui/components/badge/fl_badge.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Une case de 40 nommée, comme une icône d'application, que la pastille
/// marque.
Widget _anchor(BuildContext context, String label) {
  final theme = FlScope.of(context);
  return Semantics(
    label: label,
    child: SizedBox.square(
      dimension: theme.space.xs * 10,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: theme.colors.control,
          shape: FlContinuousBorder(radius: theme.shape.radiusXl),
        ),
      ),
    ),
  );
}

/// Les trois remplissages dans les cinq couleurs, puis les trois tailles, le
/// compte plafonné, un mot, un point et les quatre coins.
Widget _badges(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final gap = theme.space.lg;
  final inbox = tr(rtl, 'Messages', 'الرسائل');
  Widget row(List<Widget> children) => Padding(
    padding: EdgeInsetsDirectional.symmetric(vertical: theme.space.sm),
    child: Wrap(spacing: gap, runSpacing: gap, children: children),
  );
  return columnPage(context, [
    for (final variant in FlBadgeVariant.values)
      row([
        for (final color in FlBadgeColor.values)
          FlBadge.count(
            count: 5,
            semanticLabel: tr(rtl, '5 unread', '5 غير مقروءة'),
            variant: variant,
            color: color,
            size: FlBadgeSize.sm,
            child: _anchor(context, inbox),
          ),
      ]),
    row([
      for (final size in FlBadgeSize.values)
        FlBadge.count(count: 120, color: FlBadgeColor.danger, size: size, child: _anchor(context, inbox)),
    ]),
    row([
      FlBadge.text(
        text: tr(rtl, 'New', 'جديد'),
        color: FlBadgeColor.accent,
        size: FlBadgeSize.sm,
        child: _anchor(context, tr(rtl, 'What’s new', 'الجديد')),
      ),
      for (final placement in FlBadgePlacement.values)
        FlBadge.dot(
          semanticLabel: tr(rtl, 'online', 'متصل'),
          color: FlBadgeColor.success,
          placement: placement,
          child: _anchor(context, tr(rtl, 'Jane', 'جين')),
        ),
    ]),
  ]);
}

void main() =>
    verifyItem(item: 'badge', testFile: 'test/badge_verify_test.dart', size: const Size(390, 900), showcase: _badges);

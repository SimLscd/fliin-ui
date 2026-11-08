import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les deux fonds dans les cinq couleurs, aux initiales, puis la silhouette
/// dans les trois tailles.
Widget _avatars(BuildContext context, {required bool rtl}) {
  final gap = FlScope.of(context).space.sm;
  return columnPage(context, [
    for (final variant in FlAvatarVariant.values)
      Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final color in FlAvatarColor.values)
            FlAvatar(
              initials: tr(rtl, 'JD', 'ج د'),
              semanticLabel: tr(rtl, 'Jane Doe', 'جين دو'),
              variant: variant,
              color: color,
            ),
        ],
      ),
    Wrap(
      spacing: gap,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final size in FlAvatarSize.values) FlAvatar(size: size, semanticLabel: tr(rtl, 'Guest', 'ضيف'))],
    ),
  ]);
}

void main() => verifyItem(
  item: 'avatar',
  testFile: 'test/avatar_verify_test.dart',
  size: const Size(390, 900),
  settle: const Duration(milliseconds: 400),
  showcase: _avatars,
);

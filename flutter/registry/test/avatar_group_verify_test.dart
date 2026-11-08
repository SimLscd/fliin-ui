import 'package:fliin_ui/components/avatar/fl_avatar.dart';
import 'package:fliin_ui/components/avatar_group/fl_avatar_group.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

List<FlAvatar> _people(bool rtl) => [
  FlAvatar(initials: tr(rtl, 'JD', 'ج د'), semanticLabel: tr(rtl, 'Jane Doe', 'جين دو')),
  FlAvatar(
    initials: tr(rtl, 'KW', 'ك و'),
    semanticLabel: tr(rtl, 'Kate Wilson', 'كيت ويلسون'),
    color: FlAvatarColor.success,
  ),
  FlAvatar(
    initials: tr(rtl, 'EC', 'إ ت'),
    semanticLabel: tr(rtl, 'Emily Chen', 'إميلي تشن'),
    color: FlAvatarColor.warning,
  ),
  FlAvatar(semanticLabel: tr(rtl, 'Guest', 'ضيف'), variant: FlAvatarVariant.soft, color: FlAvatarColor.danger),
];

/// Les trois tailles d'un groupe en croissant (xl, la tête d'un profil, n'en
/// fait pas), au-delà de deux avatars ; l'anneau ;
/// tous les avatars sans compteur.
Widget _groups(BuildContext context, {required bool rtl}) {
  String others(int n) => tr(rtl, 'and $n more', 'و$n آخرين');
  return columnPage(context, [
    for (final size in FlAvatarSize.values.where((size) => size != FlAvatarSize.xl))
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FlAvatarGroup(avatars: _people(rtl), max: 2, total: 8, size: size, countLabel: others),
      ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlAvatarGroup(avatars: _people(rtl), max: 3, overlap: FlAvatarGroupOverlap.ring, countLabel: others),
    ),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: FlAvatarGroup(avatars: _people(rtl), size: FlAvatarSize.sm),
    ),
  ]);
}

void main() => verifyItem(
  item: 'avatar-group',
  testFile: 'test/avatar_group_verify_test.dart',
  size: const Size(390, 900),
  settle: const Duration(milliseconds: 400),
  showcase: _groups,
);

import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/icon_set.g.dart';
import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les icônes du jeu à la taille par défaut, puis les directionnelles, la
/// lecture et le cœur plein à la taille et à la couleur d'un `IconTheme`.
Widget _icons(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  return columnPage(context, [
    Wrap(
      spacing: theme.space.lg,
      runSpacing: theme.space.lg,
      children: [for (final (:icon, name: _, contours: _) in iconSet) FlIcon(icon)],
    ),
    SizedBox(height: theme.space.xl),
    IconTheme(
      data: IconThemeData(size: theme.size.buttonIconLg, color: theme.colors.accent),
      child: Row(
        spacing: theme.space.lg,
        children: [
          FlIcon(FlIcons.arrowLeft),
          FlIcon(FlIcons.chevronRight),
          FlIcon(FlIcons.paperPlane),
          FlIcon(FlIcons.playFill),
          FlIcon(FlIcons.heartFill),
        ],
      ),
    ),
  ]);
}

void main() =>
    verifyItem(item: 'icons', testFile: 'test/icons_verify_test.dart', size: const Size(390, 600), showcase: _icons);

import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/components/toggle_button/fl_toggle_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:fliin_ui/icons/fl_icons.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Éteint et allumé, plein puis `ghost`, avec texte puis en icône seule
/// dans les trois tailles, et désactivé, comme `verify.entry`.
Widget _toggles(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  final favorite = tr(rtl, 'Favorite', 'مفضلة');
  final bookmark = tr(rtl, 'Save', 'حفظ');
  Widget row(List<Widget> children) => Wrap(spacing: theme.space.sm, runSpacing: theme.space.sm, children: children);
  return scrollPage(context, [
    row([
      for (final on in [false, true])
        FlToggleButton(
          label: favorite,
          selected: on,
          leading: FlIcon(on ? FlIcons.heartFill : FlIcons.heart),
          onChanged: (_) {},
        ),
      for (final on in [false, true])
        FlToggleButton(
          label: bookmark,
          selected: on,
          variant: FlToggleButtonVariant.ghost,
          leading: FlIcon(FlIcons.bookmark),
          onChanged: (_) {},
        ),
    ]),
    row([
      for (final size in FlButtonSize.values)
        for (final on in [false, true])
          FlToggleButton.icon(
            label: favorite,
            selected: on,
            size: size,
            icon: FlIcon(on ? FlIcons.starFill : FlIcons.star),
            onChanged: (_) {},
          ),
    ]),
    row([
      for (final on in [false, true])
        FlToggleButton(label: favorite, selected: on, leading: FlIcon(FlIcons.heart), onChanged: null),
    ]),
  ]);
}

void main() => verifyItem(
  item: 'toggle-button',
  testFile: 'test/toggle_button_verify_test.dart',
  size: const Size(390, 360),
  showcase: _toggles,
);

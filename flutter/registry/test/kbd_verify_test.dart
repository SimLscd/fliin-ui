import 'package:fliin_ui/components/kbd/fl_kbd.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Des raccourcis à modificateurs, les touches spéciales et les flèches sur
/// leur fond, puis deux raccourcis sans fond dans une phrase, comme
/// `verify.entry`.
Widget _keys(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  Widget row(List<Widget> children) => Wrap(
    spacing: theme.space.sm,
    runSpacing: theme.space.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
  return scrollPage(context, [
    row([
      FlKbd(keys: const [FlKbdKey.command], text: 'K', semanticLabel: tr(rtl, 'Command K', 'أمر K')),
      const FlKbd(keys: [FlKbdKey.command, FlKbdKey.shift], text: 'Z'),
      const FlKbd(keys: [FlKbdKey.option, FlKbdKey.control], text: 'F'),
      const FlKbd(keys: [FlKbdKey.enter]),
      const FlKbd(keys: [FlKbdKey.escape]),
      const FlKbd(keys: [FlKbdKey.tab]),
    ]),
    row(const [
      FlKbd(keys: [FlKbdKey.up]),
      FlKbd(keys: [FlKbdKey.down]),
      FlKbd(keys: [FlKbdKey.left]),
      FlKbd(keys: [FlKbdKey.right]),
      FlKbd(keys: [FlKbdKey.space]),
      FlKbd(keys: [FlKbdKey.delete]),
    ]),
    row([
      showcaseText(context, tr(rtl, 'Copy', 'نسخ'), role: FlTextRole.textSm),
      const FlKbd(keys: [FlKbdKey.command], text: 'C', variant: FlKbdVariant.light),
      showcaseText(context, tr(rtl, 'Paste', 'لصق'), role: FlTextRole.textSm),
      const FlKbd(keys: [FlKbdKey.command], text: 'V', variant: FlKbdVariant.light),
    ]),
  ]);
}

void main() =>
    verifyItem(item: 'kbd', testFile: 'test/kbd_verify_test.dart', size: const Size(390, 260), showcase: _keys);

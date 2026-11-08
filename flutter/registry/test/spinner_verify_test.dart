import 'package:fliin_ui/components/spinner/fl_spinner.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Immobile, comme en mouvement réduit : le harnais capture la rotation à un
/// instant qui dépend des frames.
Widget _still(BuildContext context, Widget child) =>
    MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child);

/// Les trois tailles, puis les quatre couleurs.
Widget _spinners(BuildContext context, {required bool rtl}) {
  final label = tr(rtl, 'Loading', 'جارٍ التحميل');
  final gap = FlScope.of(context).space.lg;
  return _still(
    context,
    columnPage(context, [
      Row(
        spacing: gap,
        children: [for (final size in FlSpinnerSize.values) FlSpinner(label: label, size: size)],
      ),
      Row(
        spacing: gap,
        children: [for (final tone in FlSpinnerTone.values) FlSpinner(label: label, tone: tone)],
      ),
    ]),
  );
}

void main() => verifyItem(
  item: 'spinner',
  testFile: 'test/spinner_verify_test.dart',
  size: const Size(390, 160),
  showcase: _spinners,
);

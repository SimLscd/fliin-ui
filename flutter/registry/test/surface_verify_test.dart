import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:flutter/widgets.dart';

import 'support/showcase.dart';
import 'support/verify_item.dart';

/// Les quatre variantes, un texte dans chacune.
Widget _surfaces(BuildContext context, {required bool rtl}) => columnPage(context, [
  for (final (variant, fr, ar) in [
    (FlSurfaceVariant.primary, 'Pro subscription', 'اشتراك احترافي'),
    (FlSurfaceVariant.secondary, 'Next invoice on March 3', 'الفاتورة القادمة في 3 مارس'),
    (FlSurfaceVariant.tertiary, 'Payment method', 'وسيلة الدفع'),
    (FlSurfaceVariant.transparent, 'History', 'السجل'),
  ])
    FlSurface(variant: variant, child: showcaseText(context, tr(rtl, fr, ar))),
]);

void main() => verifyItem(
  item: 'surface',
  testFile: 'test/surface_verify_test.dart',
  size: const Size(390, 760),
  showcase: _surfaces,
);

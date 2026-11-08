import 'package:fliin_ui/components/color_field/fl_color_field.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  String tr(String fr, String ar) => rtl ? ar : fr;
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.lg,
        children: [
          FlColorField(
            label: tr('Color', 'اللون'),
            value: HSVColor.fromAHSV(1, 208, 0.98, 0.97).toColor(),
            onChanged: (_) {},
          ),
          FlColorField(
            label: tr('Background color', 'لون الخلفية'),
            value: null,
            placeholder: '#FF5733',
            helper: tr('Six hexadecimal digits', 'ستة أرقام سداسية عشرية'),
            onChanged: (_) {},
          ),
          FlColorField(
            label: tr('Brand color', 'لون العلامة'),
            value: HSVColor.fromAHSV(1, 0, 0, 0).toColor(),
            required: true,
            error: tr('Choose a lighter color', 'اختر لونًا أفتح'),
            onChanged: (_) {},
          ),
          FlColorField(
            label: tr('Overlay', 'الطبقة'),
            value: HSVColor.fromAHSV(0.5, 217, 0.76, 0.96).toColor(),
            alpha: true,
            onChanged: (_) {},
          ),
          FlColorField(
            label: tr('Theme color', 'لون السمة'),
            value: HSVColor.fromAHSV(1, 160, 0.9, 0.73).toColor(),
            enabled: false,
            onChanged: (_) {},
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'color-field',
  testFile: 'test/color_field_verify_test.dart',
  size: const Size(390, 700),
  showcase: _showcase,
);

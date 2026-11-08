import 'package:fliin_ui/components/color_swatch/fl_color_swatch.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';

import 'support/verify_item.dart';

/// Le rendu de `verify.entry`.
Widget _showcase(BuildContext context, {required bool rtl}) {
  final theme = FlScope.of(context);
  String tr(String fr, String ar) => rtl ? ar : fr;
  final tints = [
    (tr('Blue', 'أزرق'), const HSVColor.fromAHSV(1, 217, 0.76, 0.96)),
    (tr('Pink', 'وردي'), const HSVColor.fromAHSV(1, 350, 0.74, 0.96)),
    (tr('Emerald', 'زمردي'), const HSVColor.fromAHSV(1, 160, 0.9, 0.73)),
    (tr('White', 'أبيض'), const HSVColor.fromAHSV(1, 0, 0, 0.98)),
  ];
  return ColoredBox(
    color: theme.colors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(theme.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.xl,
        children: [
          for (final shape in FlColorSwatchShape.values)
            Wrap(
              spacing: theme.space.md,
              runSpacing: theme.space.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final size in FlColorSwatchSize.values)
                  FlColorSwatch(color: tints.first.$2.toColor(), label: tints.first.$1, size: size, shape: shape),
              ],
            ),
          Wrap(
            spacing: theme.space.md,
            runSpacing: theme.space.md,
            children: [
              for (final (name, tint) in tints)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.xs,
                  children: [
                    FlColorSwatch(color: tint.toColor(), label: name, size: FlColorSwatchSize.xl),
                    ExcludeSemantics(
                      child: Text(
                        flColorHex(tint.toColor()),
                        textDirection: TextDirection.ltr,
                        style: theme.typography.resolve(FlTextRole.textXs).copyWith(color: theme.colors.onSurfaceMuted),
                      ),
                    ),
                  ],
                ),
              for (final (name, tint) in tints.take(3))
                FlColorSwatch(
                  color: tint.withAlpha(0.4).toColor(),
                  label: tr('$name at 40%', '$name ٤٠٪'),
                  size: FlColorSwatchSize.xl,
                  shape: FlColorSwatchShape.square,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() => verifyItem(
  item: 'color-swatch',
  testFile: 'test/color_swatch_verify_test.dart',
  size: const Size(390, 440),
  showcase: _showcase,
);

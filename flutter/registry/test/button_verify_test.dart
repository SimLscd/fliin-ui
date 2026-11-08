import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/button/fl_button.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/runs.dart';
import 'torture/themes.dart';

class _Showcase extends StatelessWidget {
  const _Showcase({required this.rtl});

  final bool rtl;

  String _t(String fr, String ar) => rtl ? ar : fr;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return ColoredBox(
      color: theme.colors.surface,
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.sm,
          children: [
            FlButton(label: _t('Save', 'حفظ التغييرات'), onPressed: () {}),
            FlButton(label: _t('Continue', 'متابعة'), variant: FlButtonVariant.secondary, onPressed: () {}),
            FlButton(label: _t('Cancel', 'إلغاء'), variant: FlButtonVariant.tertiary, onPressed: () {}),
            FlButton(label: _t('Edit', 'تعديل'), variant: FlButtonVariant.outline, onPressed: () {}),
            FlButton(label: _t('Learn more', 'معرفة المزيد'), variant: FlButtonVariant.ghost, onPressed: () {}),
            FlButton(label: _t('Delete', 'حذف'), variant: FlButtonVariant.danger, onPressed: () {}),
            FlButton(label: _t('Remove', 'إزالة'), variant: FlButtonVariant.dangerSoft, onPressed: () {}),
            FlButton(
              label: _t('Continue', 'متابعة'),
              variant: FlButtonVariant.secondary,
              statesController: WidgetStatesController({WidgetState.pressed}),
              onPressed: () {},
            ),
            FlButton(
              label: _t('Remove', 'إزالة'),
              variant: FlButtonVariant.dangerSoft,
              statesController: WidgetStatesController({WidgetState.pressed}),
              onPressed: () {},
            ),
            FlButton(label: _t('Sending', 'جارٍ الإرسال'), loading: true, onPressed: () {}),
            FlButton(label: _t('Unavailable', 'غير متاح'), onPressed: null),
          ],
        ),
      ),
    );
  }
}

String _out(FlTestTheme theme) => 'build/fliin/verify/button/${theme.id}';

void main() {
  setUpAll(loadTortureFonts);
  final runs = FlRuns();

  for (final theme in flTestThemes) {
    fliinVerify(
      item: 'button',
      version: '0.1.0',
      contrastExceptions: allowancesOf(theme.tokens),
      outDir: _out(theme),
      logicalSize: const Size(390, 1200),
      settle: const Duration(milliseconds: 400),
      onReport: (report) => runs.keep(_out(theme), report),
      entry: (context, variant) => FlScope(
        tokens: theme.tokens,
        density: theme.density,
        brightness: variant.brightness,
        platform: variant.platform,
        child: _Showcase(rtl: variant.dir == TextDirection.rtl),
      ),
    );
  }

  for (final theme in flTestThemes) {
    test(
      'devrait faire passer les 16 variantes du bouton, guidelines a11y comprises, sous le thème ${theme.id} '
      '(preuve 6, ADR §4.6)',
      () {
        expect(runs.report(_out(theme))['summary'], ['16/16 variants pass']);
        for (final variant in runs.variants(_out(theme))) {
          expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
          expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
        }
      },
    );
  }
}

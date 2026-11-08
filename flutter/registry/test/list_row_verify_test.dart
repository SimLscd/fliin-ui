import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/components/list_row/fl_list_row.dart';
import 'package:fliin_ui/components/surface/fl_surface.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/keyboard_highlight.dart';
import 'support/runs.dart';
import 'torture/themes.dart';

String _out(FlTestTheme theme) => 'build/fliin/verify/list_row/${theme.id}';

String _goldens(FlTestTheme theme) => 'test/goldens/list_row/${theme.id}';

class _Showcase extends StatelessWidget {
  const _Showcase({required this.rtl});

  final bool rtl;

  String _t(String fr, String ar) => rtl ? ar : fr;

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    final badge = SizedBox.square(
      dimension: theme.controlHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.accent,
          borderRadius: BorderRadius.circular(theme.shape.radiusControl),
        ),
      ),
    );
    return ColoredBox(
      color: theme.colors.surface,
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.lg,
          children: [
            FlListGroup(
              children: [
                FlListRow(
                  title: _t('Wi-Fi', 'واي فاي'),
                  subtitle: _t('Home', 'المنزل'),
                  leading: badge,
                  trailing: const FlListRowChevron(),
                  onPressed: () {},
                ),
                FlListRow(
                  title: _t('Notifications', 'الإشعارات'),
                  leading: badge,
                  value: _t('On', 'مفعّلة'),
                  trailing: const FlListRowChevron(),
                  onPressed: () {},
                ),
                FlListRow(
                  title: _t('Language', 'اللغة'),
                  value: _t('English', 'العربية'),
                  autofocus: true,
                  onPressed: () {},
                ),
                FlListRow(
                  title: _t('Bluetooth', 'بلوتوث'),
                  value: _t('Unavailable', 'غير متاح'),
                  enabled: false,
                  onPressed: () {},
                ),
              ],
            ),
            FlListGroup(
              variant: FlSurfaceVariant.secondary,
              children: [
                FlListRow(
                  title: _t('Privacy and data sharing', 'الخصوصية ومشاركة البيانات'),
                  subtitle: _t('Choose what apps see of your activity', 'اختر ما تراه التطبيقات من نشاطك'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadTortureFonts);
  final runs = FlRuns();

  for (final theme in flTestThemes) {
    fliinVerify(
      item: 'list_row',
      version: '0.1.0',
      contrastExceptions: allowancesOf(theme.tokens),
      outDir: _out(theme),
      goldens: macOSGoldens(_goldens(theme), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(_out(theme), report),
      logicalSize: const Size(390, 1360),
      entry: (context, variant) => FlScope(
        tokens: theme.tokens,
        density: theme.density,
        brightness: variant.brightness,
        platform: variant.platform,
        child: KeyboardHighlight(child: _Showcase(rtl: variant.dir == TextDirection.rtl)),
      ),
    );
  }

  for (final theme in flTestThemes) {
    test(
      'devrait passer les guidelines a11y et le layout sur les 16 variantes de la ligne sous le thème ${theme.id}',
      () {
        expect(runs.report(_out(theme))['summary'], ['16/16 variants pass']);
        for (final variant in runs.variants(_out(theme))) {
          expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
          expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
        }
      },
    );

    test('devrait rendre chaque variante de la ligne au pixel près de son golden macOS sous le thème ${theme.id}', () {
      final drifted = {
        for (final variant in runs.variants(_out(theme)))
          if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
            variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
      };
      expect(
        drifted,
        isEmpty,
        reason:
            'références ${_goldens(theme)}, produites sous macOS 27.2 arm64 (ADR 0005), '
            'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
            'flutter test --update-goldens test/list_row_verify_test.dart',
      );
    }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
  }
}

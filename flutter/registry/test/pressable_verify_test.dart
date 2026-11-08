import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/keyboard_highlight.dart';
import 'support/runs.dart';
import 'torture/themes.dart';

String _out(FlTestTheme theme) => 'build/fliin/verify/pressable/${theme.id}';

String _goldens(FlTestTheme theme) => 'test/goldens/pressable/${theme.id}';

class _Showcase extends StatelessWidget {
  const _Showcase({required this.rtl});

  final bool rtl;

  String _t(String fr, String ar) => rtl ? ar : fr;

  Widget _tile(BuildContext context, String text, {VoidCallback? onPressed, bool autofocus = false, String? label}) {
    final theme = FlScope.of(context);
    return FlPressable(
      onPressed: onPressed,
      autofocus: autofocus,
      label: label,
      borderRadius: theme.shape.buttonRadius,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.controlHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: disabled ? theme.colors.disabled : theme.colors.surfaceRaised,
              border: Border.all(color: theme.colors.border, width: theme.size.border),
              borderRadius: theme.shape.buttonRadius,
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.lg, vertical: theme.space.sm),
              child: Align(
                widthFactor: 1,
                child: Text(
                  text,
                  style: theme.typography
                      .resolve(FlTextRole.label)
                      .copyWith(color: disabled ? theme.colors.onDisabled : theme.colors.onSurface),
                  strutStyle: theme.typography.strut(
                    FlTextRole.label,
                    inheritedFamily: DefaultTextStyle.of(context).style.fontFamily,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
            _tile(context, _t('Press', 'اضغط'), onPressed: () {}, label: _t('Press', 'اضغط')),
            _tile(context, _t('Focused', 'محدد'), onPressed: () {}, autofocus: true),
            _tile(context, _t('Unavailable', 'غير متاح')),
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
      item: 'pressable',
      version: '0.1.0',
      contrastExceptions: allowancesOf(theme.tokens),
      outDir: _out(theme),
      goldens: macOSGoldens(_goldens(theme), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(_out(theme), report),
      logicalSize: const Size(390, 360),
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
    test('devrait passer les guidelines a11y et le layout sur les 16 variantes de FlPressable sous le thème ${theme.id}', () {
      expect(runs.report(_out(theme))['summary'], ['16/16 variants pass']);
      for (final variant in runs.variants(_out(theme))) {
        expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
        expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
      }
    });

    test(
      'devrait rendre chaque variante de FlPressable au pixel près de son golden macOS sous le thème ${theme.id}',
      () {
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
              'flutter test --update-goldens test/pressable_verify_test.dart',
        );
      },
      skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)',
    );
  }

  test('devrait refuser --update-goldens hors macOS et ne comparer aux goldens que sous macOS', () {
    expect(() => macOSGoldens('g', macOS: false, update: true), throwsStateError);
    expect(macOSGoldens('g', macOS: false, update: false), isNull);
    expect(macOSGoldens('g', macOS: true, update: true), 'g');
  });
}

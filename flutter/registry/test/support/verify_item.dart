import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../torture/themes.dart';
import 'allowances.dart';
import 'keyboard_highlight.dart';
import 'runs.dart';

/// Le rendu d'un élément pour une variante : [rtl] choisit les textes arabes.
typedef ItemShowcase = Widget Function(BuildContext context, {required bool rtl});

/// Rend [item] par le harnais sous chaque thème de test (16 variantes,
/// focus clavier visible), puis vérifie ses guidelines a11y et son layout,
/// et, sous macOS, chaque variante au pixel près de son golden
/// `test/goldens/<item>/<thème>/`. [testFile] est le fichier qui l'appelle,
/// cité pour régénérer les goldens. Un fichier de test par élément : deux
/// lots qui refont deux éléments n'écrivent jamais le même fichier.
void verifyItem({
  required String item,
  required String testFile,
  required Size size,
  Map<TargetPlatform, Size> platformSizes = const {},
  required ItemShowcase showcase,
  Duration? settle,
  String version = '0.1.0',
  Map<String, List<FlContrastAllowance>> Function(FlTestTheme theme)? frameAllowances,
}) {
  String out(FlTestTheme theme) => 'build/fliin/verify/$item/${theme.id}';
  String goldens(FlTestTheme theme) => 'test/goldens/$item/${theme.id}';

  setUpAll(loadTortureFonts);
  final runs = FlRuns();

  for (final theme in flTestThemes) {
    fliinVerify(
      item: item,
      version: version,
      contrastExceptions: [...allowancesOf(theme.tokens), ...?frameAllowances?.call(theme)[theme.id]],
      outDir: out(theme),
      goldens: macOSGoldens(goldens(theme), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(out(theme), report),
      logicalSize: size,
      platformSizes: platformSizes,
      settle: settle,
      entry: (context, variant) => FlScope(
        tokens: theme.tokens,
        density: theme.density,
        brightness: variant.brightness,
        platform: variant.platform,
        child: KeyboardHighlight(
          child: Builder(builder: (context) => showcase(context, rtl: variant.dir == TextDirection.rtl)),
        ),
      ),
    );
  }

  for (final theme in flTestThemes) {
    test('devrait passer les guidelines a11y et le layout sur les 16 variantes de $item sous le thème ${theme.id}', () {
      expect(runs.report(out(theme))['summary'], ['16/16 variants pass']);
      for (final variant in runs.variants(out(theme))) {
        expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
        expect(variant['a11yIncomplete'], isFalse, reason: '${variant['id']}');
      }
    });

    test('devrait rendre chaque variante de $item au pixel près de son golden macOS sous le thème ${theme.id}', () {
      final drifted = {
        for (final variant in runs.variants(out(theme)))
          if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
            variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
      };
      expect(
        drifted,
        isEmpty,
        reason:
            'références ${goldens(theme)}, produites sous macOS 27.2 arm64 (ADR 0005), '
            'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
            'flutter test --update-goldens $testFile',
      );
    }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
  }
}

/// Les cadres de libellé qui, sous torture B, débordent d'un aplat carré sur
/// la page : [fill] contre `surface`, sous le ratio [ratio] mesuré. Le rapport
/// les garde en avertissement.
Map<String, List<FlContrastAllowance>> squareFillOnPage(
  FlTestTheme theme,
  Color Function(FlColorTokens c) fill,
  double ratio,
) => {
  'torture-b': [
    for (final (brightness, colors) in [(Brightness.light, theme.tokens.light), (Brightness.dark, theme.tokens.dark)])
      (
        brightness: brightness,
        foreground: fill(colors),
        background: [colors.surface],
        ratio: ratio,
        reason: "faux positif de la règle de Flutter : sous torture B (aplats carrés, densité compacte), le cadre du libellé, agrandi de 4, déborde sur la page ; la règle oppose alors la page à l'aplat au lieu du texte, dont la couleur passe l'AA (ADR 0019 §6.1)",
      ),
  ],
};

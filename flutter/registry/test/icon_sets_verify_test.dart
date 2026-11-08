import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:fliin_harness/fliin_harness.dart';
import 'package:fliin_ui/core/fliin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/allowances.dart';
import 'support/icon_set.g.dart';
import 'support/keyboard_highlight.dart';
import 'support/runs.dart';
import 'support/showcase.dart';

/// Les 46 icônes d'un jeu à la taille par défaut, puis les directionnelles,
/// la lecture et le cœur plein à la taille et à la couleur d'un `IconTheme` :
/// la planche de `icons_verify_test.dart`, pour chaque autre jeu du
/// préréglage (ADR 0016 §3.8). Gravity UI, le défaut, reste dans celui-là.
Widget _board(BuildContext context, List<IconCase> icons) {
  final theme = FlScope.of(context);
  FlIconData named(String name) => icons.firstWhere((icon) => icon.name == name).icon;
  return columnPage(context, [
    Wrap(spacing: theme.space.lg, runSpacing: theme.space.lg, children: [for (final icon in icons) FlIcon(icon.icon)]),
    SizedBox(height: theme.space.xl),
    IconTheme(
      data: IconThemeData(size: theme.size.buttonIconLg, color: theme.colors.accent),
      child: Row(
        spacing: theme.space.lg,
        children: [
          for (final name in ['arrow-left', 'chevron-right', 'paper-plane', 'play-fill', 'heart-fill', 'star-fill'])
            FlIcon(named(name)),
        ],
      ),
    ),
  ]);
}

void main() {
  String out(String set) => 'build/fliin/verify/icon_sets/$set';
  String goldens(String set) => 'test/goldens/icon_sets/$set';
  final sets = {...iconSets}..remove('fliin');
  final runs = FlRuns();

  for (final MapEntry(key: set, value: icons) in sets.entries) {
    fliinVerify(
      item: 'icons-$set',
      version: '0.1.2',
      contrastExceptions: allowancesOf(FlTokens.defaults),
      outDir: out(set),
      goldens: macOSGoldens(goldens(set), macOS: Platform.isMacOS, update: autoUpdateGoldenFiles),
      onReport: (report) => runs.keep(out(set), report),
      logicalSize: const Size(390, 600),
      entry: (context, variant) => FlScope(
        brightness: variant.brightness,
        platform: variant.platform,
        child: KeyboardHighlight(child: Builder(builder: (context) => _board(context, icons))),
      ),
    );
  }

  test('devrait donner à chaque jeu les 46 icônes du contrat, dans le même ordre', () {
    final names = [for (final icon in iconSet) icon.name];
    expect(names, hasLength(46));
    expect(iconSets.keys, ['fliin', 'lucide', 'tabler', 'phosphor']);
    for (final MapEntry(key: set, value: icons) in iconSets.entries) {
      expect([for (final icon in icons) icon.name], names, reason: set);
    }
  });

  test('devrait garder le sens RTL de Fliin dans chaque jeu, quel que soit le jeu', () {
    for (final MapEntry(key: set, value: icons) in iconSets.entries) {
      expect(
        [
          for (final icon in icons)
            if (icon.icon.mirrorInRtl) icon.name,
        ],
        ['arrow-left', 'arrow-right', 'chevron-left', 'chevron-right', 'paper-plane'],
        reason: set,
      );
    }
  });

  for (final set in sets.keys) {
    test('devrait passer les guidelines a11y sur les 16 variantes du jeu $set', () {
      expect(runs.report(out(set))['summary'], ['16/16 variants pass']);
      for (final variant in runs.variants(out(set))) {
        expect(variant['a11y'], isEmpty, reason: '${variant['id']}');
      }
    });

    test('devrait rendre chaque variante du jeu $set au pixel près de son golden macOS', () {
      final drifted = {
        for (final variant in runs.variants(out(set)))
          if ((variant['golden']! as Map<String, Object?>)['diffPct'] != 0.0)
            variant['id']: (variant['golden']! as Map<String, Object?>)['diffPct'],
      };
      expect(
        drifted,
        isEmpty,
        reason:
            'références ${goldens(set)}, produites sous macOS 27.2 arm64 (ADR 0005), '
            'hôte ${Platform.operatingSystemVersion} ${Abi.current()} ; régénérer après un changement voulu : '
            'flutter test --update-goldens test/icon_sets_verify_test.dart',
      );
    }, skip: Platform.isMacOS ? false : 'goldens de référence produits sous macOS seulement (ADR 0005)');
  }
}

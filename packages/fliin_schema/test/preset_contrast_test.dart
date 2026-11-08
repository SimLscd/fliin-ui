import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

import 'theme_test.dart' show readTokens, registryJson, violations;

void main() {
  final registry = registryJson();

  test('devrait résoudre chaque base avec chaque primaire sans paire sous son seuil ni exception, hors couleurs du registre (ADR 0016 §6)', () {
    final failures = <String>[];
    for (final base in PresetBase.values) {
      for (final (primary, menu) in [
        for (final primary in PresetPrimary.values)
          if (primary != PresetPrimary.custom)
            for (final menu in PresetMenu.values) (primary, menu),
      ]) {
        final preset = Preset(base: base, primary: primary, menu: menu);
        if (preset.exactColors) continue;
        switch (applyPreset(registry, registry, preset)) {
          case ThemeSolved(:final patch):
            final tokens = readTokens(applyJsonPatch(registry, patch));
            for (final violation in violations(tokens)) {
              failures.add(
                '${preset.encode()} ($base, $primary, $menu) : $violation',
              );
            }
            if (tokens.contrastExceptions.isNotEmpty) {
              failures.add('${preset.encode()} : exceptions déclarées');
            }
          case Unsatisfiable(:final failing):
            failures.add(
              '${preset.encode()} ($base, $primary, $menu) : UNSATISFIABLE sur '
              '${failing.pair.foreground}/${failing.pair.background}',
            );
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('devrait garder hors du mélange exactement les primaires qui se confondent avec danger, sur toutes les bases', () {
    for (final base in PresetBase.values) {
      final clashing = {
        for (final primary in PresetPrimary.values)
          if (primary != PresetPrimary.custom &&
              !Preset(base: base, primary: primary).exactColors)
            if ((applyPreset(
              registry,
              registry,
              Preset(base: base, primary: primary),
            ) as ThemeSolved).clashes.isNotEmpty)
              primary,
      };
      expect(clashing, {
        for (final primary in PresetPrimary.values)
          if (!primary.shuffled && primary != PresetPrimary.custom) primary,
      }, reason: '$base');
    }
  });

  test('devrait ne tirer au hasard que des préréglages dont la primaire passe le mélange, et chaque valeur des champs de la version b', () {
    final random = math.Random(29);
    final seen = <String>{};
    for (var i = 0; i < 400; i++) {
      final preset = Preset.shuffle(random);
      expect(preset.primary.shuffled, isTrue);
      seen.addAll([
        'menu.${preset.menu.name}',
        'cards.${preset.cards.name}',
        'border.${preset.border.name}',
        'text.${preset.text.name}',
        'motion.${preset.motion.name}',
      ]);
    }
    expect(seen, hasLength(2 + 2 + 3 + 3 + 3));
  });

  test('devrait résoudre une marque libre sur chaque base quand le solveur trouve sa teinte, et dire la teinte conforme la plus proche sinon', () {
    final random = math.Random(5);
    var solved = 0;
    for (var i = 0; i < 60; i++) {
      final brand = Rgb8(random.nextInt(1 << 24));
      final preset = Preset(
        base: PresetBase.values[i % PresetBase.values.length],
        primary: PresetPrimary.custom,
        brand: brand,
      );
      switch (applyPreset(registry, registry, preset)) {
        case ThemeSolved(:final patch):
          solved++;
          final tokens = readTokens(applyJsonPatch(registry, patch));
          expect(violations(tokens), isEmpty, reason: brand.hex);
          expect(tokens.contrastExceptions, isEmpty);
        case Unsatisfiable(:final nearestHue, :final sameHue):
          expect(nearestHue ?? sameHue, isNotNull, reason: brand.hex);
      }
    }
    expect(solved, greaterThan(30));
  });

  test('devrait passer chaque paire sans exception sous le préréglage par défaut (ADR 0019)', () {
    final outcome =
        applyPreset(registry, registry, const Preset()) as ThemeSolved;
    expect(outcome.patch, isEmpty);
    final tokens = readTokens(registry);
    // Mesuré par la formule du test, une paire par fond et par apparence ;
    // les exceptions déclarées, autant de fois (B6).
    String mode(String appearance) =>
        appearance == 'light' ? 'clair' : 'sombre';
    expect(
      violations(tokens)..sort(),
      [
        for (final e in tokens.contrastExceptions)
          '${e.pair.foreground}/${e.pair.background} en ${mode(e.appearance)}',
      ]..sort(),
    );
  });
}

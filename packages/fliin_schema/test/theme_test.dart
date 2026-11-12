import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

const registryFile = '../../flutter/registry/lib/core/tokens/fliin.tokens.json';

Map<String, Object?> registryJson() =>
    jsonDecode(File(registryFile).readAsStringSync()) as Map<String, Object?>;

Oklch hex(String text) => toOklch(Rgb8.parse(text));

/// La formule de `flutter/registry/test/tokens_test.dart`, réécrite ici pour
/// ne pas vérifier le solveur avec son propre code.
double wcag(int argb) {
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(argb >> 16 & 0xFF) +
      0.7152 * channel(argb >> 8 & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double ratio(int a, int b) {
  final la = wcag(a);
  final lb = wcag(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

FliinTokens readTokens(Object? json) =>
    FliinTokens.read(resolveTokens(TokenDocument.fromJson(json)));

/// Les paires de [tokens] sous leur seuil, lues comme `tokens.g.dart` les
/// portera.
List<String> violations(FliinTokens tokens) => [
  for (final (name, colors) in [
    ('clair', tokens.light),
    ('sombre', tokens.dark),
  ])
    for (final pair in tokens.contrastPairs)
      if (ratio(
            colors[pair.foreground]!,
            composite([
              colors[pair.background]!,
              for (final role in pair.over) colors[role]!,
            ]).value,
          ) <
          (pair.kind == ContrastKind.text ? 4.5 : 3.0))
        '${pair.foreground}/${pair.background} en $name',
];

/// [json] dont les exceptions de contraste sont celles qu'il fait échouer,
/// sauf celles que [omit] écarte : un fichier retouché les redéclare, comme
/// `heroui_tokens.dart` le fait pour le registre.
Map<String, Object?> redeclared(
  Map<String, Object?> json, {
  bool Function(ContrastPair pair)? omit,
}) {
  final extensions = (json['color']! as Map)[r'$extensions']! as Map;
  extensions[FliinTokens.contrastExceptionsExtension] = <Object?>[];
  final tokens = readTokens(json);
  extensions[FliinTokens.contrastExceptionsExtension] = [
    for (final (appearance, colors) in [
      ('light', tokens.light),
      ('dark', tokens.dark),
    ])
      for (final pair in tokens.contrastPairs)
        if (pairContrast(pair, colors) case final ratio
            when ratio < contrastThreshold(pair.kind) &&
                !(omit?.call(pair) ?? false))
          {
            'foreground': pair.foreground,
            'background': pair.background,
            if (pair.over.isNotEmpty) 'over': pair.over,
            'kind': pair.kind.name,
            'appearance': appearance,
            'ratio': floorRatio(ratio),
            'reason': 'test',
          },
  ];
  return json;
}

/// [json] sans exception de contraste.
Map<String, Object?> withoutExceptions(Map<String, Object?> json) {
  ((json['color']! as Map)[r'$extensions']!
          as Map)[FliinTokens.contrastExceptionsExtension] =
      <Object?>[];
  return json;
}

/// [json] dont les teintes translucides sont écrites en valeur, plutôt que
/// par `$ref` vers la rampe d'accent ou vers `danger`.
Map<String, Object?> withLiteralTints(Map<String, Object?> json) {
  for (final appearance in ['light', 'dark']) {
    final roles = (json['color']! as Map)[appearance]! as Map;
    for (final role in [
      'accentSoft',
      'accentSoftPressed',
      'dangerSoft',
      'dangerSoftPressed',
      'selectedSoft',
    ]) {
      (roles[role]! as Map)[r'$value'] = {
        'colorSpace': 'srgb',
        'components': [0.5, 0.5, 0.5],
        'alpha': 0.15,
      };
    }
  }
  // Un halo reprend l'accent ou le danger par `$ref` : il prend sa
  // couleur écrite.
  for (final shadows in ((json['shadow']! as Map).entries)) {
    if (shadows.value is! Map) continue;
    for (final shadow in (shadows.value as Map).values) {
      for (final layer in (shadow as Map)[r'$value']! as List) {
        (layer as Map)['color'] = {
          'colorSpace': 'srgb',
          'components': [0.5, 0.5, 0.5],
          'alpha': 0.2,
        };
      }
    }
  }
  return json;
}

ThemeSolved solved(ThemeOutcome outcome) => switch (outcome) {
  final ThemeSolved solved => solved,
  Unsatisfiable(:final failing) => fail(
    'UNSATISFIABLE ${failing.pair.foreground}/${failing.pair.background}',
  ),
};

void main() {
  group('rôles discernables', () {
    test('devrait mesurer un ΔE OK de 1 entre le blanc et le noir et de 0 entre une couleur et elle-même', () {
      expect(
        deltaEOk(Rgb8.parse('#FFFFFF'), Rgb8.parse('#000000')),
        closeTo(1, 1e-3),
      );
      expect(deltaEOk(Rgb8.parse('#B3261E'), Rgb8.parse('#B3261E')), 0);
    });

    test('devrait signaler danger et accent confondus en clair quand la marque est le rouge de danger', () {
      final clashes = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#B3261E'))),
      ).clashes;
      expect(
        clashes.map((c) => (c.appearance, c.role, c.other)),
        contains((Appearance.light, 'danger', 'accent')),
      );
      expect(clashes.every((c) => c.deltaE < distinctDeltaE), isTrue);
    });

    test(
      'devrait ne rien signaler quand la marque est le bleu du registre',
      () {
        expect(
          solved(
            solveTheme(registryJson(), ThemeRequest(primary: hex('#0485F7'))),
          ).clashes,
          isEmpty,
        );
      },
    );
  });

  group('OKLCH', () {
    test(
      'devrait donner le rouge sRGB de CSS Color 4 quand on convertit #FF0000',
      () {
        final red = hex('#FF0000');
        expect(red.l, closeTo(0.62796, 1e-4));
        expect(red.c, closeTo(0.25768, 1e-4));
        expect(red.h, closeTo(29.2339, 1e-3));
      },
    );

    test('devrait retrouver chaque couleur sur 8 bits quand elle fait l’aller-retour par OKLCH', () {
      final random = math.Random(7);
      final colors = [
        for (var r = 0; r < 256; r += 17)
          for (var g = 0; g < 256; g += 17)
            for (var b = 0; b < 256; b += 17) Rgb8.channels(r, g, b),
        for (var i = 0; i < 2000; i++) Rgb8(random.nextInt(0x1000000)),
      ];
      for (final color in colors) {
        expect(fromOklch(toOklch(color)).color.hex, color.hex);
      }
    });

    test('devrait garder la plus grande chroma qui tient dans le gamut quand la demande en sort', () {
      const asked = (l: 0.7, c: 0.4, h: 140.0);
      final kept = fromOklch(asked).chroma;
      expect(kept, lessThan(asked.c));
      expect(fromOklch((l: 0.7, c: kept, h: 140)).chroma, kept);
      expect(
        fromOklch((l: 0.7, c: kept + 0.005, h: 140)).chroma,
        lessThan(kept + 0.005),
      );
      expect(toOklch(fromOklch(asked).color).h, closeTo(140, 1));
    });

    test(
      'devrait mesurer 21:1 et 4,54:1 quand on compare les références WCAG',
      () {
        expect(contrastRatio(Rgb8(0), Rgb8(0xFFFFFF)), closeTo(21, 1e-9));
        expect(
          contrastRatio(Rgb8.parse('#767676'), Rgb8(0xFFFFFF)),
          closeTo(4.54, 0.01),
        );
      },
    );
  });

  group('neutres', () {
    test('devrait redonner le neutre du registre au bit près quand le ton est sand', () {
      final neutral =
          (registryJson()['color']! as Map)['neutral']! as Map<String, Object?>;
      expect(neutral.keys, neutralRamp.keys);
      for (final MapEntry(key: step, value: token) in neutral.entries) {
        final value = (token! as Map)[r'$value']! as Map;
        expect(NeutralTone.sand.step(step).hex, value['hex'], reason: step);
      }
    });

    test('devrait laisser le fichier du registre intact, exceptions comprises, quand aucune marque n’est demandée', () {
      for (final tone in [null, NeutralTone.sand]) {
        final theme = solved(
          solveTheme(registryJson(), ThemeRequest(neutral: tone)),
        );
        expect(theme.patch, isEmpty, reason: '$tone');
        final exceptions = readTokens(registryJson()).contrastExceptions;
        expect(
          theme.contrast.where((c) => c.excused),
          hasLength(exceptions.length),
        );
        expect(theme.contrast.where((c) => !c.ok && !c.excused), isEmpty);
      }
    });

    test('devrait rendre le thème conforme, sans exception, quand la marque est celle du registre (ADR 0014)', () {
      final theme = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#0485F7'))),
      );
      final conform =
          applyJsonPatch(registryJson(), theme.patch)! as Map<String, Object?>;
      final tokens = readTokens(conform);
      expect(tokens.contrastExceptions, isEmpty);
      expect(violations(tokens), isEmpty);
      expect(theme.contrast.every((c) => c.ok), isTrue);
      expect(
        solved(solveTheme(conform, ThemeRequest(primary: hex('#0485F7'))))
            .patch,
        isEmpty,
      );
    });

    test('devrait garder la source d’une teinte et foncer le texte posé dessus quand ce texte échoue', () {
      // Le registre passe partout (ADR 0019) : une encre de succès et
      // d'alerte trop claire, celle de leur fond plein, échoue sur leur
      // fond doux.
      final json = registryJson();
      final light = (json['color']! as Map)['light']! as Map;
      for (final (ink, fill) in [
        ('onSuccessSoft', 'success'),
        ('onWarningSoft', 'warning'),
      ]) {
        (light[ink]! as Map)[r'$value'] = (light[fill]! as Map)[r'$value'];
      }
      final theme = solved(
        solveTheme(json, ThemeRequest(primary: hex('#0485F7'))),
      );
      final conform =
          applyJsonPatch(json, theme.patch)! as Map<String, Object?>;
      final before = readTokens(json), after = readTokens(conform);
      for (final role in ['success', 'warning']) {
        expect(after.light[role], before.light[role], reason: role);
      }
      for (final role in ['onSuccessSoft', 'onWarningSoft']) {
        expect(after.light[role], isNot(before.light[role]), reason: role);
      }
    });

    test('devrait décliner les neutres d’un fichier de core 0.1.x, ceux de HeroUI, quand le ton change (ADR 0019 §3)', () {
      final old = jsonDecode(
        File('test/fixtures/core-0.1.1.tokens.json').readAsStringSync(),
      ) as Map<String, Object?>;
      expect(
        solved(solveTheme(old, const ThemeRequest(neutral: NeutralTone.sand)))
            .patch,
        isEmpty,
      );
      final warm = solved(
        solveTheme(old, const ThemeRequest(neutral: NeutralTone.warm)),
      );
      expect([
        for (final op in warm.patch)
          if (op.op == PatchOperation.replace &&
              op.path.startsWith('/color/neutral/'))
            op.path,
      ], isNotEmpty);
      expect(warm.contrast.where((c) => !c.ok && !c.excused), isEmpty);
    });

    test('devrait donner des gris sans chroma quand le ton est neutral', () {
      for (final step in neutralRamp.keys) {
        final rgb = NeutralTone.neutral.step(step);
        expect([rgb.g, rgb.b], [rgb.r, rgb.r], reason: step);
      }
    });
  });

  group('solveur', () {
    test(
      'devrait garder la marque telle quelle en clair quand elle passe déjà',
      () {
        final theme = solved(
          solveTheme(registryJson(), ThemeRequest(primary: hex('#0047AB'))),
        );
        final tokens = readTokens(applyJsonPatch(registryJson(), theme.patch));
        expect(Rgb8(tokens.light['accent']!).hex, '#0047AB');
      },
    );

    test('devrait faire suivre la marque aux teintes translucides sans les réécrire', () {
      final theme = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#0047AB'))),
      );
      const tints = [
        'dangerSoft',
        'dangerSoftPressed',
        'successSoft',
        'warningSoft',
      ];
      expect(
        [
          for (final op in theme.patch)
            if (op.op != PatchOperation.test &&
                tints.any((tint) => op.path.contains('/$tint/')))
              op.path,
        ],
        isEmpty,
        reason: 'une teinte est un \$ref vers sa source',
      );
      final before = readTokens(registryJson());
      final tokens = readTokens(applyJsonPatch(registryJson(), theme.patch));
      for (final (colors, previous) in [
        (tokens.light, before.light),
        (tokens.dark, before.dark),
      ]) {
        for (final (tint, source) in [
          ('dangerSoft', 'danger'),
          ('dangerSoftPressed', 'danger'),
          ('successSoft', 'success'),
          ('warningSoft', 'warning'),
        ]) {
          expect(
            colors[tint]! & 0xFFFFFF,
            colors[source]! & 0xFFFFFF,
            reason: tint,
          );
          expect(
            colors[tint]! >>> 24,
            previous[tint]! >>> 24,
            reason: '$tint garde son opacité',
          );
        }
      }
      // Le halo du bouton principal reprend l'accent par `$ref`.
      expect(
        tokens.shadows['light']!['glow']!.first.color & 0xFFFFFF,
        0x0047AB,
      );
    });

    test('devrait éclaircir seul le texte d’accent sombre quand le fond d’accent doit foncer sous un texte blanc', () {
      final theme = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#0A6CFF'))),
      );
      final tokens = readTokens(applyJsonPatch(registryJson(), theme.patch));
      expect(
        ratio(tokens.dark['onAccent']!, tokens.dark['accentPressed']!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        ratio(tokens.dark['onAccentSoft']!, tokens.dark['surfacePressed']!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        toOklch(Rgb8(tokens.dark['onAccentSoft']!)).l,
        greaterThan(toOklch(Rgb8(tokens.dark['accent']!)).l),
      );
    });

    test('devrait assombrir l’accent clair jusqu’au seuil quand la marque manque de contraste', () {
      final theme = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#3B9BFF'))),
      );
      final tokens = readTokens(applyJsonPatch(registryJson(), theme.patch));
      final accent = Rgb8(tokens.light['accent']!);
      expect(toOklch(accent).l, lessThan(hex('#3B9BFF').l));
      expect(toOklch(accent).h, closeTo(hex('#3B9BFF').h, 2));
      expect(
        ratio(tokens.light['onAccent']!, tokens.light['accent']!),
        inInclusiveRange(4.5, 4.7),
      );
    });

    test('devrait garder la marque et blanchir le texte quand un cran de blanc suffit', () {
      final theme = solved(
        solveTheme(registryJson(), ThemeRequest(primary: hex('#0A6CFF'))),
      );
      final tokens = readTokens(applyJsonPatch(registryJson(), theme.patch));
      expect(Rgb8(tokens.light['accent']!).hex, '#0A6CFF');
      expect(
        ratio(tokens.light['onAccent']!, tokens.light['accent']!),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('devrait rendre le même patch octet pour octet quand la demande est la même', () {
      String run() => jsonEncode([
        for (final op in solved(
          solveTheme(
            registryJson(),
            ThemeRequest(primary: hex('#E4572E'), neutral: NeutralTone.warm),
          ),
        ).patch)
          patchOpJson(op),
      ]);
      expect(run(), run());
    });

    test('devrait ne plus rien changer quand on relance le même thème sur son résultat', () {
      const request = ThemeRequest(
        primary: (l: 0.6, c: 0.2, h: 30),
        neutral: NeutralTone.warm,
        button: ButtonShape.pill,
        radius: 6,
        font: NamedFont('Inter'),
      );
      final first = solved(solveTheme(registryJson(), request));
      expect(first.patch, isNotEmpty);
      final themed = applyJsonPatch(registryJson(), first.patch);
      expect(solved(solveTheme(themed, request)).patch, isEmpty);
    });
  });

  group('UNSATISFIABLE', () {
    final yellow = hex('#FFFF00');

    test('devrait proposer la même teinte moins saturée quand elle passe, avant la teinte voisine (n°4)', () {
      final json = registryJson();
      final green = hex('#00FF00');
      final outcome =
          solveTheme(json, ThemeRequest(primary: green)) as Unsatisfiable;
      final same = outcome.sameHue!;
      expect(same.chroma, lessThan(green.c));
      final replay = solved(
        solveTheme(json, ThemeRequest(primary: toOklch(same.primary))),
      );
      final accent = readTokens(applyJsonPatch(json, replay.patch))
          .light['accent']!;
      expect(Rgb8(accent).hex, same.primary.hex);
      expect(toOklch(same.primary).h, closeTo(green.h, 2));
      final richer = solveTheme(
        json,
        ThemeRequest(primary: (l: green.l, c: same.chroma * 1.05, h: green.h)),
      );
      expect(richer, isA<Unsatisfiable>());
    });

    test('devrait refuser un jaune pur avec la paire, le ratio atteint et le seuil', () {
      final outcome = solveTheme(registryJson(), ThemeRequest(primary: yellow));
      final failing = (outcome as Unsatisfiable).failing;
      expect(failing.appearance, Appearance.dark);
      expect(failing.pair.foreground, 'onAccent');
      expect(failing.pair.background, 'accent');
      expect(failing.threshold, 4.5);
      expect(failing.ratio, lessThan(4.5));
      expect(failing.ratio, greaterThan(1));
    });

    test('devrait proposer la teinte conforme la plus proche, aucune teinte plus proche ne l’étant', () {
      final json = registryJson();
      final nearest = (solveTheme(
        json,
        ThemeRequest(primary: yellow),
      ) as Unsatisfiable).nearestHue!;
      bool conforms(int hue) {
        final outcome = solveTheme(
          json,
          ThemeRequest(primary: (l: yellow.l, c: yellow.c, h: hue.toDouble())),
        );
        if (outcome is! ThemeSolved) return false;
        final accent = readTokens(applyJsonPatch(json, outcome.patch))
            .light['accent']!;
        return solveTheme(json, ThemeRequest(primary: toOklch(Rgb8(accent))))
            is ThemeSolved;
      }

      final origin = yellow.h.round();
      final distance = math.min(
        (nearest.hue - origin) % 360,
        (origin - nearest.hue) % 360,
      );
      expect(distance, greaterThan(0));
      for (var d = 1; d < distance; d++) {
        expect(conforms((origin + d) % 360), isFalse, reason: '+$d°');
        expect(conforms((origin - d) % 360), isFalse, reason: '-$d°');
      }
      expect(conforms(nearest.hue), isTrue);
    });

    test('devrait donner l’accent clair tel quel quand on relance avec la couleur proposée', () {
      final json = registryJson();
      final nearest = (solveTheme(
        json,
        ThemeRequest(primary: yellow),
      ) as Unsatisfiable).nearestHue!;
      final theme = solved(
        solveTheme(json, ThemeRequest(primary: toOklch(nearest.primary))),
      );
      expect(
        Rgb8(readTokens(applyJsonPatch(json, theme.patch)).light['accent']!)
            .hex,
        nearest.primary.hex,
      );
    });

    test('devrait ne proposer aucune teinte quand la marque est un gris', () {
      final json = registryJson();
      final color = json['color']! as Map<String, Object?>;
      color[r'$extensions'] = {
        FliinTokens.contrastExtension: [
          {'foreground': 'accent', 'background': 'onAccent', 'kind': 'text'},
          {'foreground': 'accent', 'background': 'onSurface', 'kind': 'text'},
        ],
      };
      final outcome = solveTheme(json, ThemeRequest(primary: hex('#808080')));
      expect(
        outcome,
        isA<Unsatisfiable>().having((e) => e.nearestHue, 'nearestHue', isNull),
      );
    });
  });

  group('réglages', () {
    test('devrait écrire la forme, le rayon et une police nommée que le profil relit', () {
      final json = registryJson();
      final theme = solved(
        solveTheme(
          json,
          ThemeRequest(
            primary: hex('#0485F7'),
            button: ButtonShape.pill,
            radius: 6,
            font: NamedFont('Inter'),
          ),
        ),
      );
      final tokens = readTokens(applyJsonPatch(json, theme.patch));
      expect(tokens.button, ButtonShape.pill);
      expect(tokens.radius['control'], 6);
      expect(tokens.fontFamily, {'ios': 'Inter', 'android': 'Inter'});
      expect(readTokens(json).fontFamily, {'ios': null, 'android': null});
    });

    test(
      'devrait faire précéder chaque remplacement d’un test sur la valeur lue',
      () {
        final theme = solved(
          solveTheme(
            registryJson(),
            const ThemeRequest(button: ButtonShape.rounded),
          ),
        );
        expect(
          [for (final op in theme.patch) patchOpJson(op)],
          [
            {
              'op': 'test',
              'path': r'/shape/button/$extensions/dev.fliin.buttonShape/value',
              'value': 'pill',
            },
            {
              'op': 'replace',
              'path': r'/shape/button/$extensions/dev.fliin.buttonShape/value',
              'value': 'rounded',
            },
          ],
        );
      },
    );

    test('devrait refuser un fichier dont le rôle accent n’est pas un alias de color.accent', () {
      final json = withoutExceptions(registryJson());
      ((json['color']! as Map)['light']! as Map)['accent'] = {
        r'$value': '{color.neutral.832}',
      };
      expect(
        () => solveTheme(json, ThemeRequest(primary: hex('#0485F7'))),
        throwsA(
          isA<MissingFliinToken>().having(
            (e) => e.path,
            'path',
            'color.light.accent',
          ),
        ),
      );
    });
  });

  test('devrait refuser un pas d’accent partagé par le clair et le sombre, que chaque apparence décale à part', () {
    final json = registryJson();
    ((json['color']! as Map)['dark']! as Map)['accent'] = {
      r'$value': '{color.accent.500}',
    };
    expect(
      () => solveTheme(json, ThemeRequest(primary: hex('#0485F7'))),
      throwsA(
        isA<MissingFliinToken>().having(
          (e) => e.path,
          'path',
          'color.accent.500',
        ),
      ),
    );
  });

  group('fichiers que le thème refuse', () {
    Map<String, Object?> at(Map<String, Object?> json, String path) {
      Object? node = json;
      for (final key in path.split('.')) {
        node = (node! as Map)[key];
      }
      return node! as Map<String, Object?>;
    }

    void expectRefused(Map<String, Object?> json, String path) => expect(
      () => solveTheme(json, ThemeRequest(primary: hex('#0A6CFF'))),
      throwsA(isA<MissingFliinToken>().having((e) => e.path, 'path', path)),
    );

    test('devrait refuser un rôle translucide, dont le contraste réel n’est pas celui d’une couleur pleine (n°1)', () {
      final json = registryJson();
      at(json, 'color.light')['onSurfaceMuted'] = {
        r'$value': {
          'colorSpace': 'srgb',
          'components': [0.0, 0.0, 0.0],
          'alpha': 0.15,
        },
      };
      expectRefused(json, 'color.light.onSurfaceMuted');
    });

    test('devrait refuser un pas d’accent translucide (n°1)', () {
      final json = registryJson();
      (at(json, 'color.accent.300')[r'$value']! as Map)['alpha'] = 0.3;
      expectRefused(json, 'color.dark.accent');
    });

    test('devrait refuser une rampe héritée par \$extends, qu’il ne peut ni lire ni réécrire à son emplacement (n°3)', () {
      final json = redeclared(withLiteralTints(registryJson()));
      final color = at(json, 'color');
      color['blue'] = color['accent'];
      color['accent'] = {r'$extends': '{color.blue}'};
      expect(readTokens(json).light['accent'], isNotNull);
      expectRefused(json, 'color.accent.100');
    });

    test('devrait refuser, sans marque, une paire non déclarée qui échoue entre deux couleurs que le thème ne bouge pas (n°7)', () {
      final json = registryJson();
      at(json, 'color.light')['onSurfaceMuted'] = {
        r'$value': {
          'colorSpace': 'srgb',
          'components': [0.6667, 0.6667, 0.6667],
          'hex': '#AAAAAA',
        },
      };
      redeclared(json, omit: (pair) => pair.foreground == 'onSurfaceMuted');
      expect(
        () => solveTheme(json, const ThemeRequest(button: ButtonShape.pill)),
        throwsA(
          isA<MissingFliinToken>().having(
            (e) => e.path,
            'path',
            'color.light.onSurfaceMuted',
          ),
        ),
      );
    });

    test('devrait déplacer une couleur écrite en valeur jusqu’au seuil quand une marque est demandée', () {
      final json = registryJson();
      at(json, 'color.light')['onSurfaceMuted'] = {
        r'$value': {
          'colorSpace': 'srgb',
          'components': [0.6667, 0.6667, 0.6667],
          'hex': '#AAAAAA',
        },
      };
      redeclared(json);
      final theme = solved(
        solveTheme(json, ThemeRequest(primary: hex('#0485F7'))),
      );
      expect(
        violations(readTokens(applyJsonPatch(json, theme.patch))),
        isEmpty,
      );
    });
  });

  group('sans --primary', () {
    test('devrait garder les pas d’accent du fichier, même retouchés, quand seule la forme change (n°2)', () {
      final json = registryJson();
      (((json['color']! as Map)['accent']! as Map)['600']!
          as Map)[r'$value'] = {
        'colorSpace': 'srgb',
        'components': [0.0627, 0.1843, 0.4392],
        'hex': '#102F70',
      };
      final theme = solved(
        solveTheme(
          redeclared(json),
          const ThemeRequest(button: ButtonShape.rounded),
        ),
      );
      expect(
        [for (final op in theme.patch) op.path],
        [
          r'/shape/button/$extensions/dev.fliin.buttonShape/value',
          r'/shape/button/$extensions/dev.fliin.buttonShape/value',
        ],
      );
    });
  });

  test('devrait faire échouer le patch rejoué sur un fichier dont un fond lu par le calcul a changé (n°5)', () {
    final json = registryJson();
    final patch = solved(
      solveTheme(json, ThemeRequest(primary: hex('#0A6CFF'))),
    ).patch;
    final retouched = registryJson();
    (((retouched['color']! as Map)['neutral']! as Map)['36']!
        as Map)[r'$value'] = {
      'colorSpace': 'srgb',
      'components': [0.8824, 0.8941, 0.9137],
      'hex': '#E1E4E9',
    };
    expect(
      () => applyJsonPatch(retouched, patch),
      throwsA(
        isA<JsonPatchError>().having(
          (e) => e.path,
          'path',
          r'/color/neutral/36/$value',
        ),
      ),
    );
    final pairs = registryJson();
    (((pairs['color']! as Map)[r'$extensions']!
                as Map)[FliinTokens.contrastExtension]!
            as List)
        .removeLast();
    expect(() => applyJsonPatch(pairs, patch), throwsA(isA<JsonPatchError>()));
  });

  test('devrait revenir à la police système quand la police demandée est SystemFont (n°11)', () {
    final named = applyJsonPatch(
      registryJson(),
      solved(
        solveTheme(
          registryJson(),
          const ThemeRequest(font: NamedFont('Inter')),
        ),
      ).patch,
    );
    final back = applyJsonPatch(
      named,
      solved(solveTheme(named, const ThemeRequest(font: SystemFont()))).patch,
    );
    expect(readTokens(back).fontFamily, {'ios': null, 'android': null});
    expect(jsonEncode(back), jsonEncode(registryJson()));
  });

  group('JSON Patch', () {
    test('devrait remplacer sur place sans toucher à l’original ni à l’ordre des clés', () {
      final original = {
        'a': 1,
        'b': {'c': 2},
        'd': 3,
      };
      final patched = applyJsonPatch(original, const [
        (op: PatchOperation.test, path: '/b/c', value: 2),
        (op: PatchOperation.replace, path: '/b/c', value: 5),
      ]);
      expect(jsonEncode(patched), '{"a":1,"b":{"c":5},"d":3}');
      expect(original['b'], {'c': 2});
    });

    test('devrait échouer quand la valeur testée a changé', () {
      expect(
        () => applyJsonPatch(
          {'a': 1},
          const [(op: PatchOperation.test, path: '/a', value: 2)],
        ),
        throwsA(isA<JsonPatchError>()),
      );
    });

    test('devrait accepter un test quand le nombre lu vaut le nombre attendu sous une autre écriture (RFC 6902 §4.6)', () {
      final patched = applyJsonPatch(
        {
          'c': [1.0, 0.5],
          'r': {'v': 6.0},
        },
        const [
          (op: PatchOperation.test, path: '/c', value: [1, 0.5]),
          (op: PatchOperation.test, path: '/r', value: {'v': 6}),
          (op: PatchOperation.replace, path: '/r', value: 2),
        ],
      );
      expect(jsonEncode(patched), '{"c":[1.0,0.5],"r":2}');
    });

    test('devrait écrire un nombre entier sans « .0 » quand le JSON est rendu portable, comme JavaScript l’écrit', () {
      expect(
        jsonEncode(
          portableJson({
            'components': [1.0, 0.9647, 0.0],
            'radius': 6.0,
            'ratio': 4.51,
          }),
        ),
        '{"components":[1,0.9647,0],"radius":6,"ratio":4.51}',
      );
    });

    test('devrait échapper ~ et / dans un pointeur', () {
      expect(jsonPointer(['a/b', 'c~d']), '/a~1b/c~0d');
      expect(
        valueAt({
          'a/b': {'c~d': 1},
        }, '/a~1b/c~0d'),
        1,
      );
    });
  });

  test('devrait ne nommer aucune bibliothèque native, ni dans lib/ ni dans la fermeture de ses dépendances, pour compiler pour le web', () async {
    // dart2js accepte dart:io (des stubs qui lèvent à l'exécution) : la
    // compilation seule ne le prouve pas. Toute mention entre guillemets
    // compte, import conditionnel ou commenté compris.
    final native = RegExp(r"""['"]dart:(io|cli|ffi|isolate|mirrors)['"]""");
    final deps = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'deps',
      '--json',
    ]);
    expect(deps.exitCode, 0, reason: '${deps.stderr}');
    final graph = {
      for (final package
          in (jsonDecode(deps.stdout as String) as Map)['packages'] as List)
        (package as Map)['name'] as String: package,
    };
    final closure = <String>{};
    final pending = [
      ...(graph['fliin_schema']!['directDependencies'] as List).cast<String>(),
    ];
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (closure.add(name)) {
        pending.addAll((graph[name]!['dependencies'] as List).cast<String>());
      }
    }
    // pubspec.lock est ignoré par git : un clone neuf résout les dernières
    // versions, et un paquet peut quitter la fermeture (crypto 3.0.8 n'a plus
    // typed_data). Seul un paquet nouveau doit faire échouer.
    expect(
      closure,
      containsAll(graph['fliin_schema']!['directDependencies'] as List),
    );
    expect(
      {'crypto', 'pub_semver', 'collection', 'typed_data'}.containsAll(closure),
      isTrue,
      reason: 'paquet hors de la liste autorisée : $closure',
    );
    final config = File('../../.dart_tool/package_config.json');
    final libraries = [
      for (final package
          in (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List)
        if (closure.contains((package as Map)['name']) ||
            package['name'] == 'fliin_schema')
          Directory.fromUri(
            config.absolute.uri
                .resolve(
                  '${package['rootUri']}'.endsWith('/')
                      ? '${package['rootUri']}'
                      : '${package['rootUri']}/',
                )
                .resolve(package['packageUri'] as String),
          ),
    ];
    expect(libraries, hasLength(closure.length + 1));
    final offending = [
      for (final library in libraries)
        for (final file in library.listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              native.hasMatch(file.readAsStringSync()))
            file.path,
    ];
    expect(offending, isEmpty);
  });
}

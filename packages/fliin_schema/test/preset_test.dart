import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:test/test.dart';

import 'theme_test.dart' show readTokens, registryJson;

Matcher refusedWith(String text) => throwsA(
  isA<PresetError>().having((e) => e.message, 'message', contains(text)),
);

/// [patch] appliqué à [json], relu par le profil.
Object? applied(Object? json, ThemeOutcome outcome) {
  final solved = outcome as ThemeSolved;
  final result = applyJsonPatch(json, solved.patch);
  readTokens(result);
  return result;
}

/// Le contenu de [json] sous les chemins d'un préréglage.
String owned(Object? json) => jsonEncode([
  for (final segments in presetPathsIn(registryJson()))
    _orNull(json, jsonPointer(segments)),
]);

/// Un préréglage dont chaque champ, des deux versions, est tiré par [random].
Preset randomPreset(math.Random random) {
  T pick<T>(List<T> values) => values[random.nextInt(values.length)];
  final primary = pick(PresetPrimary.values);
  return Preset(
    base: pick(PresetBase.values),
    primary: primary,
    brand: primary == PresetPrimary.custom
        ? Rgb8(random.nextInt(1 << 24))
        : null,
    body: pick([null, ...PresetFamily.values]),
    heading: pick([null, ...PresetFamily.values]),
    radius: pick(PresetRadius.values),
    spacing: pick(PresetSpacing.values),
    shadow: pick(PresetShadow.values),
    button: pick(ButtonShape.values),
    icons: pick(PresetIcons.values),
    menu: pick(PresetMenu.values),
    cards: pick(PresetCards.values),
    border: pick(PresetBorder.values),
    text: pick(PresetTextSize.values),
    motion: pick(PresetMotion.values),
  );
}

Object? _orNull(Object? json, String pointer) {
  try {
    return valueAt(json, pointer);
  } on JsonPatchError {
    return null;
  }
}

void main() {
  group('codage', () {
    test('devrait coder le thème livré en c0000000000000 quand chaque champ est à son défaut', () {
      expect(const Preset().encode(), 'c0000000000000');
      expect(Preset.decode('c0000000000000'), const Preset());
      expect(const Preset().describe, {
        'base': 'sand',
        'primary': 'blue',
        'body': 'system',
        'heading': 'inherit',
        'radius': 'standard',
        'spacing': 'standard',
        'shadow': 'standard',
        'button': 'pill',
        'icons': 'fliin',
        'menu': 'standard',
        'cards': 'raised',
        'border': 'regular',
        'text': 'regular',
        'motion': 'regular',
      });
    });

    test('devrait redonner chaque valeur de chaque champ après un aller-retour quand les autres champs sont au défaut', () {
      final presets = [
        for (final base in PresetBase.values) Preset(base: base),
        for (final primary in PresetPrimary.values) Preset(primary: primary),
        for (final brand in ['#000000', '#0A6CFF', '#FFFFFF', '#7F00FF'])
          Preset(primary: PresetPrimary.custom, brand: Rgb8.parse(brand)),
        for (final family in [null, ...PresetFamily.values]) ...[
          Preset(body: family),
          Preset(heading: family),
        ],
        for (final radius in PresetRadius.values) Preset(radius: radius),
        for (final spacing in PresetSpacing.values) Preset(spacing: spacing),
        for (final shadow in PresetShadow.values) Preset(shadow: shadow),
        for (final button in ButtonShape.values) Preset(button: button),
        for (final icons in PresetIcons.values) Preset(icons: icons),
        for (final menu in PresetMenu.values) Preset(menu: menu),
        for (final cards in PresetCards.values) Preset(cards: cards),
        for (final border in PresetBorder.values) Preset(border: border),
        for (final text in PresetTextSize.values) Preset(text: text),
        for (final motion in PresetMotion.values) Preset(motion: motion),
      ];
      for (final preset in presets) {
        final code = preset.encode();
        expect(code, hasLength(presetLengths[code[0]]), reason: code);
        expect(Preset.decode(code).describe, preset.describe, reason: code);
        expect(Preset.decode(code), preset, reason: code);
      }
    });

    test('devrait écrire tout code en version c, sur quatorze caractères, quels que soient les champs qui quittent leur défaut', () {
      expect(presetLengths, {'c': 14});
      expect(
        const Preset(radius: PresetRadius.none).encode(),
        'c00Hb840000000',
      );
      expect(const Preset(menu: PresetMenu.tinted).encode(), 'c0000000000001');
      expect(
        Preset(
          primary: PresetPrimary.custom,
          brand: Rgb8.parse('#0A6CFF'),
        ).encode(),
        'c00004e00lLhrs',
      );
      expect(Preset.decode('c00004e0000000').primary, PresetPrimary.custom);
      expect(
        Preset(
          base: PresetBase.stone,
          primary: PresetPrimary.custom,
          brand: Rgb8.parse('#1F6F50'),
          body: PresetFamily.inter,
          heading: PresetFamily.lora,
          radius: PresetRadius.none,
          cards: PresetCards.outlined,
          border: PresetBorder.medium,
          text: PresetTextSize.large,
          motion: PresetMotion.fast,
          menu: PresetMenu.tinted,
        ).encode(),
        'c00Ku3f02IlTe9',
      );
      expect(
        const Preset(
          icons: PresetIcons.phosphor,
          motion: PresetMotion.slow,
        ).encode(),
        'c71zrn6000008G',
      );
    });

    test('devrait redonner un préréglage tiré au hasard après un aller-retour quand tous les champs bougent ensemble', () {
      final random = math.Random(16);
      for (var i = 0; i < 500; i++) {
        final preset = randomPreset(random);
        final code = preset.encode();
        expect(Preset.decode(code).describe, preset.describe, reason: code);
        expect(Preset.decode(code).encode(), code);
        expect(Preset.fromIndices(preset.indices), preset);
      }
    });

    test('devrait garder les codes déjà émis quand la liste des valeurs ne change pas (version c)', () {
      final preset = Preset(
        base: PresetBase.stone,
        primary: PresetPrimary.pink,
        body: PresetFamily.inter,
        heading: PresetFamily.lora,
        radius: PresetRadius.none,
        spacing: PresetSpacing.compact,
        shadow: PresetShadow.none,
        button: ButtonShape.rounded,
      );
      expect(preset.encode(), 'c0m1Vr90000000');
    });

    test(
      'devrait décoder au jeu de Fliin un code dont le champ icons vaut 0',
      () {
        expect(Preset.decode('c0m1Vr90000000').icons, PresetIcons.fliin);
        expect(Preset.decode('c0000000000000').icons, PresetIcons.fliin);
      },
    );

    test('devrait placer chaque jeu d’icônes ajouté en fin de liste à son indice, sans changer la version', () {
      expect(
        [for (final icons in PresetIcons.values) icons.name],
        ['fliin', 'lucide', 'tabler', 'phosphor'],
      );
      expect(
        [for (final icons in PresetIcons.values) Preset(icons: icons).encode()],
        [
          'c0000000000000',
          'c2LKcb20000000',
          'c4gfFC40000000',
          'c71zrn60000000',
        ],
      );
      expect(Preset.decode('c2LKcb20000000').describe['icons'], 'lucide');
    });

    test('devrait donner la variante de fichier de chaque jeu, et aucune pour le jeu par défaut', () {
      expect(PresetIcons.fliin.variant, isNull);
      expect(
        [for (final icons in PresetIcons.values.skip(1)) icons.variant],
        ['lucide', 'tabler', 'phosphor'],
      );
    });
    test('devrait redonner le préréglage depuis ses indices quand on les lit dans Preset.indices', () {
      final preset = Preset(
        base: PresetBase.olive,
        primary: PresetPrimary.teal,
        body: PresetFamily.geist,
        heading: PresetFamily.ebGaramond,
        radius: PresetRadius.small,
        spacing: PresetSpacing.relaxed,
        shadow: PresetShadow.none,
        button: ButtonShape.square,
        icons: PresetIcons.tabler,
      );
      expect(Preset.fromIndices(preset.indices), preset);
      expect(Preset.fromIndices(const {}), const Preset());
      expect(Preset.fromIndices(const {'radius': 1}).radius, PresetRadius.none);
    });
  });

  group('refus', () {
    test('devrait dire de mettre fliin à jour pour un code d’une autre version, quelle que soit sa longueur (B1)', () {
      expect(() => Preset.decode('d0000000'), refusedWith('Update fliin'));
      expect(() => Preset.decode('d00'), refusedWith('Update fliin'));
    });

    test('devrait refuser un code des versions a et b en disant qu’il décrit le thème d’avant core 0.2.0 (ADR 0019)', () {
      for (final code in ['a000000', 'a0m1VrO', 'a00', 'b000000', 'b0000000000001', 'b00']) {
        expect(() => Preset.decode(code), refusedWith('the theme from before core 0.2.0'));
      }
    });

    test('devrait décoder pareil un code émis quand azure s’appelait heroui : le code porte le rang, pas le nom', () {
      // Émis avant que la couleur prenne le nom d'azure.
      for (final (code, base) in [('c00004O0000000', 0), ('c00004P0000000', 1)]) {
        final preset = Preset.decode(code);
        expect(preset.primary, PresetPrimary.azure);
        expect(preset.base, PresetBase.values[base]);
        expect(preset.encode(), code);
        expect(preset.describe['primary'], 'azure');
      }
    });

    test('devrait refuser un code d’une autre longueur en disant combien de caractères il faut à sa version', () {
      expect(
        () => Preset.decode('c00'),
        refusedWith('version c preset has 14 characters'),
      );
      expect(() => Preset.decode('d000000'), refusedWith('Update fliin'));
      expect(() => Preset.decode(''), refusedWith('empty preset'));
    });

    test('devrait refuser un premier caractère qui n’est pas une lettre de version sans pousser à mettre fliin à jour', () {
      for (final code in [
        '--preset a000000',
        '-a000000',
        'A000000',
        '0000000',
      ]) {
        expect(
          () => Preset.decode(code),
          throwsA(
            isA<PresetError>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('is not a version'),
                )
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('Update fliin')),
                ),
          ),
          reason: code,
        );
      }
    });

    test('devrait refuser un caractère hors base62 en donnant sa position', () {
      expect(() => Preset.decode('c00-0000000000'), refusedWith('position 4'));
    });

    test('devrait refuser une valeur hors de la liste d’un champ au lieu de retomber sur le défaut', () {
      // base sur 4 bits : 15 n'est pas un ton.
      expect(
        () => Preset.decode('c00000F0000000'),
        refusedWith('base: unknown value 15'),
      );
      // icons : quatre jeux connus, l'indice 4 viendra d'un fliin plus récent.
      expect(
        () => Preset.decode('c9NKUO80000000'),
        refusedWith('icons: unknown value 4'),
      );
    });

    test('devrait refuser une couleur de marque sans la primaire custom', () {
      expect(
        () => Preset.fromIndices(const {'brand': 0x0A6CFF}),
        refusedWith('brand: a brand color only goes with the custom primary'),
      );
      // brand = 1 au-dessus des 10 bits des réglages, primaire blue.
      expect(() => Preset.decode('c0000000000G00'), refusedWith('brand'));
    });

    test('devrait refuser une valeur hors de la liste d’un réglage du second bloc, et des bits au-delà de son dernier champ', () {
      // menu sur 2 bits : 3 n'est pas un fond de menu.
      expect(
        () => Preset.decode('c0000000000003'),
        refusedWith('menu: unknown value 3 in version c'),
      );
      expect(
        () => Preset.decode('c000000zzzzzzz'),
        throwsA(isA<PresetError>()),
      );
      // 2^34 : un bit au-delà de brand, le dernier champ.
      expect(
        () => Preset.decode('c000000${_base62Of(1 << 34, 7)}'),
        refusedWith('beyond the last field of version c'),
      );
    });

    test('devrait refuser un indice hors de la liste ou un champ inconnu quand on construit depuis des indices', () {
      expect(
        () => Preset.fromIndices(const {'primary': 19}),
        refusedWith('primary: unknown value 19'),
      );
      expect(
        () => Preset.fromIndices(const {'icons': -1}),
        refusedWith('icons: unknown value -1'),
      );
      expect(
        () => Preset.fromIndices(const {'font': 1}),
        refusedWith('unknown field font'),
      );
    });

    test('devrait refuser des bits au-delà du dernier champ', () {
      expect(
        () => Preset.decode('czzzzzz0000000'),
        throwsA(isA<PresetError>()),
      );
      expect(
        () => Preset.decode('cbVJxYW0000000'),
        refusedWith('beyond the last field'),
      );
    });
  });

  group('application', () {
    final registry = registryJson();

    test('devrait poser les cartes à plat, tracées de l’épaisseur choisie et sans ombre de surface, quand cards vaut outlined', () {
      final result = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(
            cards: PresetCards.outlined,
            border: PresetBorder.medium,
          ),
        ),
      );
      expect(valueAt(result, '/size/border/\$value/value'), 1.5);
      expect(valueAt(result, '/size/surfaceBorder/\$value/value'), 1.5);
      final tokens = readTokens(result);
      final defaults = readTokens(registry);
      for (final appearance in ['light', 'dark']) {
        expect(
          tokens.shadows[appearance]!['surface']!.every(
            (l) => l.color >> 24 == 0,
          ),
          isTrue,
        );
        expect(
          '${tokens.shadows[appearance]!['overlay']}',
          '${defaults.shadows[appearance]!['overlay']}',
        );
      }
      expect(tokens.light, defaults.light);
      final raised = applied(
        result,
        applyPreset(result, registry, const Preset(border: PresetBorder.bold)),
      );
      expect(valueAt(raised, '/size/border/\$value/value'), 2);
      expect(valueAt(raised, '/size/surfaceBorder/\$value/value'), 0);
    });

    test('devrait refuser les cartes à plat sur les jetons d’un core d’avant size.surfaceBorder, en disant lequel installer', () {
      final before = jsonDecode(jsonEncode(registry)) as Map<String, Object?>;
      (before['size']! as Map<String, Object?>).remove('surfaceBorder');
      expect(
        () => applyPreset(
          before,
          before,
          const Preset(cards: PresetCards.outlined),
        ),
        refusedWith('core 0.1.3 or later is required'),
      );
      expect(
        applyPreset(before, before, const Preset(border: PresetBorder.bold)),
        isA<ThemeSolved>(),
      );
    });

    test('devrait multiplier chaque taille et hauteur de ligne de l’échelle typographique, arrondies au pixel, quand text change', () {
      final defaults = registry;
      for (final text in [PresetTextSize.small, PresetTextSize.large]) {
        final result = applied(
          registry,
          applyPreset(registry, registry, Preset(text: text)),
        );
        for (final platform in ['ios', 'android']) {
          final scale =
              valueAt(defaults, '/typography/scale/$platform')!
                  as Map<String, Object?>;
          for (final role in scale.keys.where((k) => !k.startsWith(r'$'))) {
            for (final property in ['size', 'lineHeight']) {
              final pointer =
                  '/typography/scale/$platform/$role/$property/\$value/value';
              expect(
                valueAt(result, pointer),
                ((valueAt(defaults, pointer)! as num) * text.scale)
                    .roundToDouble(),
                reason: '$text $pointer',
              );
            }
          }
        }
      }
    });

    test('devrait changer le tempo de chaque durée et la raideur de chaque ressort, sans toucher amortissement ni masse, quand motion change', () {
      final result = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(motion: PresetMotion.fast),
        ),
      );
      final durations =
          valueAt(registry, '/motion/duration')! as Map<String, Object?>;
      for (final name in durations.keys.where((k) => !k.startsWith(r'$'))) {
        final pointer = '/motion/duration/$name/\$value/value';
        expect(
          valueAt(result, pointer),
          ((valueAt(registry, pointer)! as num) * 0.7).round(),
          reason: name,
        );
      }
      final springs =
          valueAt(registry, '/motion/spring')! as Map<String, Object?>;
      for (final name in springs.keys.where((k) => !k.startsWith(r'$'))) {
        final stiffness =
            valueAt(registry, '/motion/spring/$name/stiffness/\$value')! as num;
        expect(
          valueAt(result, '/motion/spring/$name/stiffness/\$value'),
          closeTo(stiffness / 0.49, 0.05),
          reason: name,
        );
        for (final kept in ['dampingRatio', 'mass']) {
          expect(
            valueAt(result, '/motion/spring/$name/$kept/\$value'),
            valueAt(registry, '/motion/spring/$name/$kept/\$value'),
          );
        }
      }
      final back = applied(
        result,
        applyPreset(result, registry, const Preset()),
      );
      expect(jsonEncode(back), jsonEncode(registry));
    });

    test('devrait teinter le fond des menus de la primaire, en clair et en sombre, sans exception de contraste, quand menu vaut tinted', () {
      final result = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(primary: PresetPrimary.violet, menu: PresetMenu.tinted),
        ),
      );
      final tokens = readTokens(result);
      final flat = readTokens(
        applied(
          registry,
          applyPreset(
            registry,
            registry,
            const Preset(primary: PresetPrimary.violet),
          ),
        ),
      );
      for (final (tinted, neutral) in [
        (tokens.light, flat.light),
        (tokens.dark, flat.dark),
      ]) {
        expect(tinted['surfaceOverlay'], isNot(neutral['surfaceOverlay']));
        final hue = toOklch(Rgb8(tinted['surfaceOverlay']!)).h;
        expect((hue - toOklch(Rgb8.parse('#7C3AED')).h).abs(), lessThan(15));
        expect(tinted['surfaceRaised'], neutral['surfaceRaised']);
      }
      expect(tokens.contrastExceptions, isEmpty);
    });

    for (final brand in ['#000000', '#FFFFFF', '#808080', '#7F7F80']) {
      test(
        'devrait prendre la teinte de la base, et non une teinte arbitraire, quand la marque $brand est achromatique et menu vaut tinted',
        () {
          Map<String, int> overlay(PresetBase base) {
            final tokens = readTokens(
              applied(
                registry,
                applyPreset(
                  registry,
                  registry,
                  Preset(
                    base: base,
                    primary: PresetPrimary.custom,
                    brand: Rgb8.parse(brand),
                    menu: PresetMenu.tinted,
                  ),
                ),
              ),
            );
            return {
              'light': tokens.light['surfaceOverlay']!,
              'dark': tokens.dark['surfaceOverlay']!,
            };
          }

          for (final color in overlay(PresetBase.neutral).values) {
            expect(toOklch(Rgb8(color)).c, lessThan(0.005), reason: brand);
          }
          for (final color in overlay(PresetBase.slate).values) {
            final lch = toOklch(Rgb8(color));
            expect(
              (lch.h - NeutralTone.slate.hue!).abs(),
              lessThan(15),
              reason: '$brand ${Rgb8(color).hex}',
            );
          }
        },
      );
    }

    test('devrait résoudre la couleur de marque custom, à la teinte demandée, quand primary vaut custom', () {
      final brand = Rgb8.parse('#1F6F50');
      final tokens = readTokens(
        applied(
          registry,
          applyPreset(
            registry,
            registry,
            Preset(primary: PresetPrimary.custom, brand: brand),
          ),
        ),
      );
      expect(
        (toOklch(Rgb8(tokens.light['accent']!)).h - toOklch(brand).h).abs(),
        lessThan(3),
      );
      expect(tokens.contrastExceptions, isEmpty);
    });

    test('devrait laisser le fichier du registre intact, sans exception, quand le préréglage est le défaut', () {
      final outcome = applyPreset(registry, registry, const Preset());
      expect((outcome as ThemeSolved).patch, isEmpty);
      expect(outcome.contrast.every((c) => c.ok && !c.excused), isTrue);
    });

    test('devrait redonner le thème livré quand on revient au défaut après un autre préréglage', () {
      final pink = applied(
        registry,
        applyPreset(registry, registry, Preset.decode('c0m1Vr90000000')),
      );
      expect(owned(pink), isNot(owned(registry)));
      final back = applied(pink, applyPreset(pink, registry, const Preset()));
      expect(owned(back), owned(registry));
      expect(jsonEncode(back), jsonEncode(registry));
    });

    test('devrait donner les mêmes jetons quel que soit le thème de départ quand le code est le même', () {
      final code = Preset.decode('c0m1Vr90000000');
      final violet = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(
            primary: PresetPrimary.violet,
            radius: PresetRadius.large,
          ),
        ),
      );
      final fromRegistry = applied(
        registry,
        applyPreset(registry, registry, code),
      );
      final fromViolet = applied(violet, applyPreset(violet, registry, code));
      expect(jsonEncode(fromViolet), jsonEncode(fromRegistry));
    });

    test('devrait ne plus rien changer quand le même préréglage est appliqué une seconde fois', () {
      final preset = Preset.decode('c0m1Vr90000000');
      final once = applied(registry, applyPreset(registry, registry, preset));
      final again = applyPreset(once, registry, preset) as ThemeSolved;
      expect(again.patch, isEmpty);
    });

    test('devrait garder une retouche hors des chemins du préréglage et reprendre celles qui sont dessous', () {
      final edited = jsonDecode(jsonEncode(registry)) as Map<String, Object?>;
      final size = edited['size']! as Map<String, Object?>;
      (size['focusRing']! as Map<String, Object?>)[r'$value'] = {
        'value': 3,
        'unit': 'px',
      };
      final space = edited['space']! as Map<String, Object?>;
      (space['xs']! as Map<String, Object?>)[r'$value'] = {
        'value': 7,
        'unit': 'px',
      };
      final result = applied(
        edited,
        applyPreset(edited, registry, const Preset()),
      );
      expect(valueAt(result, '/size/focusRing/\$value/value'), 3);
      expect(valueAt(result, '/space/xs/\$value/value'), 4);
    });

    test('devrait garder la graisse retouchée d\'un rôle de texte et reprendre sa taille quand un code c0000000000000 est appliqué', () {
      final edited = jsonDecode(jsonEncode(registry)) as Map<String, Object?>;
      final body =
          ((edited['typography']! as Map<String, Object?>)['scale']!
                  as Map<String, Object?>)['ios']!
              as Map<String, Object?>;
      final role = body['body']! as Map<String, Object?>;
      (role['weight']! as Map<String, Object?>)[r'$value'] = 600;
      (role['size']! as Map<String, Object?>)[r'$value'] = {
        'value': 30,
        'unit': 'px',
      };
      final result = applied(
        edited,
        applyPreset(edited, registry, Preset.decode('c0000000000000')),
      );
      expect(valueAt(result, '/typography/scale/ios/body/weight/\$value'), 600);
      expect(
        valueAt(result, '/typography/scale/ios/body/size/\$value/value'),
        16,
      );
    });

    test('devrait régler les onze rayons, les six espacements et les ombres quand le préréglage les change', () {
      final result = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(
            radius: PresetRadius.large,
            spacing: PresetSpacing.relaxed,
            shadow: PresetShadow.none,
          ),
        ),
      );
      final tokens = readTokens(result);
      final defaults = readTokens(registry);
      for (final MapEntry(:key, :value) in defaults.radius.entries) {
        // Le bouton rounded du registre est déjà une capsule : plafonné (B8).
        final expected = ['button', 'buttonLarge'].contains(key)
            ? value
            : (value * 1.5).roundToDouble();
        expect(tokens.radius[key], expected, reason: key);
      }
      for (final MapEntry(:key, :value) in defaults.space.entries) {
        expect(tokens.space[key], (value * 1.25).roundToDouble(), reason: key);
      }
      for (final appearance in tokens.shadows.values) {
        for (final layers in appearance.values) {
          expect(layers.every((l) => l.color >> 24 == 0), isTrue);
        }
      }
      expect(tokens.light, defaults.light);
      expect('${tokens.contrastExceptions}', '${defaults.contrastExceptions}');
    });

    test('devrait nommer la police des titres à part de celle du texte', () {
      final tokens = readTokens(
        applied(
          registry,
          applyPreset(
            registry,
            registry,
            const Preset(body: PresetFamily.inter, heading: PresetFamily.lora),
          ),
        ),
      );
      expect(tokens.fontFamily, {'ios': 'Inter', 'android': 'Inter'});
      expect(tokens.headingFamily, {'ios': 'Lora', 'android': 'Lora'});
    });

    test('devrait rendre aux titres la police du texte quand le thème demande InheritedFont', () {
      final lora = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(heading: PresetFamily.lora),
        ),
      );
      final back = applied(
        lora,
        solveTheme(lora, const ThemeRequest(headingFont: InheritedFont())),
      );
      expect(readTokens(back).headingFamily, {'ios': null, 'android': null});
      expect(jsonEncode(back), jsonEncode(registry));
    });

    test(
      'devrait ajouter la police des titres à un fichier installé avant elle',
      () {
        final old = jsonDecode(jsonEncode(registry)) as Map<String, Object?>;
        (old['typography']! as Map<String, Object?>).remove('headingFamily');
        expect(readTokens(old).headingFamily, {'ios': null, 'android': null});
        final outcome = applyPreset(
          old,
          registry,
          const Preset(heading: PresetFamily.playfairDisplay),
        ) as ThemeSolved;
        expect(
          outcome.patch.map((op) => (op.op, op.path)),
          contains((PatchOperation.add, '/typography/headingFamily')),
        );
        expect(
          readTokens(applyJsonPatch(old, outcome.patch)).headingFamily['ios'],
          'Playfair Display',
        );
      },
    );

    test('devrait résoudre en AA strict, sans exception, dès qu’une couleur quitte celles du registre', () {
      final tokens = readTokens(
        applied(
          registry,
          applyPreset(registry, registry, const Preset(base: PresetBase.slate)),
        ),
      );
      expect(tokens.contrastExceptions, isEmpty);
    });

    test('devrait laisser telles quelles les clés de rayon et d’espacement ajoutées par l’app, et rester stable au second passage (M1)', () {
      final edited = jsonDecode(jsonEncode(registry)) as Map<String, Object?>;
      final radius =
          (edited['shape']! as Map<String, Object?>)['radius']!
              as Map<String, Object?>;
      radius['avatar'] = {
        r'$value': {'value': 10, 'unit': 'px'},
      };
      (edited['space']! as Map<String, Object?>)['xxxl'] = {
        r'$value': {'value': 48, 'unit': 'px'},
      };
      const preset = Preset(
        radius: PresetRadius.large,
        spacing: PresetSpacing.relaxed,
      );
      final once = applied(edited, applyPreset(edited, registry, preset));
      expect(valueAt(once, '/shape/radius/avatar/\$value/value'), 10);
      expect(valueAt(once, '/space/xxxl/\$value/value'), 48);
      expect(
        (applyPreset(once, registry, preset) as ThemeSolved).patch,
        isEmpty,
      );
      final back = applied(once, applyPreset(once, registry, const Preset()));
      expect(jsonEncode(back), jsonEncode(edited));
    });

    test('devrait faire suivre à l’espacement les marges visibles en size, sans toucher hauteurs de contrôle ni cibles tactiles (M2)', () {
      final defaults = readTokens(registry);
      final compact = readTokens(
        applied(
          registry,
          applyPreset(
            registry,
            registry,
            const Preset(spacing: PresetSpacing.compact),
          ),
        ),
      );
      for (final name in [
        'surfacePadding',
        'buttonPaddingSm',
        'buttonPaddingMd',
        'buttonPaddingLg',
        'buttonGapSm',
        'buttonGapMd',
        'buttonGapLg',
        'fieldInset',
        'codePaddingX',
        'codePaddingY',
      ]) {
        expect(
          compact.size[name],
          (defaults.size[name]! * 0.75).roundToDouble(),
          reason: name,
        );
      }
      expect(compact.size['surfacePadding'], 12);
      for (final name in [
        'controlCompact',
        'controlComfortable',
        'hitTargetIos',
        'listPaddingComfortable',
      ]) {
        expect(compact.size[name], defaults.size[name], reason: name);
      }
    });

    test('devrait écrire des entiers quand l’échelle tombe juste (B2)', () {
      final relaxed = applied(
        registry,
        applyPreset(
          registry,
          registry,
          const Preset(spacing: PresetSpacing.relaxed),
        ),
      );
      expect(
        jsonEncode(valueAt(relaxed, '/space/md')),
        contains('"value":15,'),
      );
    });

    test('devrait refuser une police de titres quand les jetons livrés sont ceux de core 0.1.1, en disant de mettre core à jour (M6)', () {
      final old = jsonDecode(
        File('test/fixtures/core-0.1.1.tokens.json').readAsStringSync(),
      );
      expect(valueAt(old, '/typography/family'), isNotNull);
      expect(
        () => valueAt(old, '/typography/headingFamily'),
        throwsA(isA<JsonPatchError>()),
      );
      expect(
        () => applyPreset(old, old, const Preset(heading: PresetFamily.lora)),
        throwsA(
          isA<PresetError>().having(
            (e) => e.message,
            'message',
            contains('fliin update core'),
          ),
        ),
      );
      expect(
        applyPreset(old, old, const Preset(body: PresetFamily.inter)),
        isA<ThemeSolved>(),
      );
    });
  });
}

String _base62Of(int value, int digits) {
  const alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  final out = List.filled(digits, '0');
  for (var i = digits - 1; i >= 0; i--) {
    out[i] = alphabet[value % 62];
    value ~/= 62;
  }
  return out.join();
}

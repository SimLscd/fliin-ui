import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

const registryFile = '../../flutter/registry/lib/core/tokens/fliin.tokens.json';

Map<String, Object?> srgb(List<num> rgb, {String? hex}) => {
  'colorSpace': 'srgb',
  'components': rgb,
  'hex': ?hex,
};

ResolvedTokens resolve(Map<String, Object?> json) =>
    resolveTokens(TokenDocument.fromJson(json));

Matcher throwsToken<T extends TokenError>(String path) =>
    throwsA(isA<T>().having((e) => e.path, 'path', path));

void main() {
  group('types (Format §5.2.2)', () {
    test('devrait hériter le \$type du groupe le plus proche quand le jeton n’en a pas', () {
      final tokens = resolve({
        'color': {
          r'$type': 'color',
          'brand': {
            r'$type': 'dimension',
            'gap': {
              r'$value': {'value': 4, 'unit': 'px'},
            },
          },
          'primary': {
            r'$value': srgb([1, 0, 0]),
          },
        },
      });
      expect(tokens['color.primary']!.type, TokenType.color);
      expect(tokens['color.brand.gap']!.type, TokenType.dimension);
    });

    test('devrait prendre le type de la cible quand un alias n’a ni \$type ni groupe typé', () {
      final tokens = resolve({
        'base': {
          r'$type': 'color',
          'blue': {
            r'$value': srgb([0, 0, 1]),
          },
        },
        'semantic': {
          'link': {r'$value': '{base.blue}'},
        },
      });
      expect(tokens['semantic.link']!.type, TokenType.color);
      expect(
        (tokens['semantic.link']!.value as ColorValue).components,
        hasLength(3),
      );
    });

    test('devrait refuser un jeton sans type déterminable avec son chemin', () {
      expect(
        () => resolve({
          'a': {
            'b': {r'$value': 4},
          },
        }),
        throwsToken<UndeterminedTokenType>('a.b'),
      );
    });

    test('devrait refuser un \$type hors des 13 types', () {
      expect(
        () => resolve({
          'x': {r'$type': 'string', r'$value': 'a'},
        }),
        throwsToken<UnknownTokenType>('x'),
      );
    });

    test('devrait prendre le \$type du groupe avant celui de la cible d’alias quand ils divergent', () {
      expect(
        () => resolve({
          'p': {
            r'$type': 'number',
            'one': {r'$value': 1},
          },
          'd': {
            r'$type': 'dimension',
            'x': {r'$value': '{p.one}'},
          },
        }),
        throwsToken<ReferenceTypeMismatch>('d.x'),
      );
    });

    test('devrait refuser un alias vers un jeton d’un autre type', () {
      expect(
        () => resolve({
          'gap': {
            r'$type': 'dimension',
            r'$value': {'value': 4, 'unit': 'px'},
          },
          'tint': {r'$type': 'color', r'$value': '{gap}'},
        }),
        throwsToken<ReferenceTypeMismatch>('tint'),
      );
    });
  });

  group('références (Format §7)', () {
    test('devrait suivre une chaîne d’alias {a.b} jusqu’à la valeur', () {
      final tokens = resolve({
        'a': {
          r'$type': 'number',
          'x': {r'$value': 7},
        },
        'b': {r'$value': '{a.x}'},
        'c': {r'$value': '{b}'},
      });
      expect((tokens['c']!.value as NumberValue).value, 7);
    });

    test(
      'devrait lire une sous-valeur par pointeur JSON \$ref (Format §7.1.2)',
      () {
        final tokens = resolve({
          'palette': {
            r'$type': 'color',
            'red': {
              r'$value': srgb([1, 0.5, 0]),
            },
          },
          'green': {
            r'$type': 'number',
            r'$ref': r'#/palette/red/$value/components/1',
          },
          'mixed': {
            r'$type': 'color',
            r'$value': {
              'colorSpace': 'srgb',
              'components': [
                {r'$ref': r'#/palette/red/$value/components/0'},
                0,
                1,
              ],
            },
          },
        });
        expect((tokens['green']!.value as NumberValue).value, 0.5);
        expect(
          ((tokens['mixed']!.value as ColorValue).components[0]
                  as NumericComponent)
              .value,
          1,
        );
      },
    );

    test('devrait signaler un cycle avec le chemin complet des maillons', () {
      expect(
        () => resolve({
          'a': {r'$type': 'number', r'$value': '{b}'},
          'b': {r'$type': 'number', r'$value': '{c}'},
          'c': {r'$type': 'number', r'$value': '{a}'},
        }),
        throwsA(
          isA<ReferenceCycle>().having((e) => e.chain, 'chain', [
            'a',
            'b',
            'c',
            'a',
          ]),
        ),
      );
    });

    test('devrait signaler un cycle qui passe par des \$ref', () {
      expect(
        () => resolve({
          'a': {
            r'$type': 'number',
            r'$value': {r'$ref': r'#/b/$value'},
          },
          'b': {
            r'$type': 'number',
            r'$value': {r'$ref': r'#/a/$value'},
          },
        }),
        throwsToken<ReferenceCycle>('a'),
      );
    });

    test(
      'devrait signaler un cycle quand deux groupes s’étendent l’un l’autre',
      () {
        expect(
          () => resolve({
            'a': {r'$extends': '{b}'},
            'b': {r'$extends': '{a}', r'$type': 'number'},
          }),
          throwsToken<ReferenceCycle>('a'),
        );
      },
    );

    test('devrait signaler un cycle quand un groupe étend son ancêtre (Format §6.4.4, ex. 16)', () {
      expect(
        () => resolve({
          'a': {
            r'$type': 'number',
            't': {r'$value': 1},
            'b': {r'$extends': '{a}'},
          },
        }),
        throwsToken<ReferenceCycle>('a.b'),
      );
    });

    test('devrait signaler un cycle quand un groupe étend son ancêtre par un intermédiaire', () {
      expect(
        () => resolve({
          'a': {
            r'$type': 'number',
            't': {r'$value': 1},
            'b': {r'$extends': '{c}'},
          },
          'c': {r'$extends': '{a}'},
        }),
        throwsA(isA<ReferenceCycle>()),
      );
    });

    test('devrait suivre {g.\$root} jusqu’au jeton \$root du groupe (Format §6.7.2)', () {
      final tokens = resolve({
        'g': {
          r'$type': 'number',
          r'$root': {r'$value': 3},
          'x': {r'$value': 4},
        },
        'alias': {r'$value': r'{g.$root}'},
      });
      expect(tokens['alias']!.type, TokenType.number);
      expect((tokens['alias']!.value as NumberValue).value, 3);
    });

    test('devrait refuser un alias {g} vers un groupe même quand il a un \$root (Format §6.7.2, ex. 10)', () {
      expect(
        () => resolve({
          'g': {
            r'$type': 'number',
            r'$root': {r'$value': 3},
          },
          'alias': {r'$value': '{g}'},
        }),
        throwsA(
          isA<UnresolvedReference>()
              .having((e) => e.path, 'path', 'alias')
              .having((e) => e.text, 'text', '{g}'),
        ),
      );
    });

    test('devrait signaler un cycle quand un \$ref désigne le \$value de son propre jeton', () {
      expect(
        () => resolve({
          'a': {r'$type': 'number', r'$ref': r'#/a/$value'},
        }),
        throwsToken<ReferenceCycle>('a'),
      );
    });

    test('devrait suivre un pointeur dont un segment contient une espace non encodée (Format §7.4.6)', () {
      final tokens = resolve({
        'colors': {
          r'$type': 'number',
          'my red': {r'$value': 1},
        },
        'y': {r'$type': 'number', r'$ref': r'#/colors/my red/$value'},
      });
      expect((tokens['y']!.value as NumberValue).value, 1);
    });

    test('devrait refuser un pointeur vers un jeton hérité par \$extends, qu’un alias suit', () {
      final base = {
        'a': {
          r'$type': 'number',
          't': {r'$value': 1},
        },
        'b': {r'$extends': '{a}'},
      };
      expect(
        (resolve({
                  ...base,
                  'y': {r'$value': '{b.t}'},
                })['y']!.value
                as NumberValue)
            .value,
        1,
      );
      expect(
        () => resolve({
          ...base,
          'y': {r'$type': 'number', r'$ref': r'#/b/t/$value'},
        }),
        throwsA(
          isA<UnresolvedReference>()
              .having((e) => e.path, 'path', 'y')
              .having((e) => e.reason, 'reason', contains(r'$extends')),
        ),
      );
    });

    test('devrait situer l’erreur sur le jeton imbriqué qui la porte', () {
      expect(
        () => resolve({
          'color': {
            r'$type': 'color',
            'light': {
              'surface': {r'$value': '{color.neutral.0}'},
            },
          },
        }),
        throwsA(
          isA<UnresolvedReference>()
              .having((e) => e.path, 'path', 'color.light.surface')
              .having((e) => e.text, 'text', '{color.neutral.0}'),
        ),
      );
    });

    test('devrait hériter les jetons d’un groupe \$extends et laisser le local gagner', () {
      final tokens = resolve({
        'base': {
          r'$type': 'number',
          'a': {r'$value': 1},
          'b': {r'$value': 2},
        },
        'derived': {
          r'$extends': '{base}',
          'b': {r'$value': 3},
        },
      });
      expect((tokens['derived.a']!.value as NumberValue).value, 1);
      expect((tokens['derived.b']!.value as NumberValue).value, 3);
    });
  });

  group('valeurs', () {
    test(
      'devrait convertir une couleur sRGB en ARGB quand son hex concorde',
      () {
        final tokens = resolve({
          'c': {
            r'$type': 'color',
            r'$value': srgb([0.9647, 0.9686, 0.9765], hex: '#F6F7F9'),
          },
        });
        expect((tokens['c']!.value as ColorValue).argb('c'), 0xFFF6F7F9);
      },
    );

    test('devrait refuser à la résolution un hex qui contredit les composantes, sur le jeton qui le porte', () {
      expect(
        () => resolve({
          'role': {r'$type': 'color', r'$value': '{palette.bad}'},
          'palette': {
            r'$type': 'color',
            'bad': {
              r'$value': srgb([1, 0, 0], hex: '#00ff00'),
            },
          },
        }),
        throwsToken<InvalidTokenValue>('palette.bad'),
      );
    });

    test('devrait refuser de convertir un espace autre que sRGB en Color', () {
      final tokens = resolve({
        'c': {
          r'$type': 'color',
          r'$value': {
            'colorSpace': 'oklch',
            'components': [0.7, 0.1, 200],
          },
        },
      });
      expect(
        () => (tokens['c']!.value as ColorValue).argb('c'),
        throwsA(
          isA<UnsupportedColorSpace>().having(
            (e) => e.colorSpace,
            'colorSpace',
            'oklch',
          ),
        ),
      );
    });

    test('devrait lire px et rem, ms et s, et refuser toute autre unité', () {
      final tokens = resolve({
        'd': {
          r'$type': 'dimension',
          r'$value': {'value': 1.5, 'unit': 'rem'},
        },
        't': {
          r'$type': 'duration',
          r'$value': {'value': 0.25, 'unit': 's'},
        },
      });
      expect(
        tokens['d']!.value,
        isA<DimensionValue>().having((d) => d.unit, 'unit', DimensionUnit.rem),
      );
      expect((tokens['t']!.value as DurationValue).milliseconds, 250);
      expect(
        () => resolve({
          'd': {
            r'$type': 'dimension',
            r'$value': {'value': 1, 'unit': 'pt'},
          },
        }),
        throwsToken<InvalidTokenValue>('d'),
      );
    });
  });

  group('sérialisation', () {
    test('devrait rendre les clés dans l’ordre lu quand le fichier ne suit pas l’ordre canonique', () {
      const text =
          '{"g":{"t":{"\$value":1,"\$type":"number"},"\$description":"d",'
          '"\$root":{"\$value":2,"\$type":"number"}}}';
      expect(
        jsonEncode(TokenDocument.fromJson(jsonDecode(text)).toJson()),
        text,
      );
    });

    test('devrait conserver les \$extensions inconnues, descriptions et dépréciations au retour', () {
      final json = {
        r'$schema': 'https://www.designtokens.org/schemas/2025.10/format.json',
        'g': {
          r'$type': 'number',
          r'$description': 'un groupe',
          r'$extensions': {
            'com.example.tool': {
              'nested': [1, 2],
            },
          },
          't': {
            r'$value': 1,
            r'$deprecated': 'utiliser g.u',
            r'$extensions': {'org.other': true},
          },
          'u': {r'$value': 2, r'$deprecated': false},
        },
      };
      final document = TokenDocument.fromJson(json);
      expect(document.toJson(), json);
      expect(TokenDocument.fromJson(document.toJson()).toJson(), json);
    });
  });

  group('profil Fliin', () {
    final file = File(registryFile);
    final document = TokenDocument.fromJson(
      jsonDecode(file.readAsStringSync()),
    );
    final tokens = resolveTokens(document);

    test(
      'devrait relire fliin.tokens.json octet pour octet après sérialisation',
      () {
        expect(
          '${const JsonEncoder.withIndent('  ').convert(document.toJson())}\n',
          file.readAsStringSync(),
        );
      },
    );

    test('devrait lire les rôles, paires, forme et ressorts du fichier du registre', () {
      final fliin = FliinTokens.read(tokens);
      expect(fliin.roles, containsAllInOrder(FliinTokens.colorRoles));
      expect(fliin.roles, containsAll(['switchThumb', 'switchTrack']));
      expect(fliin.roles, containsAll(['selected', 'onSelected', 'link']));
      expect(fliin.light['surface'], 0xFFFFFFFF);
      expect(fliin.dark['surface'], 0xFF0F0F0D);
      expect(fliin.light['selected'], 0xFF2563EB);
      expect(fliin.contrastPairs, hasLength(86));
      expect(fliin.contrastExceptions, isEmpty);
      expect(fliin.button, ButtonShape.pill);
      expect(fliin.springs['release']!.stiffness, 157.9);
      expect(fliin.durations['medium2']!.milliseconds, 300);
      expect(fliin.typography['ios']!['body']!.lineHeight, 24);
      expect(fliin.size['iconMaxScale'], 1.5);
      expect(fliin.size['scrimOpacity'], 1);
    });

    Map<String, Object?> registryJson() =>
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

    Map<String, Object?> at(Map<String, Object?> json, String path) => path
        .split('.')
        .fold(json, (node, key) => node[key]! as Map<String, Object?>);

    Object? copy(Object? json) => jsonDecode(jsonEncode(json));

    test(
      'devrait refuser une paire de contraste qui nomme un rôle translucide',
      () {
        final json = registryJson();
        (at(json, 'color.light.surfacePressed'))[r'$value'] = {
          ...srgb([0.5, 0.5, 0.5]),
          'alpha': 0.5,
        };
        expect(
          () => FliinTokens.read(resolve(json)),
          throwsToken<MissingFliinToken>('color.light.surfacePressed'),
        );
      },
    );

    List<Object?> exceptions(Map<String, Object?> json) =>
        (at(
              json,
              r'color.$extensions',
            ))[FliinTokens.contrastExceptionsExtension]!
            as List<Object?>;

    test('devrait refuser une exception dont le ratio déclaré n’est plus celui mesuré', () {
      final json = registryJson();
      // Le thème livré n'en a aucune (ADR 0019) : un texte secondaire pâli
      // à `fg-3` sur `surface-2` échoue, et se déclare à 0,01 près.
      at(json, 'color.light.onSurfaceMuted')[r'$value'] = '{color.neutral.475}';
      final measured = contrastRatio(
        Rgb8.parse('#6B6B63'),
        Rgb8.parse('#E9E8E2'),
      );
      exceptions(json).add({
        'foreground': 'onSurfaceMuted',
        'background': 'surfaceSecondary',
        'kind': 'text',
        'appearance': 'light',
        'ratio': floorRatio(measured) + 0.01,
        'reason': 'ratio mal recopié',
      });
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsA(
          isA<MissingFliinToken>()
              .having((e) => e.path, 'path', 'color')
              .having(
                (e) => '$e',
                'message',
                contains('Declare the exception again'),
              ),
        ),
      );
    });

    test('devrait refuser une exception sur une paire qui passe son seuil', () {
      final json = registryJson();
      exceptions(json).add({
        'foreground': 'onSurface',
        'background': 'surface',
        'kind': 'text',
        'appearance': 'light',
        'ratio': 15.0,
        'reason': 'paire conforme, déclarée à tort',
      });
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsA(
          isA<MissingFliinToken>()
              .having((e) => e.path, 'path', 'color')
              .having((e) => '$e', 'message', contains('Remove the exception')),
        ),
      );
    });

    test(
      'devrait accepter un rôle translucide quand aucune paire ne le nomme',
      () {
        final json = registryJson();
        at(json, 'color.light')['veil'] = {
          r'$value': {
            ...srgb([0, 0, 0]),
            'alpha': 0.2,
          },
        };
        at(json, 'color.dark')['veil'] = {
          r'$value': {
            ...srgb([0, 0, 0]),
            'alpha': 0.2,
          },
        };
        expect(FliinTokens.read(resolve(json)).light['veil']! >>> 24, 0x33);
      },
    );

    test('devrait lire l’approche d’un style typographique, nulle quand le jeton tracking manque', () {
      final fliin = FliinTokens.read(tokens);
      expect(fliin.typography['ios']!['controlMd']!.tracking, -0.1504);
      expect(fliin.typography['android']!['controlMd']!.tracking, 0);
      expect(fliin.typography['ios']!['body']!.tracking, 0);
    });

    test('devrait lire les ombres, les graisses et la police du code du fichier du registre', () {
      final fliin = FliinTokens.read(tokens);
      expect(fliin.shadows['light']!.keys, [
        'surface',
        'overlay',
        'field',
        'glow',
        'dangerGlow',
        'thumb',
      ]);
      // Les trois couches de `--overlay-shadow` de HeroUI v3 (ADR 0019 §10).
      expect(
        fliin.shadows['light']!['overlay']!.map(
          (l) => (l.color, l.offsetY, l.blur),
        ),
        [
          (0x0F000000, 2.0, 8.0),
          (0x08000000, -6.0, 12.0),
          (0x14000000, 14.0, 28.0),
        ],
      );
      expect(fliin.shadows['dark']!['overlay']!.single.color, 0x80000000);
      // Le halo suit l'accent par `$ref` : sa couleur est celle de l'accent.
      expect(
        fliin.shadows['light']!['glow']!.first.color & 0xFFFFFF,
        fliin.light['accent']! & 0xFFFFFF,
      );
      expect(fliin.fontWeights, {
        'normal': 400,
        'medium': 500,
        'semibold': 600,
        'bold': 700,
      });
      expect(fliin.monospaceFamily, {'ios': 'Menlo', 'android': 'monospace'});
    });

    test('devrait refuser des ombres sombres qui ne portent pas les noms des claires (règle 8)', () {
      final json = registryJson();
      final light = at(json, 'shadow.light');
      light['veil'] = copy(light['surface']);
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('shadow.dark'),
      );
    });

    test('devrait refuser la police système pour le code quand typography.monospace la demande', () {
      final json = registryJson();
      at(json, 'typography.monospace.ios')[r'$extensions'] = {
        'dev.fliin.fontFamily': {'source': 'platform-default'},
      };
      at(json, 'typography.monospace.ios')[r'$value'] = [
        'system-ui',
        'sans-serif',
      ];
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('typography.monospace.ios'),
      );
    });

    test('devrait refuser un rôle requis par core/ absent de color.dark', () {
      final json = registryJson();
      at(json, 'color.dark').remove('focusRing');
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('color.dark.focusRing'),
      );
    });

    test('devrait refuser un rôle clair sans jumeau sombre quand il n’est pas requis (règle 8)', () {
      final json = registryJson();
      at(json, 'color.light')['brand'] = {r'$value': '{color.neutral.0}'};
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('color.dark'),
      );
    });

    test('devrait refuser les rôles sombres dans un autre ordre que les clairs (règle 8)', () {
      final json = registryJson();
      final dark = at(json, 'color.dark');
      final surface = dark.remove('surface');
      dark['surface'] = surface;
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('color.dark'),
      );
    });

    test(
      'devrait refuser une graisse hors des pas de 100 avec le chemin du jeton',
      () {
        final json = registryJson();
        at(json, 'typography.scale.ios.body')['weight'] = {
          r'$type': 'fontWeight',
          r'$value': 450,
        };
        expect(
          () => FliinTokens.read(resolve(json)),
          throwsToken<MissingFliinToken>('typography.scale.ios.body.weight'),
        );
      },
    );

    test('devrait refuser un rôle typographique présent sur iOS seulement', () {
      final json = registryJson();
      final ios = at(json, 'typography.scale.ios');
      ios['hero'] = copy(ios['display']);
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('typography.scale.android'),
      );
    });

    test('devrait refuser des rôles typographiques dans un autre ordre sur Android', () {
      final json = registryJson();
      final android = at(json, 'typography.scale.android');
      final display = android.remove('display');
      android['display'] = display;
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('typography.scale.android'),
      );
    });

    group('noms émis comme identifiants Dart', () {
      final valid = {
        'color.light': {r'$value': '{color.neutral.0}'},
        'space': {
          r'$value': {'value': 4, 'unit': 'px'},
        },
        'motion.duration': {
          r'$value': {'value': 100, 'unit': 'ms'},
        },
      };
      for (final (group, name) in [
        ('color.light', 'hashCode'),
        ('color.light', 'values'),
        ('color.light', 'index'),
        ('color.light', 'contrastPairs'),
        ('color.light', 'brand-primary'),
        ('color.light', 'default'),
        ('color.light', 'Brand'),
        ('space', '3xl'),
        ('space', 'toString'),
        ('space', 'double'),
        ('motion.duration', 'pressedScale'),
        ('motion.duration', 'standard'),
      ]) {
        test(
          'devrait refuser « $name » avec son chemin quand il est sous $group',
          () {
            final json = registryJson();
            at(json, group)[name] = copy(valid[group]);
            if (group == 'color.light') {
              at(json, 'color.dark')[name] = copy(valid[group]);
            }
            expect(
              () => FliinTokens.read(resolve(json)),
              throwsToken<MissingFliinToken>('$group.$name'),
            );
          },
        );
      }

      test('devrait accepter un nom en lowerCamelCase qui est un mot-clé contextuel', () {
        final json = registryJson();
        at(json, 'space')['base'] = copy(valid['space']);
        expect(FliinTokens.read(resolve(json)).space['base'], 4);
      });
    });

    test('devrait dire qu’un rôle imbriqué n’est pas lu quand color.light contient un groupe', () {
      final json = registryJson();
      for (final theme in ['light', 'dark']) {
        at(json, 'color.$theme')['brand'] = {
          'primary': {r'$value': '{color.neutral.0}'},
        };
      }
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsA(
          isA<MissingFliinToken>()
              .having((e) => e.path, 'path', 'color.light.brand')
              .having((e) => e.reason, 'reason', contains('group')),
        ),
      );
    });

    test('devrait refuser une police modifiée tant que sa source est platform-default', () {
      final json = registryJson();
      at(json, 'typography.family.ios')[r'$value'] = ['Inter'];
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('typography.family.ios'),
      );
    });

    group('police nommée', () {
      Map<String, Object?> withFont(Object? value, Object? source) {
        final json = registryJson();
        final family = at(json, 'typography.family.ios');
        family[r'$value'] = value;
        family[r'$extensions'] = {
          FliinTokens.fontFamilyExtension: {'source': source},
        };
        return json;
      }

      test('devrait lire la première famille quand la source est named', () {
        expect(
          FliinTokens.read(resolve(withFont(['Inter', 'sans-serif'], 'named')))
              .fontFamily['ios'],
          'Inter',
        );
      });

      test('devrait refuser un rôle typographique fontFamily, déjà un champ de l’échelle générée', () {
        final json = registryJson();
        for (final platform in FliinTokens.platforms) {
          final scale = at(json, 'typography.scale.$platform');
          scale['fontFamily'] = copy(scale['body']);
        }
        expect(
          () => FliinTokens.read(resolve(json)),
          throwsToken<MissingFliinToken>('typography.scale.ios.fontFamily'),
        );
      });

      for (final (label, value, source) in [
        ('une liste vide', <String>[], 'named'),
        ('un nom blanc', ['  '], 'named'),
        ('un caractère de contrôle', ['In\nter'], 'named'),
        ('une source inconnue', ['Inter'], 'asset'),
      ]) {
        test('devrait refuser $label', () {
          expect(
            () => FliinTokens.read(resolve(withFont(value, source))),
            throwsA(
              isA<MissingFliinToken>().having(
                (e) => e.path,
                'path',
                'typography.family.ios',
              ),
            ),
          );
        });
      }
    });

    for (final (group, name) in [
      ('size', 'cursorWidth'),
      ('color.light', 'danger'),
      ('color.light', 'selection'),
    ]) {
      test(
        'devrait refuser un fichier sans $group.$name, que le champ de texte lit',
        () {
          final json = registryJson();
          // Les teintes qui reprennent ses composantes par `$ref` ne
          // résoudraient plus : elles prennent une valeur écrite.
          final pointer = '#/${group.replaceAll('.', '/')}/$name/';
          for (final roles in [
            at(json, 'color.light'),
            at(json, 'color.dark'),
          ]) {
            for (final token
                in roles.values.whereType<Map<String, Object?>>()) {
              if (token[r'$value']
                  case {'components': {r'$ref': final String ref}}
                  when ref.startsWith(pointer)) {
                (token[r'$value']! as Map)['components'] = [0.5, 0.5, 0.5];
              }
            }
          }
          at(json, group).remove(name);
          expect(
            () => FliinTokens.read(resolve(json)),
            throwsToken<MissingFliinToken>('$group.$name'),
          );
        },
      );
    }

    test('devrait refuser un number sous size ailleurs qu’iconMaxScale et scrimOpacity', () {
      final json = registryJson();
      at(json, 'size')['controlCompact'] = {r'$type': 'number', r'$value': 36};
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('size.controlCompact'),
      );
    });

    for (final name in [
      'iconMaxScale',
      'scrimOpacity',
      'disabledOpacity',
      'pressedOverlayOpacity',
      'hoverBrightness',
    ]) {
      test(
        'devrait refuser une dimension pour $name, qui n’est pas une longueur',
        () {
          final json = registryJson();
          at(json, 'size')[name] = {
            r'$value': {'value': 1.5, 'unit': 'px'},
          };
          expect(
            () => FliinTokens.read(resolve(json)),
            throwsToken<MissingFliinToken>('size.$name'),
          );
        },
      );
    }

    test('devrait refuser une paire de contraste déclarée deux fois, même avec un autre seuil', () {
      final json = registryJson();
      final pairs =
          ((at(json, 'color')[r'$extensions']!
                  as Map<String, Object?>)[FliinTokens.contrastExtension]!
              as List<Object?>);
      pairs.add({
        'foreground': 'accent',
        'background': 'surfaceOverlay',
        'kind': 'ui',
      });
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsA(
          isA<MissingFliinToken>()
              .having((e) => e.path, 'path', 'color')
              .having(
                (e) => e.reason,
                'reason',
                contains('accent/surfaceOverlay'),
              ),
        ),
      );
    });

    for (final name in [
      'scrimOpacity',
      'disabledOpacity',
      'pressedOverlayOpacity',
    ]) {
      for (final opacity in [-0.1, 1.2]) {
        test('devrait refuser $name à $opacity, hors de [0, 1]', () {
          final json = registryJson();
          at(json, 'size')[name] = {r'$type': 'number', r'$value': opacity};
          expect(
            () => FliinTokens.read(resolve(json)),
            throwsToken<MissingFliinToken>('size.$name'),
          );
        });
      }
    }

    test('devrait refuser une paire de contraste vers un rôle inconnu', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final color = json['color']! as Map<String, Object?>;
      color[r'$extensions'] = {
        FliinTokens.contrastExtension: [
          {'foreground': 'nope', 'background': 'surface', 'kind': 'text'},
        ],
      };
      expect(
        () => FliinTokens.read(resolve(json)),
        throwsToken<MissingFliinToken>('color'),
      );
    });
  });
}

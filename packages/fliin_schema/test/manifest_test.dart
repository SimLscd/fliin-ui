import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

final buttonSha = Sha256.ofString('fl_button.dart').value;

/// L'exemple de DESIGN.md §4.1, adapté à `button`.
Map<String, Object?> buttonJson() => {
  'name': 'button',
  'type': 'registry:component',
  'version': '1.3.0',
  'title': 'Bouton',
  'description': "Bouton d'action, principal, secondaire ou discret.",
  'flutter': '>=3.47.0 <4.0.0',
  'dependencies': {},
  'registryDependencies': ['core@^1.0.0', '@pro/confirm-sheet@^1.0.0'],
  'files': [
    {
      'path': 'components/button/fl_button.dart',
      'type': 'registry:component',
      'target': '@components/button/fl_button.dart',
      'sha256': buttonSha,
    },
  ],
  'l10n': {
    'buttonLoading': {
      'en': 'Loading',
      'fr': 'Chargement',
      'ar': 'جارٍ التحميل',
    },
  },
  'snippets': {
    'route': {'go_router': "GoRoute(path: '/')", 'navigator': '…'},
    'state': {'provider': '…', 'none': '…'},
  },
  'categories': ['action', 'form'],
  'meta': {
    'tier': 'free',
    'platforms': ['ios', 'android', 'web', 'macos', 'windows', 'linux'],
    'states': ['enabled', 'disabled', 'loading'],
    'semanticsRoles': ['button'],
    'intents': {
      'fr': ["bouton d'action principal", 'valider un formulaire'],
      'en': ['primary action button', 'submit a form'],
    },
    'notFor': ['lien de navigation : utiliser link'],
  },
};

Matcher throwsAt<T extends ManifestError>(String path) =>
    throwsA(isA<T>().having((error) => error.path, 'path', path));

void main() {
  test('devrait réécrire exactement le JSON lu quand il est canonique', () {
    final json = buttonJson();
    expect(ItemManifest.fromJson(json).toJson(), json);
  });

  test("devrait garder l'empreinte canonique quand on relit puis réécrit le manifeste (règle 2)", () {
    final published = Sha256.ofString(canonicalJson(buttonJson()));
    final reread = ItemManifest.fromJson(jsonDecode(jsonEncode(buttonJson())))
        .toJson();
    expect(Sha256.ofString(canonicalJson(reread)), published);
  });

  test('devrait typer chaque champ quand le manifeste est valide', () {
    final manifest = ItemManifest.fromJson(buttonJson());
    expect(manifest.type, ItemType.component);
    expect(manifest.version, Version(1, 3, 0));
    expect(manifest.flutter.allows(Version(3, 47, 7)), isTrue);
    expect(
      manifest.registryDependencies.last.ref.namespace,
      Namespace.parse('@pro'),
    );
    expect(manifest.files.single.target.alias, TargetAlias.components);
    expect(manifest.files.single.sha256, Sha256.parse(buttonSha));
    expect(manifest.meta.platforms, contains(Platform.android));
    expect(manifest.meta.intents.fr, contains("bouton d'action principal"));
    expect(manifest.status, isA<Published>());
  });

  test("devrait relire les écrans que supposent les extraits, et ne les écrire que s'il y en a", () {
    final json = buttonJson()
      ..['snippets'] = <String, Object?>{
        ...(buttonJson()['snippets']! as Map<String, Object?>),
        'screens': ['sign-in', 'product'],
      };
    final manifest = ItemManifest.fromJson(json);
    expect(manifest.snippets.screens, ['sign-in', 'product']);
    expect(manifest.toJson(), json);
    expect(
      (ItemManifest.fromJson(buttonJson()).toJson()['snippets']!
              as Map<String, Object?>)
          .keys,
      isNot(contains('screens')),
    );
  });

  test('devrait valoir vide quand une collection facultative est absente', () {
    final json = buttonJson()
      ..remove('dependencies')
      ..remove('registryDependencies')
      ..remove('l10n')
      ..['snippets'] = {}
      ..remove('categories');
    final manifest = ItemManifest.fromJson(json);
    expect(manifest.registryDependencies, isEmpty);
    expect(manifest.snippets.route, isEmpty);
    expect(manifest.l10n, isEmpty);
  });

  test('devrait relire le retrait quand une version est yanked (règle 12)', () {
    final json = buttonJson()..['status'] = {'yanked': 'régression RTL'};
    final status = ItemManifest.fromJson(json).status;
    expect(
      status,
      isA<Yanked>().having((s) => s.reason, 'reason', 'régression RTL'),
    );
    expect(ItemManifest.fromJson(json).toJson(), json);
  });

  test('devrait relire le changelog et chaque sorte de cassure, et les réécrire à l’identique', () {
    final json = {
      ...buttonJson(),
      'changelog': 'Ajoute la variante discrète.',
      'breaking': [
        {'kind': 'removed', 'symbol': 'FlButton.loading'},
        {
          'kind': 'signatureChanged',
          'symbol': 'FlButton.label',
          'before': 'String',
          'after': 'Widget',
        },
        {
          'kind': 'requiredParameterAdded',
          'symbol': 'FlButton.new',
          'parameter': 'icon',
        },
        {'kind': 'semantic', 'description': 'Le focus ne suit plus le survol.'},
      ],
    };
    final manifest = ItemManifest.fromJson(json);
    expect(manifest.changelog, 'Ajoute la variante discrète.');
    expect(manifest.breaking, [
      const RemovedDeclaration('FlButton.loading'),
      const ChangedSignature(
        'FlButton.label',
        before: 'String',
        after: 'Widget',
      ),
      const RequiredParameterAdded('FlButton.new', parameter: 'icon'),
      const SemanticBreak('Le focus ne suit plus le survol.'),
    ]);
    expect(manifest.toJson(), json);
  });

  test('devrait garder l’empreinte d’un manifeste sans changelog ni cassure (règle 2)', () {
    final manifest = ItemManifest.fromJson(buttonJson());
    expect(manifest.breaking, isEmpty);
    expect(manifest.toJson().keys, isNot(contains('breaking')));
    expect(manifest.toJson().keys, isNot(contains('changelog')));
  });

  test('devrait refuser une cassure de sorte inconnue avec son chemin', () {
    final json = {
      ...buttonJson(),
      'breaking': [
        {'kind': 'renamed', 'symbol': 'FlButton'},
      ],
    };
    expect(
      () => ItemManifest.fromJson(json),
      throwsAt<UnknownValue>(r'$.breaking[0].kind'),
    );
  });

  test('devrait relire entry et imports quand le manifeste porte verify', () {
    final json = buttonJson()
      ..['verify'] = {
        'entry': "{prefix}Button(label: 'Ok', onPressed: () {})",
        'imports': ['@components/button/fl_button.dart', '@core/fliin.dart'],
      };
    final verify = ItemManifest.fromJson(json).verify!;
    expect(verify.entry, contains('{prefix}Button'));
    expect(verify.imports.map((t) => t.alias), [
      TargetAlias.components,
      TargetAlias.core,
    ]);
    expect(ItemManifest.fromJson(json).toJson(), json);
    expect(ItemManifest.fromJson(buttonJson()).verify, isNull);
  });

  test('devrait relire canvas et settleMs, et les réécrire à l’identique', () {
    final json = buttonJson()
      ..['verify'] = {
        'entry': '{prefix}Button()',
        'imports': ['@core/fliin.dart'],
        'canvas': {'width': 390, 'height': 560},
        'settleMs': 400,
      };
    final verify = ItemManifest.fromJson(json).verify!;
    expect(verify.canvas, isA<UniformCanvas>());
    expect(verify.canvas!.android, (width: 390, height: 560));
    expect(verify.settleMs, 400);
    expect(verify.toJson(), json['verify']);
  });

  test(
    'devrait relire une taille par plateforme, et la réécrire à l’identique',
    () {
      final json = buttonJson()
        ..['verify'] = {
          'entry': '{prefix}Button()',
          'imports': ['@core/fliin.dart'],
          'canvas': {
            'ios': {'width': 390, 'height': 844},
            'android': {'width': 412, 'height': 915},
          },
        };
      final verify = ItemManifest.fromJson(json).verify!;
      expect(verify.canvas!.ios, (width: 390, height: 844));
      expect(verify.canvas!.android, (width: 412, height: 915));
      expect(verify.toJson(), json['verify']);
    },
  );

  for (final (field, value, path) in [
    ('settleMs', 5000, r'$.verify.settleMs'),
    ('settleMs', 0, r'$.verify.settleMs'),
    ('canvas', {'width': 390, 'height': 0}, r'$.verify.canvas.height'),
  ]) {
    test('devrait refuser verify.$field à $value, hors de ses bornes', () {
      final json = buttonJson()
        ..['verify'] = {
          'entry': '{prefix}Button()',
          'imports': ['@core/fliin.dart'],
          field: value,
        };
      expect(
        () => ItemManifest.fromJson(json),
        throwsA(isA<InvalidValue>().having((e) => e.path, 'path', path)),
      );
    });
  }

  Map<String, Object?> goldensJson({String host = 'macos', int count = 16}) => {
    'host': host,
    'rendering': {
      'abi': 'macos-arm64',
      'flutter': '3.47.7',
      'fonts': {'SFNS.ttf': '2f7e3871468bf56b'},
    },
    'variants': {
      for (final id in variantIds.take(count)) id: Sha256.ofString(id).value,
    },
  };

  test('devrait relire les goldens par variante et les états rendus, et les réécrire à l’identique', () {
    final json = buttonJson()
      ..['verify'] = {
        'entry': '{prefix}Button()',
        'imports': ['@core/fliin.dart'],
        'states': ['enabled', 'loading'],
        'goldens': goldensJson(),
      };
    final verify = ItemManifest.fromJson(json).verify!;
    expect(verify.states, ['enabled', 'loading']);
    expect(verify.goldens!.host, GoldenHost.macos);
    expect(verify.goldens!.variants.keys, variantIds);
    expect(
      verify.goldens!.variants['android.dark.2.0.rtl'],
      Sha256.ofString('android.dark.2.0.rtl'),
    );
    expect(ItemManifest.fromJson(json).toJson(), json);
  });

  for (final (label, goldens, path) in [
    ('quinze variantes', goldensJson(count: 15), r'$.verify.goldens.variants'),
    (
      'une variante inconnue',
      goldensJson()
        ..['variants'] = {
          ...(goldensJson()['variants']! as Map<String, Object?>),
          'web.light.1.0.ltr': Sha256.ofString('web').value,
        },
      r'$.verify.goldens.variants',
    ),
    ('un hôte inconnu', goldensJson(host: 'beos'), r'$.verify.goldens.host'),
  ]) {
    test('devrait refuser des goldens à $label', () {
      final json = buttonJson()
        ..['verify'] = {
          'entry': '{prefix}Button()',
          'imports': ['@core/fliin.dart'],
          'goldens': goldens,
        };
      expect(
        () => ItemManifest.fromJson(json),
        throwsA(isA<ManifestError>().having((e) => e.path, 'path', path)),
      );
    });
  }

  test('devrait garder octet pour octet un manifeste publié sans golden quand on le relit puis le réécrit', () {
    final published = File('test/fixtures/switch-0.1.0.published.json')
        .readAsBytesSync();
    final reread = ItemManifest.fromJson(jsonDecode(utf8.decode(published)));
    expect(reread.verify!.goldens, isNull);
    expect(
      Sha256.ofString(canonicalJson(reread.toJson())),
      Sha256.ofBytes(published),
    );
  });

  test('devrait garder les jetons opaques quand le manifeste en porte', () {
    final json = buttonJson()
      ..['tokens'] = {
        'light': {
          'button': {
            'radius': {r'$value': 10, r'$type': 'dimension'},
          },
        },
        'dark': {
          'button': {
            'radius': {r'$value': 10.5},
          },
        },
      };
    expect(ItemManifest.fromJson(json).toJson(), json);
  });

  group('variantes de fichier', () {
    final gravity = Sha256.ofString('gravity').value;
    final lucide = Sha256.ofString('lucide').value;
    Map<String, Object?> iconsJson({bool variants = true}) => {
      ...buttonJson(),
      'name': 'icons',
      'type': 'registry:icon',
      'version': '0.1.1',
      'files': [
        {
          'path': 'icons/fl_icons.dart',
          'type': 'registry:icon',
          'target': '@icons/fl_icons.dart',
          'sha256': gravity,
          if (variants)
            'variants': {
              'lucide': {
                'path': 'icons/sets/lucide/fl_icons.dart',
                'sha256': lucide,
              },
            },
        },
      ],
    };

    test(
      'devrait relire et réécrire à l’identique les variantes d’un fichier',
      () {
        final json = iconsJson();
        final manifest = ItemManifest.fromJson(json);
        expect(manifest.files.single.variants['lucide']!.sha256.value, lucide);
        expect(manifest.toJson(), json);
      },
    );

    test('devrait installer le contenu de la variante à la même cible quand le projet a choisi son jeu', () {
      final file = ItemManifest.fromJson(iconsJson())
          .select('lucide')
          .files
          .single;
      expect(file.sha256.value, lucide);
      expect(file.path, 'icons/sets/lucide/fl_icons.dart');
      expect('${file.target}', '@icons/fl_icons.dart');
      expect(file.variants, isEmpty);
    });

    test('devrait garder le fichier par défaut quand le projet n’a pas choisi de jeu', () {
      final file = ItemManifest.fromJson(iconsJson()).select(null).files.single;
      expect(file.sha256.value, gravity);
      expect(file.variants, isEmpty);
    });

    test('devrait laisser intact un élément sans variante quel que soit le jeu choisi', () {
      final button = ItemManifest.fromJson(buttonJson());
      expect(button.select('lucide').toJson(), button.toJson());
    });

    test(
      'devrait refuser un jeu absent au lieu d’installer le jeu par défaut',
      () {
        expect(
          () => ItemManifest.fromJson(iconsJson()).select('tabler'),
          throwsA(
            isA<MissingVariant>().having(
              (e) => '$e',
              'message',
              contains('fliin update icons'),
            ),
          ),
        );
      },
    );

    test('devrait refuser un jeu choisi quand la version d’icons a été publiée sans variante', () {
      expect(
        () =>
            ItemManifest.fromJson(iconsJson(variants: false)).select('lucide'),
        throwsA(isA<MissingVariant>()),
      );
    });

    test('devrait situer une variante sans empreinte', () {
      final json = iconsJson();
      ((json['files']! as List<Object?>).single!
          as Map<String, Object?>)['variants'] = {
        'lucide': {'path': 'icons/sets/lucide/fl_icons.dart'},
      };
      expect(
        () => ItemManifest.fromJson(json),
        throwsAt<MissingField>(r'$.files[0].variants.lucide.sha256'),
      );
    });
  });

  group('devrait lever une ManifestError située quand', () {
    test('un champ obligatoire manque', () {
      expect(
        () => ItemManifest.fromJson(buttonJson()..remove('name')),
        throwsAt<MissingField>(r'$.name'),
      );
      final json = buttonJson();
      ((json['meta']! as Map)['intents']! as Map).remove('en');
      expect(
        () => ItemManifest.fromJson(json),
        throwsAt<MissingField>(r'$.meta.intents.en'),
      );
    });

    test('le type est inconnu', () {
      expect(
        () => ItemManifest.fromJson(buttonJson()..['type'] = 'registry:widget'),
        throwsAt<UnknownValue>(r'$.type'),
      );
    });

    test('la version est invalide', () {
      expect(
        () => ItemManifest.fromJson(buttonJson()..['version'] = '1.3'),
        throwsAt<InvalidVersion>(r'$.version'),
      );
      expect(
        () => ItemManifest.fromJson(
          buttonJson()..['dependencies'] = {'intl': '^x'},
        ),
        throwsAt<InvalidVersion>(r'$.dependencies.intl'),
      );
    });

    test('un sha256 est invalide', () {
      final json = buttonJson();
      ((json['files']! as List).single as Map)['sha256'] = buttonSha
          .toUpperCase();
      expect(
        () => ItemManifest.fromJson(json),
        throwsAt<InvalidSha256>(r'$.files[0].sha256'),
      );
    });

    test('une dépendance est malformée', () {
      expect(
        () => ItemManifest.fromJson(
          buttonJson()..['registryDependencies'] = ['core@^1.0.0', 'Core'],
        ),
        throwsAt<MalformedReference>(r'$.registryDependencies[1]'),
      );
    });

    test('une cible sort de sa racine', () {
      final json = buttonJson();
      ((json['files']! as List).single as Map)['target'] =
          '@components/../../../.ssh/config';
      expect(
        () => ItemManifest.fromJson(json),
        throwsAt<InvalidValue>(r'$.files[0].target'),
      );
    });

    test("une valeur n'a pas le bon type JSON", () {
      expect(
        () => ItemManifest.fromJson(buttonJson()..['files'] = {}),
        throwsAt<WrongJsonType>(r'$.files'),
      );
      expect(
        () => ItemManifest.fromJson(
          buttonJson()
            ..['l10n'] = {
              'k': {'fr': 1},
            },
        ),
        throwsAt<WrongJsonType>(r'$.l10n.k.fr'),
      );
    });

    test("le nom n'est pas en kebab-case", () {
      expect(
        () => ItemManifest.fromJson(buttonJson()..['name'] = 'FlButton'),
        throwsAt<InvalidValue>(r'$.name'),
      );
    });
  });
}

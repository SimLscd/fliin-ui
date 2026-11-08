import 'dart:convert';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

final key = base64Encode(List.filled(32, 7));

/// Ce que `package:yaml` rend pour `fliin.yaml` : des Map aux clés dynamiques.
Map<Object?, Object?> yaml() => <Object?, Object?>{
  'root': 'lib/ui/fliin',
  'prefix': 'Fl',
  'package': 'mon_app',
  'registries': <Object?, Object?>{
    '@fliin': <Object?, Object?>{
      'url': 'https://registry.fliin.dev/',
      'trustedKeys': [key],
      'auth': 'none',
    },
    '@acme': <Object?, Object?>{
      'url': 'file:///srv/acme-registry/',
      'trustedKeys': [key],
      'auth': 'header',
    },
  },
  'agents': <Object?, Object?>{
    'claudeCode': <Object?, Object?>{},
    'androidStudio': <Object?, Object?>{'port': 47821},
  },
};

Matcher throwsAt<T extends ManifestError>(String path) =>
    throwsA(isA<T>().having((error) => error.path, 'path', path));

void main() {
  test('devrait typer fliin.yaml quand il arrive décodé par package:yaml', () {
    final config = FliinConfig.fromJson(yaml());
    expect(config.render.root, 'lib/ui/fliin');
    expect(config.render.importRoot, 'ui/fliin');
    expect(config.registries.keys, [Namespace.fliin, Namespace.parse('@acme')]);
    expect(
      config.registries[Namespace.parse('@acme')]!.auth,
      RegistryAuth.header,
    );
    expect(config.agents, [
      isA<ClaudeCodeAgent>(),
      isA<AndroidStudioAgent>().having((a) => a.port, 'port', 47821),
    ]);
  });

  test('devrait réécrire exactement la Map lue quand elle est canonique', () {
    expect(FliinConfig.fromJson(yaml()).toJson(), yaml());
  });

  test(
    'ne devrait jamais écrire de jeton quand Android Studio est configuré',
    () {
      final json = yaml();
      (json['agents']! as Map)['androidStudio'] = <Object?, Object?>{
        'port': 47821,
        'token': 'secret',
      };
      final agents = FliinConfig.fromJson(json).toJson()['agents']! as Map;
      expect(agents['androidStudio'], {'port': 47821});
    },
  );

  test("devrait terminer l'URL par une barre quand elle n'en a pas", () {
    final json = yaml();
    ((json['registries']! as Map)['@fliin']! as Map)['url'] =
        'https://registry.fliin.dev/v1';
    final url = FliinConfig.fromJson(json).registries[Namespace.fliin]!.url;
    expect(
      url.resolve(DistLayout.pointerPath),
      Uri.parse('https://registry.fliin.dev/v1/latest.json'),
    );
  });

  group('configHash (règle 3)', () {
    test('devrait hacher le JSON canonique de root, prefix et package', () {
      expect(
        FliinConfig.fromJson(yaml()).render.configHash,
        Sha256.ofString(
          '{"package":"mon_app","prefix":"Fl","root":"lib/ui/fliin"}',
        ),
      );
    });

    test(
      'ne devrait pas changer quand seuls les registres ou les agents changent',
      () {
        final before = FliinConfig.fromJson(yaml()).render.configHash;
        final json = yaml()
          ..['registries'] = <Object?, Object?>{}
          ..['agents'] = <Object?, Object?>{'cursor': null};
        expect(FliinConfig.fromJson(json).render.configHash, before);
      },
    );

    test('devrait changer quand root, prefix ou package change', () {
      final before = FliinConfig.fromJson(yaml()).render.configHash;
      for (final (field, value) in [
        ('root', 'lib/ui/kit'),
        ('prefix', 'Ac'),
        ('package', 'autre_app'),
      ]) {
        final json = yaml()..[field] = value;
        expect(
          FliinConfig.fromJson(json).render.configHash,
          isNot(before),
          reason: field,
        );
      }
    });
  });

  group('devrait lever une ManifestError située quand', () {
    test('root sort de lib/ ou contient des majuscules', () {
      for (final root in [
        'ui/fliin',
        'lib',
        'lib/../secrets',
        'lib/ui/FlKit',
        '/lib/ui',
      ]) {
        expect(
          () => FliinConfig.fromJson(yaml()..['root'] = root),
          throwsAt<InvalidValue>(r'$.root'),
          reason: root,
        );
      }
    });

    test('le préfixe ne commence pas par une majuscule', () {
      expect(
        () => FliinConfig.fromJson(yaml()..['prefix'] = 'fl'),
        throwsAt<InvalidValue>(r'$.prefix'),
      );
    });

    test("l'URL n'est ni https ni file", () {
      final json = yaml();
      ((json['registries']! as Map)['@fliin']! as Map)['url'] =
          'http://registry.fliin.dev/';
      expect(
        () => FliinConfig.fromJson(json),
        throwsAt<InvalidValue>(r"$.registries['@fliin'].url"),
      );
    });

    test('l’URL est en http:// clair hors de la boucle locale', () {
      final json = yaml();
      ((json['registries']! as Map)['@fliin']! as Map)['url'] =
          'http://192.168.1.10/';
      expect(
        () => FliinConfig.fromJson(json),
        throwsA(
          isA<InvalidValue>().having(
            (e) => e.reason,
            'reason',
            contains('(use https://)'),
          ),
        ),
      );
    });

    test("une clé de confiance n'est pas une clé Ed25519 en base64", () {
      final json = yaml();
      ((json['registries']! as Map)['@fliin']! as Map)['trustedKeys'] = [
        base64Encode([1, 2, 3]),
      ];
      expect(
        () => FliinConfig.fromJson(json),
        throwsAt<InvalidValue>(r"$.registries['@fliin'].trustedKeys[0]"),
      );
    });

    test("un registre n'a aucune clé de confiance", () {
      final json = yaml();
      ((json['registries']! as Map)['@fliin']! as Map)['trustedKeys'] =
          <String>[];
      expect(
        () => FliinConfig.fromJson(json),
        throwsAt<InvalidValue>(r"$.registries['@fliin'].trustedKeys"),
      );
    });

    test('un agent est inconnu ou son port invalide', () {
      expect(
        () => FliinConfig.fromJson(
          yaml()..['agents'] = <Object?, Object?>{'windsurf': null},
        ),
        throwsAt<UnknownValue>(r'$.agents.windsurf'),
      );
      expect(
        () => FliinConfig.fromJson(
          yaml()
            ..['agents'] = <Object?, Object?>{
              'androidStudio': <Object?, Object?>{'port': 70000},
            },
        ),
        throwsAt<InvalidValue>(r'$.agents.androidStudio.port'),
      );
    });

    test("un espace de noms n'est pas de la forme @nom", () {
      final json = yaml()
        ..['registries'] = <Object?, Object?>{
          'fliin': (yaml()['registries']! as Map)['@fliin'],
        };
      expect(
        () => FliinConfig.fromJson(json),
        throwsAt<InvalidValue>(r'$.registries.fliin'),
      );
    });
  });

  test(
    'devrait refuser une config quand on la construit avec un champ invalide',
    () {
      expect(
        () => RenderConfig(root: 'lib/ui', prefix: 'Fl', package: 'Mon-App'),
        throwsFormatException,
      );
    },
  );

  test('devrait accepter http:// en clair sur la boucle locale seulement (ADR 0011)', () {
    for (final url in [
      'http://localhost:8080/',
      'http://127.0.0.1:8080/',
      'http://[::1]:8080/',
    ]) {
      expect(
        RegistrySource.parseUrl(url).isScheme('http'),
        isTrue,
        reason: url,
      );
    }
    expect(isLoopbackHost('localhost.example.com'), isFalse);
    expect(isLoopbackHost('128.0.0.1'), isFalse);
  });

  test('devrait relire le préréglage de theme.preset, et refuser un code invalide avec son chemin (ADR 0016, M4)', () {
    final json = {
      ...yaml(),
      'theme': <Object?, Object?>{'preset': 'c0m1Vr90000000'},
    };
    final config = FliinConfig.fromJson(json);
    expect(config.preset, Preset.decode('c0m1Vr90000000'));
    expect(config.toJson(), json);
    expect(FliinConfig.fromJson(yaml()).preset, isNull);
    expect(
      () => FliinConfig.fromJson({
        ...yaml(),
        'theme': <Object?, Object?>{'preset': 'c00'},
      }),
      throwsAt<InvalidValue>(r'$.theme.preset'),
    );
  });

  test('devrait garder sans le lire un préréglage de la version a, puis l’effacer quand un autre le remplace (ADR 0019 §5)', () {
    final json = {
      ...yaml(),
      'theme': <Object?, Object?>{'preset': 'a0m1VrO'},
    };
    final config = FliinConfig.fromJson(json);
    expect(config.preset, isNull);
    expect(config.retiredPreset, 'a0m1VrO');
    expect(config.toJson(), json);
    final replaced = config.withPreset(Preset.decode('c0m1Vr90000000'));
    expect(replaced.retiredPreset, isNull);
    expect(replaced.toJson()['theme'], {'preset': 'c0m1Vr90000000'});
  });
}

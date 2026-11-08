import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin/src/tokens/generate.dart';
import 'package:fliin/src/tokens/project_tokens.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Token;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/gen_tokens.dart' as gen;
import '../support/cli.dart';

const registryTokens = '../../flutter/registry/lib/core/tokens';

FliinTokens readRegistry() => FliinTokens.read(
  resolveTokens(
    TokenDocument.fromJson(
      jsonDecode(
        File(p.join(registryTokens, tokensJsonName)).readAsStringSync(),
      ),
    ),
  ),
);

/// Ajoute [role] en clair et en sombre, alias de `color.neutral.0`.
void addRole(Map<String, Object?> json, String role) {
  final color = json['color']! as Map<String, Object?>;
  for (final theme in ['light', 'dark']) {
    (color[theme]! as Map<String, Object?>)[role] = {
      r'$value': '{color.neutral.0}',
    };
  }
}

void main() {
  group('générateur', () {
    test('devrait produire exactement le tokens.g.dart commité du registre (préfixe Fl)', () {
      expect(
        normalize(tokensDart(readRegistry(), prefix: 'Fl')),
        File(p.join(registryTokens, tokensDartName)).readAsStringSync(),
        reason: 'lancez dart run packages/fliin/tool/gen_tokens.dart',
      );
    });

    test('devrait produire exactement le torture.g.dart commité depuis les thèmes de torture du registre', () {
      expect(
        gen.generateTortureTokens(
          Directory('../../${gen.tortureDir}'),
          check: true,
        ),
        isA<TokensUpToDate>(),
        reason: 'lancez dart run packages/fliin/tool/gen_tokens.dart',
      );
    });

    test('devrait donner le même fichier par génération directe et par réécriture du préfixe après init', () {
      final tokens = readRegistry();
      final installed = normalize(tokensDart(tokens, prefix: 'Fl'));
      for (final prefix in ['A', 'Ac', 'Acme', 'VeryLongPrefix']) {
        final config = RenderConfig(
          root: 'lib/ui/fliin',
          prefix: prefix,
          package: 'app',
        );
        expect(
          normalize(applyRewrites(installed, config)),
          normalize(tokensDart(tokens, prefix: prefix)),
          reason: prefix,
        );
      }
    });

    test('devrait émettre la police nommée échappée et null pour la police système', () {
      final json = jsonDecode(
        File(p.join(registryTokens, tokensJsonName)).readAsStringSync(),
      ) as Map<String, Object?>;
      final family = ((json['typography']! as Map)['family']! as Map)['ios']!
          as Map<String, Object?>;
      family[r'$value'] = [r"O'Neil \ $x", 'sans-serif'];
      family[r'$extensions'] = {
        FliinTokens.fontFamilyExtension: {'source': 'named'},
      };
      final tokens = FliinTokens.read(
        resolveTokens(TokenDocument.fromJson(json)),
      );
      final dart = normalize(tokensDart(tokens, prefix: 'Fl'));
      expect(dart, contains(r"fontFamily: 'O\'Neil \\ \$x',"));
      expect(dart, contains('fontFamily: null,'));
    });

    test('devrait garder un grand nombre tel quel quand il dépasse 2^53', () {
      final json = jsonDecode(
        File(p.join(registryTokens, tokensJsonName)).readAsStringSync(),
      ) as Map<String, Object?>;
      (json['space']! as Map<String, Object?>)['huge'] = {
        r'$value': {'value': 1e300, 'unit': 'px'},
      };
      final tokens = FliinTokens.read(
        resolveTokens(TokenDocument.fromJson(json)),
      );
      expect(tokensDart(tokens, prefix: 'Fl'), contains('huge: 1e+300,'));
    });
  });

  group('fliin tokens', () {
    late Directory project;
    late File json;
    late File generated;

    setUp(() {
      project = Directory.systemTemp.createTempSync('fliin-tokens-');
      writeFliinConfig(
        project,
        FliinConfig(
          render: RenderConfig(
            root: 'lib/ui/fliin',
            prefix: 'Ac',
            package: 'app',
          ),
          registries: const {},
          agents: const [],
        ),
      );
      final dir = Directory(p.join(project.path, 'lib/ui/fliin/core/tokens'))
        ..createSync(recursive: true);
      json = File(p.join(registryTokens, tokensJsonName))
          .copySync(p.join(dir.path, tokensJsonName));
      generated = File(p.join(dir.path, tokensDartName));
    });

    tearDown(() => project.deleteSync(recursive: true));

    test('devrait écrire tokens.g.dart avec le préfixe de fliin.yaml puis le dire à jour', () async {
      final run = await fliin(project, ['tokens', '--json']);
      expect(run.code, 0, reason: run.err);
      expect(jsonOf(run)['upToDate'], false);
      expect(generated.readAsStringSync(), contains('class AcColorTokens'));
      expect(generated.readAsStringSync(), isNot(contains('FlColorTokens')));
      final again = await fliin(project, ['tokens', '--check', '--json']);
      expect(again.code, 0, reason: again.err);
      expect(jsonOf(again)['upToDate'], true);
    });

    test('devrait sortir en 1 sans écrire quand --check trouve un tokens.g.dart qui dérive', () async {
      expect((await fliin(project, ['tokens'])).code, 0);
      generated.writeAsStringSync(
        '${generated.readAsStringSync()}\n// local\n',
      );
      final edited = generated.readAsStringSync();
      final run = await fliin(project, ['tokens', '--check', '--json']);
      expect(run.code, 1);
      expect(run.err, contains('Run fliin tokens'));
      expect(jsonOf(run)['upToDate'], isFalse);
      expect(generated.readAsStringSync(), edited);
    });

    test('devrait sortir en 1 avec le chemin du jeton fautif quand le JSON viole le format', () async {
      final text = json.readAsStringSync();
      json.writeAsStringSync(
        text.replaceFirst('"{color.neutral.0}"', '"{color.neutral.nope}"'),
      );
      final run = await fliin(project, ['tokens']);
      expect(run.code, 1);
      expect(run.err, contains('color.light.surface'));
      expect(run.err, contains('{color.neutral.nope}'));
      expect(generated.existsSync(), isFalse);
    });

    for (final (label, path, edit)
        in <(String, String, void Function(Map<String, Object?>))>[
          (
            'un rôle brand-primary',
            'color.light.brand-primary',
            (json) => addRole(json, 'brand-primary'),
          ),
          (
            'un rôle default',
            'color.light.default',
            (json) => addRole(json, 'default'),
          ),
          (
            'un rôle hashCode',
            'color.light.hashCode',
            (json) => addRole(json, 'hashCode'),
          ),
          (
            'un espacement 3xl',
            'space.3xl',
            (json) => (json['space']! as Map<String, Object?>)['3xl'] = {
              r'$value': {'value': 64, 'unit': 'px'},
            },
          ),
          (
            'un rôle typographique sur iOS seulement',
            'typography.scale.android',
            (json) {
              final scale =
                  (json['typography']! as Map<String, Object?>)['scale']!
                      as Map<String, Object?>;
              final ios = scale['ios']! as Map<String, Object?>;
              ios['hero'] = jsonDecode(jsonEncode(ios['display']));
            },
          ),
        ]) {
      test(
        'devrait sortir en 1 sans rien écrire quand le JSON nomme $label',
        () async {
          final edited =
              jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
          edit(edited);
          json.writeAsStringSync(jsonEncode(edited));
          for (final args in [
            ['tokens', '--check', '--json'],
            ['tokens', '--json'],
          ]) {
            final run = await fliin(project, args);
            expect(run.code, 1, reason: '${args.join(' ')} : ${run.err}');
            expect(run.err, contains('$path: '));
            expect(jsonOf(run)['error'], isNotNull);
            expect(jsonOf(run), isNot(contains('upToDate')));
          }
          expect(generated.existsSync(), isFalse);
        },
      );
    }

    test('devrait sortir en 1 avec le chemin du jeton quand un nombre dépasse les bornes d’un double', () async {
      final text = json.readAsStringSync();
      json.writeAsStringSync(
        text.replaceFirst(
          '"xs": {\n      "\$value": {\n        "value": 4,',
          '"xs": {\n      "\$value": {\n        "value": 1e400,',
        ),
      );
      expect(json.readAsStringSync(), isNot(text));
      final run = await fliin(project, ['tokens']);
      expect(run.code, 1, reason: run.err);
      expect(run.err, contains('space.xs'));
      expect(generated.existsSync(), isFalse);
    });

    test('devrait sortir en 3 quand le projet n’est pas initialisé', () async {
      File(p.join(project.path, fliinYamlName)).deleteSync();
      expect((await fliin(project, ['tokens'])).code, 3);
    });
  });
}

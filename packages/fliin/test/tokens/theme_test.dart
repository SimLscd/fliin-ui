import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fliin/src/install/registry_port.dart';
import 'package:fliin/src/install/lockfile_io.dart';
import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin/src/project/project_lock.dart';
import 'package:fliin/src/tokens/project_tokens.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform, Token;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/cli.dart';

const registryTokens = '../../flutter/registry/lib/core/tokens';

/// Les `Color(0x…)` de `<mode>: const FlColorTokens(…)` dans le Dart généré.
Map<String, int> generatedColors(String dart, String mode) {
  final start = dart.indexOf('$mode: const FlColorTokens(');
  final block = dart.substring(start, dart.indexOf('\n    ),', start));
  return {
    for (final match in RegExp(
      r'(\w+): Color\(0x([0-9A-F]{8})\)',
    ).allMatches(block))
      match[1]!: int.parse(match[2]!, radix: 16),
  };
}

/// WCAG 2, seuil 0,03928, la formule de `flutter/registry/test/tokens_test.dart`.
double wcagRatio(int a, int b) {
  double luminance(int argb) {
    double channel(int v) {
      final c = v / 255;
      return c <= 0.03928
          ? c / 12.92
          : pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(argb >> 16 & 0xFF) +
        0.7152 * channel(argb >> 8 & 0xFF) +
        0.0722 * channel(argb & 0xFF);
  }

  final la = luminance(a);
  final lb = luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  late Directory project;
  late Directory tokens;
  late File json;
  late File generated;

  /// Le contenu de chaque fichier du dossier des jetons, temporaires compris.
  Map<String, String> snapshot() => {
    for (final entity
        in tokens.listSync()..sort((a, b) => a.path.compareTo(b.path)))
      p.basename(entity.path): entity is File
          ? entity.readAsStringSync()
          : '<dossier>',
  };

  setUp(() async {
    project = Directory.systemTemp.createTempSync('fliin-theme-');
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
    tokens = Directory(p.join(project.path, 'lib/ui/fliin/core/tokens'))
      ..createSync(recursive: true);
    json = File(p.join(registryTokens, tokensJsonName))
        .copySync(p.join(tokens.path, tokensJsonName));
    generated = File(p.join(tokens.path, tokensDartName));
    expect((await fliin(project, ['tokens'])).code, 0);
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('devrait réécrire le JSON et tokens.g.dart, garder les extensions inconnues, puis passer tokens --check', () async {
    final edited = jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
    (edited['color']! as Map<String, Object?>)[r'$extensions'] = {
      'com.example.figma': {'collection': 'Brand'},
      ...((edited['color']! as Map)[r'$extensions']! as Map<String, Object?>),
    };
    json.writeAsStringSync(tokensJsonText(edited));

    final run = await fliin(project, [
      'theme',
      '--primary',
      '#0A6CFF',
      '--button',
      'pill',
      '--json',
    ]);
    expect(run.code, 0, reason: run.err);
    final out = jsonOf(run);
    expect(out['written'], isTrue);
    final contrast = (out['contrast']! as List).cast<Map<String, Object?>>();
    expect(contrast.map((c) => c['mode']).toSet(), {'light', 'dark'});
    expect(contrast.every((c) => c['ok'] == true), isTrue);

    final after = jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
    final extensions = (after['color']! as Map)[r'$extensions']! as Map;
    expect(extensions.keys.first, 'com.example.figma');
    expect(after.keys, edited.keys);
    expect(
      json.readAsStringSync(),
      tokensJsonText(
        applyJsonPatch(edited, [
          for (final op in (out['patch']! as List).cast<Map<String, Object?>>())
            (
              op: PatchOperation.values.byName(op['op']! as String),
              path: op['path']! as String,
              value: op['value'],
            ),
        ]),
      ),
    );
    expect(
      generated.readAsStringSync(),
      contains('button: AcButtonShape.pill'),
    );
    final check = await fliin(project, ['tokens', '--check', '--json']);
    expect(check.code, 0, reason: check.err);
    expect(tokens.listSync().map((e) => p.basename(e.path)).toSet(), {
      tokensJsonName,
      tokensDartName,
    });
  });

  test('devrait prévenir sans échouer quand la marque rouge se confond avec danger, et se taire pour un bleu', () async {
    final red = await fliin(project, [
      'theme',
      '--primary',
      '#B3261E',
      '--json',
    ]);
    expect(red.code, 0, reason: red.err);
    expect(
      (jsonOf(red)['warnings']! as List).cast<String>(),
      contains(allOf(contains('danger and accent'), contains('light'))),
    );

    final blue = await fliin(project, [
      'theme',
      '--primary',
      '#0A6CFF',
      '--json',
    ]);
    expect(blue.code, 0, reason: blue.err);
    expect(jsonOf(blue)['warnings'], isEmpty);
  });

  test('devrait ne rien écrire et sortir un patch qui mène au même fichier quand --dry-run', () async {
    final before = snapshot();
    final dry = await fliin(project, [
      'theme',
      '--primary',
      '#E4572E',
      '--neutral',
      'warm',
      '--dry-run',
      '--json',
    ]);
    expect(dry.code, 0, reason: dry.err);
    expect(snapshot(), before);
    final out = jsonOf(dry);
    expect(out['dryRun'], isTrue);
    expect(out['written'], isFalse);
    final patch = (out['patch']! as List).cast<Map<String, Object?>>();
    expect(patch.map((op) => op['op']).toSet(), {'test', 'replace'});

    final human = await fliin(project, [
      'theme',
      '--primary',
      '#E4572E',
      '--neutral',
      'warm',
      '--dry-run',
    ]);
    expect(human.out, contains('nothing was written'));
    expect(snapshot(), before);

    final real = await fliin(project, [
      'theme',
      '--primary',
      '#E4572E',
      '--neutral',
      'warm',
    ]);
    expect(real.code, 0, reason: real.err);
    expect(
      json.readAsStringSync(),
      tokensJsonText(
        applyJsonPatch(jsonDecode(before[tokensJsonName]!), [
          for (final op in patch)
            (
              op: PatchOperation.values.byName(op['op']! as String),
              path: op['path']! as String,
              value: op['value'],
            ),
        ]),
      ),
    );
    final again = await fliin(project, [
      'theme',
      '--primary',
      '#E4572E',
      '--neutral',
      'warm',
      '--json',
    ]);
    expect(jsonOf(again)['patch'], isEmpty);
    expect(jsonOf(again)['written'], isFalse);
  });

  test('devrait sortir en 1 avec UNSATISFIABLE dans error, la paire, le ratio, le seuil et deux propositions, sans rien écrire (n°4, n°12)', () async {
    final before = snapshot();
    final run = await fliin(project, [
      'theme',
      '--primary',
      '#00FF00',
      '--json',
    ]);
    expect(run.code, 1);
    expect(snapshot(), before);
    final error = jsonOf(run)['error']! as Map<String, Object?>;
    expect(error['code'], 1);
    expect(error['kind'], 'UNSATISFIABLE');
    expect(error['message'], run.err.trim());
    expect((error['failing']! as Map)['foreground'], 'onAccent');
    expect((error['failing']! as Map)['background'], 'accent');
    expect((error['failing']! as Map)['mode'], 'dark');
    expect((error['failing']! as Map)['threshold'], 4.5);
    expect((error['failing']! as Map)['ratio'], lessThan(4.5));
    expect(run.err, contains('floor'));
    final same = (error['sameHue']! as Map)['primary']! as String;
    final nearest = (error['nearestHue']! as Map)['primary']! as String;
    expect(
      run.err.indexOf('--primary "$same"'),
      lessThan(run.err.indexOf('--primary "$nearest"')),
    );
    for (final primary in [same, nearest]) {
      final retry = await fliin(project, [
        'theme',
        '--primary',
        primary,
        '--dry-run',
      ]);
      expect(retry.code, 0, reason: retry.err);
    }
  });

  test('devrait sortir en 1 sans trace ni écriture quand la rampe d’accent est héritée par \$extends (n°3)', () async {
    final edited = jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
    final color = edited['color']! as Map<String, Object?>;
    color['blue'] = color['accent'];
    color['accent'] = {r'$extends': '{color.blue}'};
    // Un pointeur ne suit pas $extends : les teintes visent la rampe écrite.
    json.writeAsStringSync(
      tokensJsonText(edited).replaceAll('#/color/accent/', '#/color/blue/'),
    );
    expect((await fliin(project, ['tokens'])).code, 0);
    final before = snapshot();
    for (final args in [
      ['theme', '--primary', '#E4572E', '--json'],
      ['theme', '--primary', '#E4572E', '--dry-run', '--json'],
    ]) {
      final run = await fliin(project, args);
      expect(run.code, 1, reason: run.err);
      expect(
        (jsonOf(run)['error']! as Map)['message'],
        contains('color.accent.100'),
      );
    }
    expect(snapshot(), before);
  });

  test('devrait lister chaque valeur réécrite avec son avant et son après, et garder l’accent du fichier sans --primary (n°2)', () async {
    final edited = jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
    (((edited['color']! as Map)['accent']! as Map)['600']!
        as Map)[r'$value'] = {
      'colorSpace': 'srgb',
      'components': [0.0627, 0.1843, 0.4392],
      'hex': '#102F70',
    };
    ((edited['color']! as Map)[r'$extensions']!
        as Map)[FliinTokens.contrastExceptionsExtension] = [
      for (final e
          in ((edited['color']! as Map)[r'$extensions']!
                  as Map)[FliinTokens.contrastExceptionsExtension]!
              as List)
        if (!((e as Map)['foreground'] == 'onAccentSoft' &&
            e['appearance'] == 'light'))
          e,
    ];
    json.writeAsStringSync(tokensJsonText(edited));
    final shape = await fliin(project, ['theme', '--button', 'rounded']);
    expect(shape.code, 0, reason: shape.err);
    expect(json.readAsStringSync(), contains('#102F70'));
    expect(
      shape.out,
      contains(
        r'/shape/button/$extensions/dev.fliin.buttonShape/value: "pill" → "rounded"',
      ),
    );
    final brand = await fliin(project, ['theme', '--primary', '#0485F7']);
    expect(brand.code, 0, reason: brand.err);
    expect(
      brand.out,
      contains(r'/color/accent/600/$value: #102F70 → #006DD7'),
    );
  });

  test('devrait supprimer un temporaire orphelin quand theme ou tokens écrivent (n°8)', () async {
    for (final args in [
      ['theme', '--primary', '#0A6CFF'],
      ['tokens'],
    ]) {
      final orphan = File('${generated.path}.fliin-tmp')
        ..writeAsStringSync('// coupé');
      final run = await fliin(project, args);
      expect(run.code, 0, reason: run.err);
      expect(orphan.existsSync(), isFalse, reason: args.first);
    }
  });

  test('devrait sortir en 1 sans rien écrire quand le verrou du projet est tenu, et --dry-run passer quand même (n°10)', () async {
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
    final holder = File(p.join(project.path, 'hold.dart'))
      ..writeAsStringSync("""
import 'dart:io';
void main(List<String> args) {
  File(args.first).parent.createSync(recursive: true);
  File(args.first).openSync(mode: FileMode.append).lockSync(FileLock.exclusive);
  print('verrou');
  stdin.listen(null, onDone: () => exit(0));
}
""");
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      holder.path,
      p.join(project.path, ProjectLock.path),
    ]);
    addTearDown(process.kill);
    await process.stdout
        .transform(utf8.decoder)
        .firstWhere((line) => line.contains('verrou'));
    final before = snapshot();
    final run = await fliin(project, ['theme', '--primary', '#0A6CFF']);
    expect(run.code, 1);
    expect(run.err, contains('Another fliin'));
    expect(snapshot(), before);
    final dry = await fliin(project, [
      'theme',
      '--primary',
      '#0A6CFF',
      '--dry-run',
    ]);
    expect(dry.code, 0, reason: dry.err);
    expect(snapshot(), before);
  });

  test('devrait sortir en 1 sans rien écrire quand le fichier patché ne se génère plus (n°10)', () async {
    final edited = jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
    final accent = (edited['color']! as Map)['accent']! as Map;
    ((accent['200']! as Map)[r'$value']! as Map)['alpha'] = 1.0;
    edited['opacity'] = {
      r'$type': 'number',
      r'$ref': r'#/color/accent/200/$value/alpha',
    };
    json.writeAsStringSync(tokensJsonText(edited));
    expect((await fliin(project, ['tokens'])).code, 0);
    final before = snapshot();
    final run = await fliin(project, [
      'theme',
      '--primary',
      '#0A6CFF',
      '--json',
    ]);
    expect(run.code, 1);
    expect(run.err, contains('Invalid theme'));
    expect(snapshot(), before);
  });

  test('devrait laisser le JSON intact et aucun fichier temporaire quand tokens.g.dart ne peut pas être remplacé', () async {
    generated.deleteSync();
    Directory(generated.path).createSync();
    File(p.join(generated.path, 'occupe')).writeAsStringSync('');
    final before = json.readAsStringSync();
    final run = await fliin(project, [
      'theme',
      '--primary',
      '#0A6CFF',
      '--json',
    ]);
    expect(run.code, 1);
    expect(run.err, contains('Nothing was written'));
    expect(json.readAsStringSync(), before);
    expect(tokens.listSync().map((e) => p.basename(e.path)).toSet(), {
      tokensJsonName,
      tokensDartName,
    });
  });

  test('devrait régénérer seulement tokens.g.dart quand le thème est déjà en place mais le Dart manque', () async {
    final first = await fliin(project, ['theme', '--primary', '#0485F7']);
    expect(first.code, 0, reason: first.err);
    final before = json.readAsStringSync();
    generated.deleteSync();
    final run = await fliin(project, [
      'theme',
      '--primary',
      '#0485F7',
      '--json',
    ]);
    expect(run.code, 0, reason: run.err);
    expect(jsonOf(run)['patch'], isEmpty);
    expect(jsonOf(run)['written'], isTrue);
    expect(json.readAsStringSync(), before);
    expect((await fliin(project, ['tokens', '--check'])).code, 0);
  });

  test('devrait générer la police nommée et prévenir qu’elle se déclare dans le pubspec', () async {
    final run = await fliin(project, [
      'theme',
      '--primary',
      '#0485F7',
      '--font',
      'Inter',
    ]);
    expect(run.code, 0, reason: run.err);
    expect(run.out, contains('pubspec.yaml'));
    expect(generated.readAsStringSync(), contains("fontFamily: 'Inter'"));
  });

  for (final (label, args) in [
    ('une couleur sans #', ['--primary', '0A6CFF']),
    ('un rayon négatif', ['--primary', '#0A6CFF', '--radius', '-1']),
    ('un ton inconnu', ['--primary', '#0A6CFF', '--neutral', 'beige']),
    ('une police vide (n°11)', ['--font', '  ']),
    ('une liste de polices (n°11)', ['--font', 'Inter, Arial']),
    ('une police à caractère de contrôle (n°11)', ['--font', 'In\nter']),
  ]) {
    test(
      'devrait sortir en 64 sans rien écrire quand on passe $label',
      () async {
        final before = snapshot();
        expect((await fliin(project, ['theme', ...args])).code, 64);
        expect(snapshot(), before);
      },
    );
  }

  test('devrait revenir à la police système quand --font system suit une police nommée (n°11)', () async {
    final registry = json.readAsStringSync();
    expect((await fliin(project, ['theme', '--font', 'Inter'])).code, 0);
    expect(generated.readAsStringSync(), contains("fontFamily: 'Inter'"));
    final back = await fliin(project, ['theme', '--font', 'system']);
    expect(back.code, 0, reason: back.err);
    expect(back.out, isNot(contains('pubspec.yaml')));
    expect(json.readAsStringSync(), registry);
    expect(generated.readAsStringSync(), isNot(contains("fontFamily: '")));
  });

  test('devrait rendre un tokens.g.dart conforme en clair et en sombre, ou UNSATISFIABLE dont la paire est sous son seuil, pour des marques extrêmes et 200 au hasard (n°9)', () {
    final source = jsonDecode(
      File(p.join(registryTokens, tokensJsonName)).readAsStringSync(),
    );
    final pairs = FliinTokens.read(
      resolveTokens(TokenDocument.fromJson(source)),
    ).contrastPairs;
    final random = Random(2026);
    final brands = [
      for (final hex in [
        '#FFFFFF',
        '#FEFEFE',
        '#000000',
        '#010101',
        '#808080',
        '#FF0000',
        '#00FF00',
        '#0000FF',
        '#FFFF00',
        '#00FFFF',
        '#FF00FF',
      ])
        for (final tone in [null, ...NeutralTone.values])
          (Rgb8.parse(hex), tone),
      for (var i = 0; i < 200; i++)
        (
          Rgb8(random.nextInt(0x1000000)),
          NeutralTone.values[i % NeutralTone.values.length],
        ),
    ];
    final outcomes = <String>{};
    for (final (brand, tone) in brands) {
      final reason = '${brand.hex} ${tone?.name}';
      switch (solveTheme(
        source,
        ThemeRequest(primary: toOklch(brand), neutral: tone),
      )) {
        case ThemeSolved(:final patch):
          outcomes.add('conforme');
          final dart = renderTokensDart(
            applyJsonPatch(source, patch),
            prefix: 'Fl',
          );
          for (final mode in ['light', 'dark']) {
            final colors = generatedColors(dart, mode);
            for (final pair in pairs) {
              final fg = colors[pair.foreground]!;
              final layers = [
                colors[pair.background]!,
                for (final role in pair.over) colors[role]!,
              ];
              expect(
                [fg >>> 24, layers.last >>> 24],
                [0xFF, 0xFF],
                reason: reason,
              );
              final bg = composite(layers).value;
              expect(
                wcagRatio(fg, bg),
                greaterThanOrEqualTo(
                  pair.kind == ContrastKind.text ? 4.5 : 3.0,
                ),
                reason: '$reason ${pair.foreground}/${pair.background} $mode',
              );
            }
          }
        case Unsatisfiable(:final failing):
          outcomes.add('UNSATISFIABLE');
          expect(failing.ratio, lessThan(failing.threshold), reason: reason);
      }
    }
    expect(outcomes, {'conforme', 'UNSATISFIABLE'});
  });

  group('--preset', () {
    /// Le lockfile d'un projet où `core` a installé [json] tel quel. Son
    /// brut n'est pas gardé dans le projet (`core` est gratuit) : le
    /// préréglage le relit au registre, ici le registre source du dépôt.
    void lockInstalled(File json) {
      final raw = Sha256.ofBytes(json.readAsBytesSync());
      final render = RenderConfig(
        root: 'lib/ui/fliin',
        prefix: 'Ac',
        package: 'app',
      );
      writeLockfile(
        project,
        Lockfile(
          registries: const {},
          config: render,
          dartStyle: dartStyleVersion,
          items: {
            ItemRef('core'): LockedItem(
              version: Version(0, 1, 1),
              registryDependencies: const [],
              files: {
                'lib/ui/fliin/core/tokens/fliin.tokens.json': LockedFile(
                  raw: raw,
                  base: raw,
                  installed: raw,
                ),
              },
            ),
          },
        ),
      );
    }

    test('devrait appliquer le préréglage, imprimer ses champs et ses polices, puis passer tokens --check', () async {
      lockInstalled(json);
      const preset = Preset(
        base: PresetBase.stone,
        primary: PresetPrimary.emerald,
        body: PresetFamily.inter,
        heading: PresetFamily.playfairDisplay,
        radius: PresetRadius.none,
        spacing: PresetSpacing.compact,
        shadow: PresetShadow.none,
        button: ButtonShape.square,
      );
      final run = await fliin(project, ['theme', '--preset', preset.encode()]);
      expect(run.code, 0, reason: run.err);
      expect(run.out, contains('Preset ${preset.encode()}:'));
      expect(run.out, contains('heading  Playfair Display'));
      expect(
        run.out,
        contains('https://fonts.google.com/specimen/Playfair+Display'),
      );
      final tokens = FliinTokens.read(
        resolveTokens(
          TokenDocument.fromJson(jsonDecode(json.readAsStringSync())),
        ),
      );
      expect(tokens.radius.values.toSet(), {0});
      expect(tokens.button, ButtonShape.square);
      expect(tokens.headingFamily['ios'], 'Playfair Display');
      expect(tokens.contrastExceptions, isEmpty);
      expect(
        generated.readAsStringSync(),
        contains("headingFamily: 'Playfair Display'"),
      );
      expect((await fliin(project, ['tokens', '--check'])).code, 0);
    });

    test('devrait redonner le fichier livré quand on revient à c0000000000000 après un autre préréglage', () async {
      final original = json.readAsStringSync();
      lockInstalled(json);
      expect(
        (await fliin(project, ['theme', '--preset', 'c0BgrCt0000000'])).code,
        0,
      );
      expect(json.readAsStringSync(), isNot(original));
      final back = await fliin(project, [
        'theme',
        '--preset',
        'c0000000000000',
        '--json',
      ]);
      expect(back.code, 0, reason: back.err);
      expect(json.readAsStringSync(), original);
      expect((jsonOf(back)['preset']! as Map)['code'], 'c0000000000000');
    });

    test('devrait sortir en 64 sans rien écrire sur un code refusé ou un autre réglage à côté', () async {
      lockInstalled(json);
      final before = snapshot();
      for (final (args, message) in [
        (['--preset', 'c00'], '14 characters'),
        (['--preset', 'd0000000000000'], 'Update fliin'),
        (['--preset', 'c00000F0000000'], 'base: unknown value 15'),
        (['--preset', 'c0000000000000', '--radius', '4'], 'Remove --radius'),
      ]) {
        final run = await fliin(project, ['theme', ...args]);
        expect(run.code, 64, reason: '$args');
        expect(run.err, contains(message), reason: '$args');
      }
      expect(snapshot(), before);
    });

    test('devrait noter le préréglage dans fliin.yaml et imprimer un bloc pubspec avec ses graisses (M4, B5)', () async {
      lockInstalled(json);
      const preset = Preset(heading: PresetFamily.playfairDisplay);
      final run = await fliin(project, ['theme', '--preset', preset.encode()]);
      expect(run.code, 0, reason: run.err);
      expect(readFliinConfig(project)!.preset, preset);
      expect(
        run.out,
        contains('    - family: Playfair Display\n      fonts:\n'),
      );
      for (final weight in [400, 500, 600, 700]) {
        expect(run.out, contains('weight: $weight'));
      }
      final dry = await fliin(project, [
        'theme',
        '--preset',
        'c0000000000000',
        '--dry-run',
      ]);
      expect(dry.code, 0, reason: dry.err);
      expect(readFliinConfig(project)!.preset, preset);
    });

    test('devrait lister à part chaque retouche à la main qu’un préréglage écrase, et taire ce qu’un préréglage précédent avait dérivé (M5)', () async {
      lockInstalled(json);
      json.writeAsStringSync(
        json.readAsStringSync().replaceFirstMapped(
          RegExp(r'("md": \{\s*"\$value": \{\s*"value": )12'),
          (match) => '${match[1]}13',
        ),
      );
      final first = await fliin(project, [
        'theme',
        '--preset',
        'c0BgrCt0000000',
        '--json',
      ]);
      expect(first.code, 0, reason: first.err);
      expect(jsonOf(first)['overwritten'], [
        {'path': '/space/md/\$value/value', 'before': 13, 'after': 9},
      ]);
      expect(
        (jsonOf(first)['warnings']! as List).cast<String>(),
        contains(
          startsWith(
            'manual edit overwritten: /space/md/\$value/value (13 → 9)',
          ),
        ),
      );
      final second = await fliin(project, [
        'theme',
        '--preset',
        'c05ONTp0000000',
        '--json',
      ]);
      expect(second.code, 0, reason: second.err);
      expect(jsonOf(second)['overwritten'], isEmpty);
    });

    test('devrait dire écrasées les retouches de size.border et d’une hauteur de ligne, et garder une graisse retouchée, quand un code les possède', () async {
      lockInstalled(json);
      final edited =
          jsonDecode(json.readAsStringSync()) as Map<String, Object?>;
      Map<String, Object?> at(List<String> path) =>
          path.fold(edited, (node, key) => node[key]! as Map<String, Object?>);
      at(['size', 'border'])[r'$value'] = {'value': 3, 'unit': 'px'};
      final body = at(['typography', 'scale', 'ios', 'body']);
      (body['lineHeight']! as Map<String, Object?>)[r'$value'] = {
        'value': 30,
        'unit': 'px',
      };
      (body['weight']! as Map<String, Object?>)[r'$value'] = 600;
      json.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(edited),
      );
      const preset = Preset(
        border: PresetBorder.medium,
        text: PresetTextSize.large,
      );
      final run = await fliin(project, [
        'theme',
        '--preset',
        preset.encode(),
        '--json',
      ]);
      expect(run.code, 0, reason: run.err);
      expect(
        jsonOf(run)['overwritten'],
        unorderedEquals([
          {'path': '/size/border/\$value/value', 'before': 3, 'after': 1.5},
          {
            'path': '/typography/scale/ios/body/lineHeight/\$value/value',
            'before': 30,
            'after': 26,
          },
        ]),
      );
      final result = jsonDecode(json.readAsStringSync());
      expect(valueAt(result, '/typography/scale/ios/body/weight/\$value'), 600);
    });

    test('devrait sortir en 3 en disant de se connecter une fois quand le registre est injoignable, sans rien écrire (B4)', () async {
      lockInstalled(json);
      final before = snapshot();
      final run = await fliin(project, [
        'theme',
        '--preset',
        'c0BgrCt0000000',
      ], registry: const _Offline());
      expect(run.code, 3);
      expect(run.err, contains('tokens shipped with core 0.1.1'));
      expect(run.err, contains('once you are online'));
      expect(snapshot(), before);
    });

    test('devrait sortir en 1 sans rien écrire quand les jetons ne sont pas dans le lockfile', () async {
      final before = snapshot();
      final run = await fliin(project, ['theme', '--preset', 'c0BgrCt0000000']);
      expect(run.code, 1);
      expect(run.err, contains('Run fliin init'));
      expect(snapshot(), before);
    });
  });

  test('devrait sortir en 3 quand le projet n’est pas initialisé', () async {
    File(p.join(project.path, fliinYamlName)).deleteSync();
    expect((await fliin(project, ['theme', '--primary', '#0A6CFF'])).code, 3);
  });
}

/// Un registre qu'aucune requête n'atteint.
final class _Offline implements Registry {
  @override
  bool get servesPro => true;

  const _Offline();

  Never _down() => throw const RegistryUnreachable('hors ligne');

  @override
  Future<IndexPointer> fetchPointer() async => _down();

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) async => _down();

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) async =>
      _down();

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) async => _down();
}

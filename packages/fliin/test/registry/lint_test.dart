import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/lint.dart';
import 'package:fliin/src/registry/public_api.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('devrait nommer chaque symbole public sans ///, et exempter le privé, les redéfinitions et le mutateur d’un accesseur', () {
    const source = '''
/// Documentée.
class Documented {
  /// Documenté.
  Documented(this.value);

  Documented.named() : value = 0;

  final int value;

  int get size => 0;

  set size(int value) {}

  @override
  String toString() => '';

  void _hidden() {}
}

enum Mode { on, off }

/// Abstraite : son constructeur ne s'appelle pas.
abstract class Shape {
  const Shape();
}

class _Private {
  void open() {}
}

int count = 0;

typedef Callback = void Function();

void run() {}
''';
    expect(undocumentedSymbols(source), [
      'Documented.named',
      'Documented.value',
      'Documented.size',
      'Mode',
      'Mode.on',
      'Mode.off',
      'count',
      'Callback',
      'run',
    ]);
  });

  test('ne devrait pas demander de doc au constructeur d’un enum, qu’aucun appelant n’appelle', () {
    expect(
      undocumentedSymbols('''
/// Un mode.
enum Mode {
  /// Lent.
  slow(1);

  const Mode(this.speed);

  /// La vitesse.
  final int speed;
}
'''),
      isEmpty,
    );
  });

  test('ne devrait trouver aucun symbole public sans doc dans les fichiers publiés du registre', () {
    final missing = {
      for (final file in Directory(
        p.join(sourceRoot, 'lib'),
      ).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          p.relative(file.path, from: sourceRoot): undocumentedSymbols(
            file.readAsStringSync(),
          ),
    }..removeWhere((_, symbols) => symbols.isEmpty);
    expect(missing, isEmpty);
  });

  group('fliin registry build', () {
    late String key;

    setUpAll(() async {
      key = p.join(tempDir().path, 'fliin-signing.key');
      final keygen = await fliin(['registry', 'keygen', '--out', key]);
      expect(keygen.exitCode, 0, reason: '${keygen.stderr}');
    });

    Future<ProcessResult> build(String source, String out) => fliin([
      'registry',
      'build',
      '--source',
      source,
      '--out',
      out,
      '--key',
      key,
    ]);

    test('devrait refuser de publier, sans rien écrire, un élément aux métadonnées hors des règles (DESIGN §6.5)', () async {
      final source = copiedSource();
      final manifest = File(p.join(source, 'items', 'switch.json'));
      final json =
          jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>
            ..['title'] = 'Modern switch';
      manifest.writeAsStringSync(jsonEncode(json));
      final out = p.join(tempDir().path, 'dist');
      final run = await build(source, out);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      expect(
        '${run.stderr}',
        allOf(
          contains('switch: title: "modern" is a marketing adjective'),
          contains('Publishing refused: 1 writing rule violation'),
        ),
      );
      expect(Directory(out).existsSync(), isFalse);
    });

    test('devrait accepter un notFor vers un élément nommé dans external_items.txt quand la source ne l’a pas, et le refuser sans', () async {
      final source = copiedSource();
      final manifest = File(p.join(source, 'items', 'switch.json'));
      final json =
          jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
      final meta = json['meta']! as Map<String, Object?>;
      final fr = meta['fr']! as Map<String, Object?>;
      meta['notFor'] = [
        ...(meta['notFor']! as List<Object?>),
        'a row of settings with a title: use a settings section (elsewhere-item)',
      ];
      fr['notFor'] = [
        ...(fr['notFor']! as List<Object?>),
        'une suite de réglages titrée : utiliser une section de réglages (elsewhere-item)',
      ];
      manifest.writeAsStringSync(jsonEncode(json));
      final external = File(p.join(source, externalItemsFile));

      final refused = await build(source, p.join(tempDir().path, 'dist'));
      expect(refused.exitCode, 1, reason: '${refused.stderr}');
      expect('${refused.stderr}', contains('elsewhere-item does not exist'));

      external.writeAsStringSync('elsewhere-item\n', mode: FileMode.append);
      final out = p.join(tempDir().path, 'dist');
      final run = await build(source, out);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect(
        Directory(p.join(out, 'items', 'fliin', 'elsewhere-item')).existsSync(),
        isFalse,
      );
    });

    test('devrait refuser de publier un fichier dont un symbole public n’a pas de doc', () async {
      final source = copiedSource();
      File(p.join(source, 'lib', 'components', 'switch', 'fl_switch.dart'))
          .writeAsStringSync(
            '\nint flSwitchRevision() => 2;\n',
            mode: FileMode.append,
          );
      final out = p.join(tempDir().path, 'dist');
      final run = await build(source, out);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      expect(
        '${run.stderr}',
        contains(
          'switch: components/switch/fl_switch.dart: flSwitchRevision has no /// comment',
        ),
      );
      expect(Directory(out).existsSync(), isFalse);
    });

    test('devrait refuser de publier un fichier Pro qui ne commence pas par la ligne de la licence Pro (ADR 0020 §5)', skip: withoutPro, () async {
      final source = copiedSource();
      final screen = File(p.join(source, 'lib', 'screens', 'account_settings', 'account_settings_screen.dart'));
      screen.writeAsStringSync(screen.readAsStringSync().replaceFirst('$proLicenseLine\n', ''));
      final out = p.join(tempDir().path, 'dist');
      final run = await build(source, out);
      expect(run.exitCode, 1, reason: '${run.stderr}');
      expect(
        '${run.stderr}',
        contains('account-settings: screens/account_settings/account_settings_screen.dart: a Pro file must start with the line'),
      );
      expect(Directory(out).existsSync(), isFalse);
    });

    test('devrait trouver la ligne de la licence Pro en tête de chaque fichier Dart Pro de la source, et dans aucun fichier gratuit', () {
      final registry = SourceRegistry.read(sourceRoot);
      for (final manifest in registry.manifests) {
        for (final file in manifest.files) {
          final text = utf8.decode(registry.blobs[file.sha256]!);
          expect(text.startsWith('$proLicenseLine\n'), manifest.meta.tier == Tier.pro, reason: file.path);
        }
      }
    });

    test('devrait publier en signalant une intention proche de celle d’un autre élément', () async {
      final source = copiedSource();
      final manifest = File(p.join(source, 'items', 'checkbox.json'));
      final json =
          jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
      final intents =
          (json['meta']! as Map<String, Object?>)['intents']!
              as Map<String, Object?>;
      intents['en'] = [
        ...(intents['en']! as List<Object?>),
        'toggle notifications on',
      ];
      manifest.writeAsStringSync(jsonEncode(json));
      final out = p.join(tempDir().path, 'dist');
      final run = await build(source, out);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      expect('${run.stderr}', contains('warning, intentOverlap'));
      expect(File(p.join(out, 'latest.json')).existsSync(), isTrue);
    });
  });
}

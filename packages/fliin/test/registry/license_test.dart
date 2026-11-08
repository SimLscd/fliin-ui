import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// `core` installe `lib/ui/fliin/LICENSE` (ADR 0020 §5) : les copies portent
/// l'avis que la MIT demande, et chaque licence de tiers dont dérive un
/// fichier copié, en entier.
void main() {
  final repository = p.normalize(p.join(sourceRoot, '..', '..'));
  String read(String path) => File(p.join(repository, path)).readAsStringSync();

  test('devrait installer le LICENSE à la racine des éléments, avec core', () {
    final core = SourceRegistry.read(sourceRoot).manifests.singleWhere((m) => m.name == 'core');
    final license = core.files.singleWhere((f) => f.path == 'LICENSE');
    expect('${license.target}', '@root/LICENSE');
  });

  test('devrait porter le MIT de Fliin et le texte entier de chaque licence de tiers, tels que le dépôt les donne', () {
    final installed = File(p.join(sourceRoot, 'lib', 'LICENSE')).readAsStringSync();
    final mit = read('LICENSE').split('\n\nThe blocks and screens marked').first;
    for (final (name, text) in [
      ('LICENSE', mit),
      for (final file in ['MIT-heroui.txt', 'MIT-gravity-ui.txt', 'Apache-2.0.txt'])
        (file, read(p.join('LICENSES', file)).trimRight()),
    ]) {
      expect(installed, contains(text), reason: name);
    }
    expect(installed, contains('https://fliin.dev/pro/license'));
    expect(installed, isNot(matches(RegExp(r'\bFl[A-Z]'))), reason: 'la réécriture du préfixe le changerait');
  });

  test('devrait nommer dans le LICENSE chaque origine que portent les en-têtes des fichiers copiés', () {
    final installed = File(p.join(sourceRoot, 'lib', 'LICENSE')).readAsStringSync();
    final headers = [
      for (final file in Directory(p.join(sourceRoot, 'lib')).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart')) file.readAsLinesSync().take(6).join('\n'),
    ];
    for (final (origin, notice) in [
      ('HeroUI Native', 'HeroUI Native\nCopyright 2025 NextUI Inc.'),
      ('HeroUI React v3', 'HeroUI React v3\nCopyright 2025 NextUI Inc.'),
      ('Gravity UI Icons', 'Gravity UI Icons\nCopyright (c) 2022 YANDEX LLC'),
    ]) {
      expect(headers.any((h) => h.contains(origin)), isTrue, reason: origin);
      expect(installed, contains(notice), reason: origin);
    }
    expect(
      [for (final h in headers) if (h.contains('of HeroUI v3')) h],
      isEmpty,
      reason: 'HeroUI React v3, le nom de NOTICE',
    );
  });

}

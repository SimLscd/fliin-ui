import 'dart:io';

import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/project/pubspec.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('devrait inscrire la version de dart_style que le workspace résout (règle 3)', () {
    final resolved = switch (readYaml(File('../../pubspec.lock'))) {
      {'packages': {'dart_style': {'version': final String version}}} =>
        Version.parse(version),
      _ => fail('dart_style absent de pubspec.lock'),
    };
    expect(dartStyleVersion, resolved);
  });

  test('devrait rendre le même texte quand la source est déjà normalisée', () {
    const source = 'class A {\n  final int x = 1;\n}\n';
    expect(normalize(source), source);
    expect(normalize('class A {\r\n  final int x = 1;\r\n}\r\n'), source);
  });

  test('devrait replier à 80 colonnes quand la source est plus large', () {
    final wide = 'final list = [${List.filled(12, "'abcdef'").join(', ')}];\n';
    final lines = normalize(wide).split('\n');
    expect(lines.length, greaterThan(1));
    expect(lines.every((line) => line.length <= 80), isTrue);
  });
}

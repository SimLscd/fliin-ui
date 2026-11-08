import 'dart:convert';

import 'package:test/test.dart';

import 'manifest_edit.dart';

void main() {
  const bare =
      '{\n  "name": "button",\n  "version": "0.1.1",\n  "l10n": {},\n  "files": []\n}\n';
  const logged =
      '{\n  "name": "button",\n  "version": "0.1.1",\n  "l10n": {},\n  "files": [],\n'
      '  "changelog": "Avant : \\"ancien\\" texte."\n}\n';

  Map<String, Object?> decoded(String text) =>
      jsonDecode(text) as Map<String, Object?>;

  test(
    'devrait ajouter le changelog après l10n quand le manifeste n’en a pas',
    () {
      expect(decoded(withChangelog(bare, 'Nouveau.'))['changelog'], 'Nouveau.');
    },
  );

  test('devrait remplacer le changelog existant, sans clé en double, quand le manifeste en a un', () {
    final text = withChangelog(logged, 'Nouveau.');
    expect(decoded(text)['changelog'], 'Nouveau.');
    expect(RegExp('"changelog"').allMatches(text), hasLength(1));
    expect(text, isNot(contains('ancien')));
  });

  test(
    'devrait garder un changelog vide tel quel, pour que le lint le refuse',
    () {
      expect(decoded(withChangelog(logged, ' '))['changelog'], ' ');
    },
  );

  test('devrait changer la version quelle qu’elle soit', () {
    expect(decoded(withVersion(bare, '0.2.0'))['version'], '0.2.0');
  });
}

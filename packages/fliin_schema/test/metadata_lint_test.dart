import 'package:fliin_schema/fliin_schema.dart';
import 'package:test/test.dart';

/// Un manifeste qui passe toutes les règles de DESIGN.md §6.5.
Map<String, Object?> _valid({String name = 'switch'}) => {
  'name': name,
  'type': 'registry:component',
  'version': '0.1.0',
  'title': 'Switch',
  'description':
      'Turns a setting on or off with one tap. Spring-animated switch.',
  'flutter': '>=3.47.0 <4.0.0',
  'files': [
    {
      'path': 'components/$name/fl_$name.dart',
      'type': 'registry:component',
      'target': '@components/$name/fl_$name.dart',
      'sha256': Sha256.ofString(name).value,
    },
  ],
  'categories': ['forms', 'settings'],
  'verify': {
    'entry': '{prefix}Switch()',
    'imports': ['@core/fliin.dart'],
    'states': ['on', 'off'],
    'goldens': {
      'host': 'macos',
      'rendering': {
        'abi': 'macos-arm64',
        'flutter': '3.47.7',
        'fonts': <String, String>{},
      },
      'variants': {for (final id in variantIds) id: Sha256.ofString(id).value},
    },
  },
  'meta': {
    'tier': 'free',
    'platforms': ['ios', 'android'],
    'states': ['on', 'off'],
    'intents': {
      'fr': [
        'activer ou désactiver un réglage',
        'basculer les notifications',
        'ajouter un interrupteur dans des réglages',
        'couper le wifi',
        's’inscrire à la lettre d’information',
      ],
      'en': [
        'turn a setting on or off',
        'toggle notifications',
        'add an on/off switch to settings',
        'enable a feature',
        'switch airplane mode on',
      ],
    },
    'notFor': ['a single choice among several: use radio buttons (radio)'],
    'fr': {
      'title': 'Interrupteur',
      'description': 'Permet d’activer ou de désactiver un réglage.',
      'notFor': [
        'un seul choix parmi plusieurs : utiliser des boutons radio (radio)',
      ],
    },
  },
  'changelog': 'First version.',
};

Map<String, Object?> _meta(Map<String, Object?> json) =>
    json['meta']! as Map<String, Object?>;

Map<String, List<String>> _intents(Map<String, Object?> json) =>
    (_meta(json)['intents']! as Map<String, Object?>).map(
      (lang, list) => MapEntry(lang, (list! as List<Object?>).cast<String>()),
    );

List<LintFinding> _lint(List<Map<String, Object?>> manifests) => lintMetadata(
  [for (final json in manifests) ItemManifest.fromJson(json)],
  known: {'radio'},
);

Set<LintRule> _rules(Map<String, Object?> json) => {
  for (final finding in _lint([json])) finding.rule,
};

void main() {
  test('ne devrait rien signaler quand le manifeste suit chaque règle', () {
    expect(_lint([_valid()]), isEmpty);
  });

  final cases = <(String, LintRule, void Function(Map<String, Object?>))>[
    (
      'un titre de plus de 40 caractères',
      LintRule.titleLength,
      (j) => j['title'] = 'On and off switch for the settings screen',
    ),
    (
      'un titre avec un adjectif marketing',
      LintRule.titleMarketing,
      (j) => j['title'] = 'Modern switch',
    ),
    (
      'une description de plus de 200 caractères',
      LintRule.descriptionLength,
      (j) => j['description'] = 'Turns ${'a setting on ' * 20}.',
    ),
    (
      'une description qui ne commence pas par un verbe d’action',
      LintRule.descriptionVerb,
      (j) => j['description'] = 'A switch that enables a setting.',
    ),
    (
      'moins de 5 intentions dans une langue',
      LintRule.intentCount,
      (j) {
        _meta(j)['intents'] = {
          ..._intents(j),
          'en': _intents(j)['en']!.take(4).toList(),
        };
      },
    ),
    (
      'plus de 12 intentions dans une langue',
      LintRule.intentCount,
      (j) {
        _meta(j)['intents'] = {
          ..._intents(j),
          'fr': [
            'activer un réglage',
            'basculer le son',
            'couper le wifi',
            'allumer la lampe',
            'désactiver le bluetooth',
            'choisir un thème sombre',
            'masquer les aperçus',
            'montrer les badges',
            'régler la luminosité auto',
            'bloquer les appels inconnus',
            'partager sa position',
            'suivre les mises à jour',
            'trier les messages lus',
          ],
        };
      },
    ),
    (
      'une intention qui ne commence pas par un verbe',
      LintRule.intentVerb,
      (j) {
        _meta(j)['intents'] = {
          ..._intents(j),
          'fr': [
            ..._intents(j)['fr']!.skip(1),
            'interrupteur des notifications',
          ],
        };
      },
    ),
    (
      'deux intentions trop proches',
      LintRule.intentSimilar,
      (j) {
        _meta(j)['intents'] = {
          ..._intents(j),
          'en': [..._intents(j)['en']!, 'toggle the notifications'],
        };
      },
    ),
    (
      'un notFor qui ne renvoie à rien',
      LintRule.notForTarget,
      (j) => _meta(j)
        ..['notFor'] = ['a link: use a link']
        ..remove('fr'),
    ),
    (
      'un notFor qui renvoie à un élément inexistant',
      LintRule.notForTarget,
      (j) => _meta(j)
        ..['notFor'] = ['a card: use a card (card)']
        ..remove('fr'),
    ),
    (
      'des notFor français qui ne suivent pas les anglais',
      LintRule.frenchMismatch,
      (j) => (_meta(j)['fr']! as Map<String, Object?>)['notFor'] = [
        'un réglage : utiliser une case à cocher (checkbox)',
      ],
    ),
    (
      'une catégorie hors de la taxonomie',
      LintRule.categoryUnknown,
      (j) => j['categories'] = ['widgets'],
    ),
    ('aucune catégorie', LintRule.categoryCount, (j) => j['categories'] = []),
    (
      'quatre catégories',
      LintRule.categoryCount,
      (j) => j['categories'] = ['forms', 'settings', 'actions', 'lists'],
    ),
    (
      'un état que verify ne rend pas',
      LintRule.stateWithoutGolden,
      (j) => _meta(j)['states'] = ['on', 'off', 'pressed'],
    ),
    (
      'des états sans golden de référence',
      LintRule.stateWithoutGolden,
      (j) => (j['verify']! as Map<String, Object?>).remove('goldens'),
    ),
    (
      'un adjectif marketing en capitales',
      LintRule.titleMarketing,
      (j) => j['title'] = 'Sleek Switch',
    ),
    (
      'une description qui commence par un nom qui est aussi un verbe',
      LintRule.descriptionVerb,
      (j) => j['description'] = 'Controls for a setting, spring-animated.',
    ),
    (
      'un titre en français',
      LintRule.notEnglish,
      (j) => j['title'] = 'Interrupteur des réglages',
    ),
    (
      'une description en français',
      LintRule.notEnglish,
      (j) => j['description'] = 'Turns un réglage on avec un toucher.',
    ),
    (
      'un notFor en français',
      LintRule.notEnglish,
      (j) => _meta(j)['notFor'] = [
        'un seul choix parmi plusieurs : utiliser des boutons radio (radio)',
      ],
    ),
    (
      'un changelog en français',
      LintRule.notEnglish,
      (j) => j['changelog'] = 'Première version, avec la taille sm.',
    ),
    (
      'une cassure décrite en français',
      LintRule.notEnglish,
      (j) => j['breaking'] = [
        {'kind': 'semantic', 'description': 'Le pouce ne rebondit plus.'},
      ],
    ),
    (
      'une intention anglaise qui commence par un nom ambigu',
      LintRule.intentVerb,
      (j) {
        _meta(j)['intents'] = {
          ..._intents(j),
          'en': [..._intents(j)['en']!.skip(1), 'list items in settings'],
        };
      },
    ),
    (
      'une catégorie en double',
      LintRule.categoryDuplicate,
      (j) => j['categories'] = ['forms', 'forms'],
    ),
    (
      'un notFor qui renvoie à lui-même',
      LintRule.notForTarget,
      (j) => _meta(j)
        ..['notFor'] = ['a setting: use a switch (switch)']
        ..remove('fr'),
    ),
  ];
  for (final (label, rule, mutate) in cases) {
    test('devrait refuser ${rule.name} quand le manifeste a $label', () {
      final json = _valid();
      mutate(json);
      expect(_rules(json), {rule});
      expect(rule.blocking, isTrue);
    });
  }

  test('devrait signaler sans bloquer une intention proche de celle d’un autre élément', () {
    final other = _valid(name: 'toggle');
    _meta(other)['intents'] = {
      ..._intents(other),
      'en': [
        'toggle notification',
        'turn a light on',
        'add a power button',
        'enable dark mode',
        'switch sound off',
      ],
    };
    final findings = _lint([_valid(), other]);
    expect(findings.map((f) => f.rule), contains(LintRule.intentOverlap));
    expect(findings.where((f) => f.rule.blocking), isEmpty);
  });

  test('devrait mesurer la similarité comme pg_trgm', () {
    expect(trigramSimilarity('word', 'word'), 1);
    expect(trigramSimilarity('word', 'two words'), closeTo(4 / 11, 1e-9));
    expect(trigramSimilarity('chat', 'lune'), 0);
  });
}

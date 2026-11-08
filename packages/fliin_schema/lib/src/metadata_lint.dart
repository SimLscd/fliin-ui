import 'breaking.dart';
import 'manifest.dart';

/// La taxonomie fermée des catégories (DESIGN.md §6.5), complétée par celles
/// des éléments de `core/` et des composants : `foundation` pour `core`,
/// `actions` pour les boutons, `lists` pour les lignes et les listes.
const categoryTaxonomy = {
  'auth',
  'onboarding',
  'account',
  'settings',
  'commerce',
  'search',
  'messaging',
  'dashboard',
  'feedback',
  'navigation',
  'forms',
  'data-display',
  'overlays',
  'actions',
  'lists',
  'foundation',
};

/// Interdits dans un titre (DESIGN.md §6.5) : ils ne disent pas ce qu'est
/// l'élément.
const marketingAdjectives = {
  'amazing',
  'awesome',
  'beautiful',
  'best',
  'brilliant',
  'cool',
  'elegant',
  'fancy',
  'gorgeous',
  'incredible',
  'innovative',
  'intuitive',
  'magnificent',
  'modern',
  'nice',
  'perfect',
  'powerful',
  'premium',
  'pretty',
  'sleek',
  'slick',
  'stunning',
  'sublime',
  'superb',
  'ultimate',
};

/// Les verbes par lesquels une intention commence, à l'infinitif français ou
/// à la base anglaise. La règle est une liste, pas une analyse : un verbe
/// absent est refusé tant qu'on ne l'ajoute pas ici. Un infinitif français
/// n'est presque jamais un nom ; en anglais, la liste écarte les mots dont la
/// lecture comme nom domine en tête d'une phrase d'interface (`list`,
/// `label`, `group`, `type`, `set`, `search`, `filter`, `sort`, `check`,
/// `mark`, `display`, `call`, `tick`, `trap`, `block`, `wait`) et garde ceux
/// qu'on lit comme un impératif en tête d'intention (`toggle`, `switch`,
/// `share`, `show`, `use`, `turn`, `drag`, `open`, `close`), au prix d'un
/// faux positif possible (ADR 0011).
const intentVerbs = {
  IntentLang.fr: {
    'accepter',
    'activer',
    'adapter',
    'afficher',
    'ajouter',
    'ajuster',
    'allumer',
    'annuler',
    'appliquer',
    'basculer',
    'bloquer',
    'changer',
    'choisir',
    'cocher',
    'confirmer',
    'connecter',
    'copier',
    'couper',
    'créer',
    'décrire',
    'demander',
    'désactiver',
    'donner',
    'éditer',
    'entrer',
    'envoyer',
    'expliquer',
    'faire',
    'fermer',
    'filtrer',
    'garantir',
    'grouper',
    'indiquer',
    'inscrire',
    'lancer',
    'lire',
    'lister',
    'marquer',
    'masquer',
    'modifier',
    'montrer',
    'naviguer',
    'nommer',
    'ouvrir',
    'partager',
    'passer',
    'patienter',
    'piéger',
    'poser',
    'présenter',
    'proposer',
    'ranger',
    'rechercher',
    'régler',
    'remplir',
    'respecter',
    'saisir',
    'sélectionner',
    'séparer',
    'signaler',
    'soumettre',
    'suivre',
    'supprimer',
    'téléverser',
    'trier',
    'valider',
  },
  IntentLang.en: {
    'accept',
    'add',
    'adjust',
    'apply',
    'ask',
    'cancel',
    'change',
    'choose',
    'close',
    'collect',
    'confirm',
    'create',
    'delete',
    'describe',
    'disable',
    'drag',
    'edit',
    'enable',
    'ensure',
    'enter',
    'explain',
    'give',
    'hide',
    'keep',
    'let',
    'make',
    'move',
    'mute',
    'navigate',
    'offer',
    'open',
    'opt',
    'pick',
    'present',
    'reach',
    'remove',
    'respect',
    'reuse',
    'select',
    'send',
    'separate',
    'share',
    'show',
    'split',
    'submit',
    'switch',
    'toggle',
    'turn',
    'upload',
    'use',
  },
};

/// Le premier mot d'une description : un verbe d'action au présent, à la
/// troisième personne, qui dit ce que l'utilisateur final fait de l'élément.
/// En anglais, presque chacune de ces formes est aussi un nom au pluriel
/// (`lists`, `groups`, `marks`) : la liste ne garde que les verbes qu'on lit
/// comme tels en tête d'une phrase de catalogue. Même limite que
/// [intentVerbs].
const descriptionVerbs = {
  'asks',
  'books',
  'closes',
  'confirms',
  'explains',
  'fades',
  'flags',
  'frames',
  'gathers',
  'gives',
  'groups',
  'holds',
  'introduces',
  'joins',
  'keeps',
  'lets',
  'lists',
  'marks',
  'moves',
  'names',
  'offers',
  'opens',
  'picks',
  'plays',
  'plots',
  'presents',
  'puts',
  'reports',
  'says',
  'searches',
  'sets',
  'shows',
  'suggests',
  'switches',
  'takes',
  'tells',
  'ticks',
  'triggers',
  'turns',
  'types',
};

/// Des mots outils français qui ne sont pas des mots anglais : le titre, la
/// description, les `notFor`, le changelog et les cassures se lisent dans
/// `fliin view`, `search`, `update` et le MCP, en anglais. Seules les
/// intentions gardent leur français, pour la recherche.
const frenchWords = {
  'aux',
  'avec',
  'dans',
  'des',
  'du',
  'et',
  'la',
  'le',
  'les',
  'ne',
  'ou',
  'pas',
  'qui',
  'sur',
  'une',
  'utiliser',
  'vos',
  'votre',
};

enum IntentLang { fr, en }

enum LintRule {
  titleLength,
  titleMarketing,
  descriptionLength,
  descriptionVerb,
  notEnglish,
  intentCount,
  intentVerb,
  intentSimilar,
  intentOverlap,
  notForTarget,
  frenchMismatch,
  categoryUnknown,
  categoryCount,
  categoryDuplicate,
  stateWithoutGolden,
  undocumentedSymbol,

  /// Un fichier d'élément Pro sans la ligne de la licence Pro en tête
  /// (ADR 0020 §5).
  proLicenseHeader;

  /// Le chevauchement avec un autre élément est signalé, jamais bloquant
  /// (DESIGN.md §6.5).
  bool get blocking => this != intentOverlap;
}

final class LintFinding {
  const LintFinding(this.item, this.rule, this.message);

  final String item;
  final LintRule rule;
  final String message;

  @override
  String toString() =>
      '$item: $message (${rule.blocking ? '' : 'warning, '}${rule.name})';
}

const maxTitle = 40;
const maxDescription = 200;
const minIntents = 5;
const maxIntents = 12;

/// Au-delà, deux intentions disent la même chose (DESIGN.md §6.5).
const maxIntentSimilarity = 0.8;

/// Les règles de DESIGN.md §6.5 sur [manifests], sauf la doc de l'API
/// publique, qui exige de lire le Dart. [known] : les éléments vers lesquels
/// un `notFor` peut renvoyer, en plus de [manifests].
List<LintFinding> lintMetadata(
  List<ItemManifest> manifests, {
  Set<String> known = const {},
}) {
  final names = {...known, for (final m in manifests) m.name};
  final findings = <LintFinding>[];
  for (final m in manifests) {
    void add(LintRule rule, String message) =>
        findings.add(LintFinding(m.name, rule, message));

    if (m.title.length > maxTitle) {
      add(
        LintRule.titleLength,
        'title has ${m.title.length} characters, at most $maxTitle',
      );
    }
    for (final word in _words(m.title)) {
      if (marketingAdjectives.contains(word)) {
        add(LintRule.titleMarketing, 'title: "$word" is a marketing adjective');
      }
    }
    if (m.description.length > maxDescription) {
      add(
        LintRule.descriptionLength,
        'description has ${m.description.length} characters, at most $maxDescription',
      );
    }
    final first = _words(m.description).firstOrNull;
    if (!descriptionVerbs.contains(first)) {
      add(
        LintRule.descriptionVerb,
        'description: start with an action verb from the list '
        '(Shows, Lets, Opens, Picks…), not "$first"',
      );
    }
    for (final (field, text) in [
      ('title', m.title),
      ('description', m.description),
      for (final notFor in m.meta.notFor) ('notFor', notFor),
      if (m.changelog case final changelog?) ('changelog', changelog),
      for (final change in m.breaking)
        if (change case SemanticBreak(:final description))
          ('breaking', description),
    ]) {
      if (_words(text).where(frenchWords.contains).firstOrNull
          case final word?) {
        add(
          LintRule.notEnglish,
          '$field: "$word" is French. Write it in English',
        );
      }
    }
    for (final (lang, intents) in [
      (IntentLang.fr, m.meta.intents.fr),
      (IntentLang.en, m.meta.intents.en),
    ]) {
      if (intents.length < minIntents || intents.length > maxIntents) {
        add(
          LintRule.intentCount,
          '${intents.length} ${lang.name} intents, expected $minIntents to $maxIntents',
        );
      }
      for (final intent in intents) {
        final verb = _leadingVerb(intent, lang);
        if (!intentVerbs[lang]!.contains(verb)) {
          add(
            LintRule.intentVerb,
            '${lang.name} intent "$intent": "$verb" is not a verb from '
            'the list',
          );
        }
      }
      for (final (i, a) in intents.indexed) {
        for (final b in intents.skip(i + 1)) {
          final similarity = trigramSimilarity(a, b);
          if (similarity >= maxIntentSimilarity) {
            add(
              LintRule.intentSimilar,
              'intents "$a" and "$b" are too close '
              '(${similarity.toStringAsFixed(2)})',
            );
          }
        }
      }
    }
    for (final notFor in m.meta.notFor) {
      final target = _notForTarget.firstMatch(notFor)?.group(1);
      if (target == m.name) {
        add(
          LintRule.notForTarget,
          'notFor "$notFor": points to the item itself',
        );
      } else if (target == null || !names.contains(target)) {
        add(
          LintRule.notForTarget,
          'notFor "$notFor": end with (<item>) naming an existing item'
          '${target == null ? '' : '. $target does not exist'}',
        );
      }
    }
    if (m.meta.fr case final fr?) {
      final english = [
        for (final notFor in m.meta.notFor)
          _notForTarget.firstMatch(notFor)?.group(1),
      ];
      final french = [
        for (final notFor in fr.notFor)
          _notForTarget.firstMatch(notFor)?.group(1),
      ];
      if ('$french' != '$english') {
        add(
          LintRule.frenchMismatch,
          'meta.fr.notFor points to $french, meta.notFor to $english: '
          'keep them entry for entry',
        );
      }
    }
    for (final category in m.categories) {
      if (!categoryTaxonomy.contains(category)) {
        add(
          LintRule.categoryUnknown,
          'category "$category" is not in the taxonomy',
        );
      }
    }
    for (final category in m.categories.toSet()) {
      if (m.categories.where((c) => c == category).length > 1) {
        add(LintRule.categoryDuplicate, 'category "$category" appears twice');
      }
    }
    if (m.categories.isEmpty || m.categories.length > 3) {
      add(
        LintRule.categoryCount,
        '${m.categories.length} categories, expected 1 to 3',
      );
    }
    final rendered = m.verify?.states ?? const [];
    for (final state in m.meta.states) {
      if (m.verify?.goldens == null || !rendered.contains(state)) {
        add(
          LintRule.stateWithoutGolden,
          'state "$state" has no golden: '
          '${m.verify?.goldens == null ? 'no reference golden' : 'not in verify.states'}',
        );
      }
    }
  }
  return [...findings, ..._overlaps(manifests)];
}

/// Les intentions de même langue de deux éléments différents trop proches.
List<LintFinding> _overlaps(List<ItemManifest> manifests) => [
  for (final (i, a) in manifests.indexed)
    for (final b in manifests.skip(i + 1))
      for (final (lang, mine, theirs) in [
        (IntentLang.fr, a.meta.intents.fr, b.meta.intents.fr),
        (IntentLang.en, a.meta.intents.en, b.meta.intents.en),
      ])
        for (final x in mine)
          for (final y in theirs)
            if (trigramSimilarity(x, y) >= maxIntentSimilarity)
              LintFinding(
                a.name,
                LintRule.intentOverlap,
                '${lang.name} intent "$x" is close to "$y" in ${b.name}',
              ),
];

final _notForTarget = RegExp(r'\(([a-z0-9-]+)\)\s*$');

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

List<String> _words(String text) => [
  for (final match in _word.allMatches(text.toLowerCase())) match[0]!,
];

/// `se connecter` et `s'inscrire` commencent par `connecter` et `inscrire`.
String? _leadingVerb(String intent, IntentLang lang) {
  final words = _words(intent.replaceAll('’', "'"));
  if (lang == IntentLang.fr &&
      words.length > 1 &&
      (words[0] == 'se' || words[0] == 's')) {
    return words[1];
  }
  return words.firstOrNull;
}

/// La similarité de `pg_trgm` : chaque mot, en minuscules, bordé de deux
/// espaces devant et d'un derrière, donne ses trigrammes ; le score est la
/// part de trigrammes communs dans leur union.
double trigramSimilarity(String a, String b) {
  final x = _trigrams(a);
  final y = _trigrams(b);
  if (x.isEmpty && y.isEmpty) return 1;
  return x.intersection(y).length / x.union(y).length;
}

Set<String> _trigrams(String text) => {
  for (final word in _words(text))
    for (var i = 0; i < word.length + 1; i++) '  $word '.substring(i, i + 3),
};

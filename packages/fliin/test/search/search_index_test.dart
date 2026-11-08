import 'package:fliin/src/registry/build.dart';
import 'package:fliin/src/registry/client.dart';
import 'package:fliin/src/registry/signing.dart';
import 'package:fliin/src/search/analyzer.dart';
import 'package:fliin/src/search/search_index.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../registry/support.dart';

IndexEntry _decoy(
  String name, {
  required String title,
  required String description,
  required ({String title, String description}) french,
  required List<String> categories,
  required List<String> fr,
  required List<String> en,
  List<String> notFor = const [],
  List<Platform> platforms = Platform.values,
}) => IndexEntry(
  ref: ItemRef(name),
  type: ItemType.component,
  title: title,
  description: description,
  categories: categories,
  meta: ItemMeta(
    tier: Tier.free,
    platforms: platforms,
    states: const [],
    semanticsRoles: const [],
    intents: (fr: fr, en: en),
    notFor: notFor,
    fr: FrenchText(
      title: french.title,
      description: french.description,
      notFor: const [],
    ),
  ),
  versions: [
    IndexVersion(
      version: Version(0, 1, 0),
      manifestSha256: Sha256.ofString(name),
      flutter: VersionConstraint.parse('>=3.47.0 <4.0.0'),
      registryDependencies: [
        ItemDependency.parse('core@^${sourceVersion('core')}'),
      ],
    ),
  ],
);

final _decoys = [
  _decoy(
    'icon-button',
    title: 'Icon button',
    description: 'Shows a square button with only an icon, for toolbars.',
    french: (
      title: 'Bouton icône',
      description:
          "Bouton carré qui ne montre qu'une icône, pour les barres d'outils.",
    ),
    categories: ['actions'],
    fr: [
      'bouton avec seulement une icône',
      "action dans une barre d'outils",
      'fermer ou revenir avec une icône',
      'ajouter aux favoris avec un cœur',
      'icône cliquable',
    ],
    en: [
      'icon-only button',
      'toolbar action',
      'close or back icon',
      'favorite heart icon',
      'tappable icon',
    ],
    platforms: [Platform.ios, Platform.android],
  ),
  _decoy(
    'text-field',
    title: 'Text field',
    description:
        'Lets people type text, with a label, help and a validation error.',
    french: (
      title: 'Champ de texte',
      description: 'Champ de saisie avec libellé, aide et erreur de validation, pour les formulaires.',
    ),
    categories: ['forms'],
    fr: [
      'saisir du texte dans un formulaire',
      'champ e-mail avec erreur de validation',
      "remplir un formulaire d'inscription",
      'zone de saisie avec libellé',
      'afficher une erreur sous un champ',
    ],
    en: [
      'text input in a form',
      'email field with validation error',
      'fill in a sign-up form',
      'labelled input',
      'show an error under a field',
    ],
  ),
  _decoy(
    'switch',
    title: 'Switch',
    description: 'Turns a setting on or off.',
    french: (
      title: 'Interrupteur',
      description:
          'Bascule marche/arrêt pour activer ou désactiver un réglage.',
    ),
    categories: ['forms'],
    fr: [
      'activer ou désactiver un réglage',
      'bascule marche arrêt',
      'interrupteur des notifications',
      'couper le son',
      'option oui ou non',
    ],
    en: [
      'toggle a setting on or off',
      'on off switch',
      'notifications switch',
      'mute sound',
      'yes or no option',
    ],
  ),
];

late SearchIndex _index;

List<String> _ids(String intent, {Lang? lang, ItemType? kind}) => [
  for (final result
      in _index
          .search(SearchQuery(intent, lang: lang, kind: kind, limit: 10))
          .results)
    '${result.id}',
];

void main() {
  setUpAll(() async {
    final dist = tempDir().path;
    final key = await testKey();
    await DistWriter(dist).write(
      SourceRegistry.read(sourceRoot),
      stamp: BuildStamp(version: 1, publishedAt: DateTime.utc(2026, 10, 18)),
      key: key,
    );
    final client = RegistryClient.forUrl(
      Uri.directory(dist),
      Ed25519PointerVerifier([key.publicKey]),
      cacheRoot: tempDir().path,
      clock: () => DateTime.utc(2026, 10, 19),
    );
    final pointer = await client.fetchPointer();
    final fragment = await client.fetchFragment(
      pointer,
      pointer.fragments.single,
    );
    _index = SearchIndex.build([...fragment.entries, ..._decoys]);
  });

  group('classement', () {
    for (final intent in [
      "bouton d'action principal",
      'valider un formulaire',
      'call to action',
    ]) {
      test(
        'devrait classer button premier quand l\'intention est « $intent »',
        () {
          expect(_ids(intent).first, 'button');
        },
      );
    }

    test('devrait classer button premier quand seul le pluriel « boutons » peut correspondre', () {
      expect(_ids('plusieurs boutons alignés').first, 'button');
    });

    test('devrait ignorer casse, accents et apostrophe typographique quand on compare', () {
      final plain = _index
          .search(const SearchQuery("bouton d'action principal"))
          .results
          .first;
      final shouted = _index
          .search(const SearchQuery('BOUTON D’ACTION PRINCIPÂL'))
          .results
          .first;
      expect('${shouted.id}', 'button');
      expect(shouted.score, plain.score);
    });

    test('devrait rétrograder un élément et le dire quand son notFor correspond mieux que ses intentions', () {
      final results = _index
          .search(const SearchQuery('bouton bascule marche arrêt', limit: 10))
          .results;
      expect('${results.first.id}', 'switch');
      final button = results.singleWhere((r) => '${r.id}' == 'button');
      expect(
        button.why,
        contains('warning: not for “an on/off toggle: use a switch (switch)”'),
      );
    });

    test('devrait ne lire que les intentions de la langue demandée quand lang est donné', () {
      expect(_ids('submit a form', lang: Lang.en).first, 'button');
      expect(_ids('submit a form', lang: Lang.fr), isNot(contains('button')));
    });
  });

  group('résultat', () {
    test('devrait dire en anglais quels champs ont correspondu, même quand la requête est française', () {
      final button = _index
          .search(const SearchQuery('valider un formulaire'))
          .results
          .first;
      expect(button.why, contains('intent: “valider un formulaire”'));
      final viaTitle = _index
          .search(const SearchQuery('un bouton icône carré'))
          .results
          .first;
      expect('${viaTitle.id}', 'icon-button');
      expect(
        viaTitle.why,
        containsAll(['title: “Icon button”', 'description: “icon”']),
      );
    });

    test('devrait donner version, dépendances résolues et commande d\'installation', () {
      final button = _index
          .search(const SearchQuery("bouton d'action principal"))
          .results
          .first;
      expect('${button.version}', sourceVersion('button'));
      expect(button.tier, Tier.free);
      expect(
        ['${button.requires.first}', '${button.requires.last}'],
        [
          'core@${sourceVersion('core')}',
          'spinner@${sourceVersion('spinner')}',
        ],
      );
      expect(button.install, 'fliin add button');
      expect(button.toJson()['id'], 'button');
    });
  });

  group('filtres et pages', () {
    test(
      'devrait filtrer par type, plateformes et tier quand ils sont donnés', skip: withoutPro,
      () {
        const intent = "bouton d'action principal";
        expect(_ids('jetons de design et thème'), contains('core'));
        expect(
          _ids('jetons de design et thème', kind: ItemType.component),
          isNot(contains('core')),
        );
        final web = _index
            .search(
              const SearchQuery(intent, platforms: [Platform.web], limit: 10),
            )
            .results;
        expect(web.map((r) => '${r.id}'), isNot(contains('icon-button')));
        final pro = _index
            .search(const SearchQuery(intent, tier: Tier.pro, limit: 10))
            .results;
        expect(pro.map((r) => r.tier), everyElement(Tier.pro));
        expect(pro.map((r) => '${r.id}'), isNot(contains('button')));
        const empty = 'état vide d’une liste';
        List<String> tiered(Tier tier) => [
          for (final r
              in _index
                  .search(SearchQuery(empty, tier: tier, limit: 10))
                  .results)
            '${r.id}',
        ];
        expect(tiered(Tier.pro), contains('empty-state'));
        expect(tiered(Tier.free), isNot(contains('empty-state')));
      },
    );

    test(
      'devrait paginer par curseur quand les résultats dépassent la limite',
      () {
        const intent = "bouton d'action principal";
        final all = _ids(intent);
        final first = _index.search(const SearchQuery(intent, limit: 1));
        expect(first.results.map((r) => '${r.id}'), [all[0]]);
        final second = _index.search(
          SearchQuery(intent, limit: 1, cursor: first.nextCursor),
        );
        expect(second.results.map((r) => '${r.id}'), [all[1]]);
        final seen = <String>[];
        String? cursor;
        do {
          final page = _index.search(
            SearchQuery(intent, limit: 10, cursor: cursor),
          );
          seen.addAll(page.results.map((r) => '${r.id}'));
          cursor = page.nextCursor;
        } while (cursor != null && seen.length < 1000);
        expect(cursor, isNull);
        expect(seen.toSet(), hasLength(seen.length));
        expect(seen.take(all.length), all);
      },
    );
  });

  group('INVALID_INPUT', () {
    Matcher invalid([Object? suggestions = anything]) => throwsA(
      isA<InvalidInput>()
          .having((e) => e.toJson()['code'], 'code', 'INVALID_INPUT')
          .having((e) => e.suggestions, 'suggestions', suggestions),
    );

    test('devrait refuser une intention de 2 mots et suggérer des intentions proches', () {
      expect(
        () => _index.search(const SearchQuery('bouton principal')),
        invalid(
          predicate<List<String>>(
            (s) => s.first.contains("bouton d'action principal"),
          ),
        ),
      );
    });

    test(
      'devrait refuser une limite hors de 1 à 10 ou un curseur illisible',
      () {
        const intent = "bouton d'action principal";
        expect(
          () => _index.search(const SearchQuery(intent, limit: 11)),
          invalid(),
        );
        expect(
          () => _index.search(const SearchQuery(intent, limit: 0)),
          invalid(),
        );
        expect(
          () => _index.search(const SearchQuery(intent, cursor: 'x')),
          invalid(),
        );
      },
    );
  });
}

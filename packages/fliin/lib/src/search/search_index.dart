import 'dart:math' as math;

import 'package:fliin_schema/fliin_schema.dart' hide Token;
import 'package:pub_semver/pub_semver.dart';

import 'analyzer.dart';

final class SearchQuery {
  const SearchQuery(
    this.intent, {
    this.kind,
    this.platforms = const [],
    this.states = const [],
    this.tier,
    this.lang,
    this.limit = 5,
    this.cursor,
  });

  /// Trois mots au moins, sinon [InvalidInput].
  final String intent;
  final ItemType? kind;

  /// L'élément doit toutes les couvrir.
  final List<Platform> platforms;
  final List<String> states;
  final Tier? tier;

  /// Sans langue, les intentions françaises et anglaises comptent. Avec une
  /// langue, seuls les textes de cette langue, et les catégories, comptent :
  /// le titre, la description et les `notFor` anglais, ou ceux de
  /// `meta.fr`.
  final Lang? lang;

  /// De 1 à 10.
  final int limit;

  /// Le `nextCursor` de la page précédente.
  final String? cursor;
}

final class SearchResult {
  const SearchResult({
    required this.id,
    required this.version,
    required this.tier,
    required this.score,
    required this.why,
    required this.requires,
  });

  final ItemRef id;
  final Version version;
  final Tier tier;
  final double score;

  /// Les champs qui ont correspondu, en français.
  final List<String> why;

  /// La fermeture des `registryDependencies`, chacune à sa version retenue.
  final List<ItemRef> requires;
  String get install => 'fliin add $id';

  Map<String, Object?> toJson() => {
    'id': '$id',
    'version': '$version',
    'tier': tier.name,
    'score': (score * 1000).round() / 1000,
    'why': why,
    'requires': [for (final ref in requires) '$ref'],
    'install': install,
  };
}

final class SearchPage {
  const SearchPage(this.results, this.nextCursor);

  final List<SearchResult> results;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'results': [for (final result in results) result.toJson()],
    'nextCursor': nextCursor,
  };
}

final class InvalidInput implements Exception {
  const InvalidInput(this.message, [this.suggestions = const []]);

  final String message;

  /// Des intentions du catalogue proches de la requête refusée.
  final List<String> suggestions;

  Map<String, Object?> toJson() => {
    'code': 'INVALID_INPUT',
    'message': message,
    'details': {'suggestions': suggestions},
  };

  @override
  String toString() => 'INVALID_INPUT: $message';
}

/// BM25 par champ, pondéré : intentions ≫ titre ≫ description ≫ catégories.
/// Le score d'un champ est celui de son meilleur passage (une intention, une
/// catégorie), ce que `why` cite. Chaque passage est multiplié par la part des
/// termes de la requête qu'il contient : sans cela, un seul terme rare retrouvé
/// par l'analyse anglaise d'une requête française bat une intention qui la
/// reprend mot pour mot. À score égal, l'ordre est alphabétique.
final class SearchIndex {
  SearchIndex._(this._docs, this._stats);

  /// Un élément dont la fermeture des dépendances ne se résout pas dans
  /// [entries] n'est pas installable : il est écarté.
  factory SearchIndex.build(List<IndexEntry> entries) {
    final lookup = {
      for (final entry in entries) entry.ref: _ignoringFlutter(entry),
    };
    final docs = [
      for (final entry in entries)
        if (resolve(
              roots: [ItemDependency(entry.ref, VersionConstraint.any)],
              lookup: (ref) => lookup[ref],
              flutter: Version.none,
              installed: const {},
            )
            case final InstallPlan plan)
          _Doc(entry, plan),
    ];
    final stats = <(_Field, Lang), _Stats>{
      for (final field in _Field.values)
        for (final lang in Lang.values) (field, lang): _Stats(),
    };
    for (final doc in docs) {
      for (final MapEntry(key: field, value: passages)
          in doc.passages.entries) {
        for (final lang in Lang.values) {
          final stat = stats[(field, lang)]!;
          final terms = <String>{};
          for (final passage in passages.where((p) => p.lang == lang)) {
            stat.passages++;
            stat.tokens += passage.tokens.length;
            terms.addAll(passage.tf.keys);
          }
          for (final term in terms) {
            stat.df[term] = (stat.df[term] ?? 0) + 1;
          }
        }
      }
    }
    return SearchIndex._(docs, stats);
  }

  final List<_Doc> _docs;
  final Map<(_Field, Lang), _Stats> _stats;

  SearchPage search(SearchQuery query) {
    if (query.limit < 1 || query.limit > 10) {
      throw const InvalidInput('limit goes from 1 to 10');
    }
    final offset = switch (query.cursor) {
      null => 0,
      final cursor => int.tryParse(cursor),
    };
    if (offset == null || offset < 0) {
      throw const InvalidInput(
        'unreadable cursor. Use the nextCursor of a page',
      );
    }
    final hits = _rank(query);
    if (query.intent.split(_space).where(_wordChar.hasMatch).length < 3) {
      throw InvalidInput('the intent must have at least 3 words', [
        for (final hit in hits.take(3))
          if (hit.intent case final intent?) intent.text,
      ]);
    }
    return SearchPage([
      for (final hit in hits.skip(offset).take(query.limit)) hit.result,
    ], offset + query.limit < hits.length ? '${offset + query.limit}' : null);
  }

  List<_Hit> _rank(SearchQuery query) {
    final terms = {
      for (final lang in Lang.values)
        lang: {for (final token in analyze(query.intent, lang)) token.term},
    };
    bool asked(_Passage passage) =>
        query.lang == null || passage.lang == query.lang;
    int matched(_Passage passage) =>
        terms[passage.lang]!.where(passage.tf.containsKey).length;

    final hits = <_Hit>[];
    for (final doc in _docs.where((doc) => doc.keeps(query))) {
      var score = 0.0;
      final why = <String>[];
      _Passage? bestIntent;
      for (final field in _Field.values) {
        (_Passage, double)? best;
        (_Passage, double)? english;
        final passages = doc.passages[field]!;
        for (final passage
            in field == _Field.categories ? passages : passages.where(asked)) {
          final value = _score(
            passage,
            terms[passage.lang]!,
            _stats[(field, passage.lang)]!,
          );
          if (value > 0 && (best == null || value > best.$2)) {
            best = (passage, value);
          }
          if (value > 0 &&
              passage.lang == Lang.en &&
              (english == null || value > english.$2)) {
            english = (passage, value);
          }
        }
        if (best case (final passage, final value)) {
          score += field.weight * value;
          // Ce que lit le développeur est en anglais : on cite le meilleur
          // passage anglais quand il y en a un, même si le français a donné
          // le score.
          final cited = english?.$1 ?? passage;
          why.add(field.why(cited, terms[cited.lang]!));
          if (field == _Field.intents) bestIntent = cited;
        }
      }
      if (score == 0) continue;

      final intentHits = doc.passages[_Field.intents]!
          .where(asked)
          .map(matched)
          .fold(0, math.max);
      for (final notFor in doc.notFor.where(asked)) {
        if (matched(notFor) > intentHits) {
          score *= _notForPenalty;
          why.add('warning: not for “${notFor.shown}”');
          break;
        }
      }
      why.addAll([for (final state in query.states) 'state: “$state”']);
      hits.add(_Hit(doc, score, why, bestIntent));
    }
    return hits..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : '${a.doc.entry.ref}'.compareTo('${b.doc.entry.ref}');
    });
  }

  double _score(_Passage passage, Set<String> terms, _Stats stats) {
    var bm25 = 0.0;
    var matched = 0;
    for (final term in terms) {
      final tf = passage.tf[term];
      if (tf == null) continue;
      matched++;
      final df = stats.df[term]!;
      final idf = math.log(1 + (_docs.length - df + 0.5) / (df + 0.5));
      final norm = 1 - _b + _b * passage.tokens.length / stats.averageLength;
      bm25 += idf * tf * (_k1 + 1) / (tf + _k1 * norm);
    }
    return matched == 0 ? 0 : bm25 * matched / terms.length;
  }

  /// La recherche ne connaît pas le Flutter du projet : `add` le vérifie.
  static IndexEntry _ignoringFlutter(IndexEntry entry) => IndexEntry(
    ref: entry.ref,
    type: entry.type,
    title: entry.title,
    description: entry.description,
    categories: entry.categories,
    meta: entry.meta,
    versions: [
      for (final release in entry.versions)
        IndexVersion(
          version: release.version,
          manifestSha256: release.manifestSha256,
          flutter: VersionConstraint.any,
          registryDependencies: release.registryDependencies,
          status: release.status,
        ),
    ],
  );

  static const _k1 = 1.2;
  static const _b = 0.75;
  static const _notForPenalty = 0.25;
  static final _space = RegExp(r'\s+');
  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
}

enum _Field {
  intents(8, 'intent'),
  title(4, 'title'),
  description(2, 'description'),
  categories(1, 'category');

  const _Field(this.weight, this.label);

  final double weight;
  final String label;

  /// Une description est longue : on n'en cite que les mots retrouvés.
  String why(_Passage passage, Set<String> terms) {
    if (this != description) return '$label: “${passage.shown}”';
    final words = {
      for (final token in passage.tokens)
        if (terms.contains(token.term)) token.word,
    };
    return '$label: ${words.map((word) => '“$word”').join(', ')}';
  }
}

final class _Passage {
  _Passage(this.lang, this.text, {String? shown})
    : shown = shown ?? text,
      tokens = analyze(text, lang) {
    for (final token in tokens) {
      tf[token.term] = (tf[token.term] ?? 0) + 1;
    }
  }

  final Lang lang;
  final String text;

  /// Ce que `why` cite : le texte anglais qui correspond au passage
  /// français de `meta.fr`, ou le `notFor` entier dont on n'indexe que le
  /// cas.
  final String shown;
  final List<Token> tokens;
  final tf = <String, int>{};
}

final class _Doc {
  _Doc(this.entry, InstallPlan plan)
    : version = plan.items.last.version,
      requires = [
        for (final item in plan.items)
          if (item.ref != entry.ref) item.ref.at(item.version),
      ],
      passages = {
        _Field.intents: [
          for (final intent in entry.meta.intents.fr) _Passage(Lang.fr, intent),
          for (final intent in entry.meta.intents.en) _Passage(Lang.en, intent),
        ],
        _Field.title: [
          _Passage(Lang.en, entry.title),
          if (entry.meta.fr case final fr?)
            _Passage(Lang.fr, fr.title, shown: entry.title),
        ],
        _Field.description: [
          _Passage(Lang.en, entry.description),
          if (entry.meta.fr case final fr?) _Passage(Lang.fr, fr.description),
        ],
        _Field.categories: [
          for (final category in entry.categories) _Passage(Lang.en, category),
        ],
      },
      notFor = [
        for (final text in entry.meta.notFor)
          _Passage(Lang.en, _case(text), shown: text),
        for (final (i, text) in (entry.meta.fr?.notFor ?? const []).indexed)
          _Passage(
            Lang.fr,
            text,
            shown: i < entry.meta.notFor.length ? entry.meta.notFor[i] : text,
          ),
      ];

  /// Le cas d'un `notFor` anglais, sans l'élément vers lequel il renvoie
  /// (« an on/off toggle: use a switch (switch) ») : les noms des éléments
  /// sont des mots anglais, et une requête qui demande un « autocomplete
  /// select » cherche `combo-box`, pas autre chose qu'un `select`. En
  /// français, l'autre élément se dit avec d'autres mots que son nom
  /// (« utiliser un calendrier »), qu'une requête française reprend
  /// justement quand elle ne veut pas celui-ci.
  static String _case(String notFor) => notFor.split(':').first;

  final IndexEntry entry;

  /// La plus haute publiée ; la résolution place la racine en dernier.
  final Version version;
  final List<ItemRef> requires;
  final Map<_Field, List<_Passage>> passages;
  final List<_Passage> notFor;

  bool keeps(SearchQuery query) =>
      (query.kind == null || entry.type == query.kind) &&
      (query.tier == null || entry.meta.tier == query.tier) &&
      query.platforms.every(entry.meta.platforms.contains) &&
      query.states.every(entry.meta.states.contains);
}

final class _Stats {
  int passages = 0;
  int tokens = 0;
  final df = <String, int>{};

  double get averageLength => passages == 0 ? 1 : tokens / passages;
}

final class _Hit {
  _Hit(this.doc, this.score, this.why, this.intent);

  final _Doc doc;
  final double score;
  final List<String> why;

  /// L'intention la mieux retrouvée, que les suggestions reprennent.
  final _Passage? intent;

  SearchResult get result => SearchResult(
    id: doc.entry.ref,
    version: doc.version,
    tier: doc.entry.meta.tier,
    score: score,
    why: why,
    requires: doc.requires,
  );
}

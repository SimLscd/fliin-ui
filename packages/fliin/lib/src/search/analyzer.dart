import 'vendor/french_stemmer.dart';
import 'vendor/porter_stemmer.dart';

/// La langue d'une intention, et l'analyse appliquée au texte.
enum Lang { fr, en }

/// Un terme indexé et le mot du texte d'où il vient, que `why` cite.
typedef Token = ({String term, String word});

/// Minuscules, découpage sur tout ce qui n'est ni lettre ni chiffre, mots
/// vides retirés, racinisation, puis accents retirés.
List<Token> analyze(String text, Lang lang) => [
  for (final match in _word.allMatches(text.toLowerCase()))
    if (_term(match[0]!, lang) case final term?) (term: term, word: match[0]!),
];

/// Le Snowball français attend les accents : on les retire après lui.
String frenchStem(String word) =>
    (_french
          ..setCurrent(word)
          ..stem())
        .current;

String englishStem(String word) =>
    (_porter
          ..setCurrent(word)
          ..stem())
        .current;

String? _term(String word, Lang lang) {
  final folded = _fold(word);
  if (folded.length < 2 || _stopwords[lang]!.contains(folded)) return null;
  return switch (lang) {
    Lang.fr => _fold(frenchStem(word)),
    Lang.en => englishStem(folded),
  };
}

String _fold(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    out.write(_accents[char] ?? char);
  }
  return out.toString();
}

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
final _french = french_stemmer();
final _porter = porter_stemmer();

final _accents = {
  for (final (i, char) in 'àâäáãåçéèêëîïíìñôöóòõùûüúÿý'.split('').indexed)
    char: 'aaaaaaceeeeiiiinooooouuuuyy'[i],
  'œ': 'oe',
  'æ': 'ae',
};

final _stopwords = {
  Lang.fr: _words(
    'au aux avec ce ces cet cette dans de des du elle elles en est et il ils '
    'je la le les leur leurs lui ma me mes mon ne nous on ou par pas pour qu '
    'que qui sa se ses son sont sur te tu un une vous',
  ),
  Lang.en: _words(
    'an and are as at be by for from in into is it its my of on or that the '
    'this to with your',
  ),
};

Set<String> _words(String text) => text.split(' ').toSet();

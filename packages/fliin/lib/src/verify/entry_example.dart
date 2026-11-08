import 'package:dart_style/dart_style.dart';

/// Le cas de gauche à droite d'un `variant.dir == TextDirection.rtl ? a : b`
/// dont les deux branches sont un texte ou un nom.
final _directional = RegExp(
  r"\(?variant\.dir == TextDirection\.rtl\s*\?\s*(?:'(?:[^'\\]|\\.)*'|\w+)\s*:\s*('(?:[^'\\]|\\.)*'|\w+)\)?",
);

const _head = 'final example =';

/// [entry] (`verify.entry`) tel qu'un développeur l'écrirait dans son app :
/// `final example = …;`, préfixe `Fl`, la branche de gauche à droite seule,
/// mis en forme par `dart_style`. L'expression seule s'il ne se met pas en
/// forme.
String readableEntry(String entry) {
  final code = _code(entry);
  return _statement(code) ?? code;
}

/// L'expression de [readableEntry], sans `final example =` ni `;` : ce qu'un
/// agent colle dans un `child:`.
String entryExpression(String entry) {
  final code = _code(entry);
  final statement = _statement(code);
  if (statement == null) return code;
  final body = statement.trimRight();
  final expression = body.substring(_head.length, body.length - 1);
  if (expression.startsWith(' ')) return expression.substring(1);
  // Coupée après `=`, l'expression est indentée de quatre espaces.
  return [
    for (final line in expression.substring(1).split('\n'))
      line.startsWith('    ') ? line.substring(4) : line,
  ].join('\n');
}

String _code(String entry) => entry
    .replaceAll('{prefix}', 'Fl')
    .replaceAllMapped(_directional, (m) => m[1]!);

String? _statement(String code) {
  try {
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .formatStatement('$_head $code;');
  } on FormatterException {
    return null;
  }
}

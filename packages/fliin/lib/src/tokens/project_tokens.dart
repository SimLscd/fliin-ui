import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;

import '../install/normalizer.dart';
import 'generate.dart';

const tokensJsonName = 'fliin.tokens.json';
const tokensDartName = 'tokens.g.dart';

sealed class TokensOutcome {
  const TokensOutcome();
}

final class TokensWritten extends TokensOutcome {
  const TokensWritten(this.path);

  final String path;
}

final class TokensUpToDate extends TokensOutcome {
  const TokensUpToDate();
}

/// `--check` : le fichier manque ou diffère de la génération.
final class TokensStale extends TokensOutcome {
  const TokensStale(this.path);

  final String path;
}

/// Le JSON est illisible, ou n'a pas la forme que `core/` attend.
final class TokensInvalid extends TokensOutcome {
  const TokensInvalid(this.path, this.error);

  final String path;
  final String error;
}

/// Lit `fliin.tokens.json` dans [dir], génère `tokens.g.dart` normalisé par
/// le `dart_style` embarqué, et l'écrit à côté, ou avec [check] compare
/// seulement. Rien n'est écrit si le JSON est invalide.
TokensOutcome generateTokens(
  Directory dir, {
  required String prefix,
  required bool check,
}) {
  final source = File(p.join(dir.path, tokensJsonName));
  final target = File(p.join(dir.path, tokensDartName));
  final String generated;
  try {
    generated = renderTokensDart(
      jsonDecode(source.readAsStringSync()),
      prefix: prefix,
    );
  } on FormatException catch (e) {
    return TokensInvalid(source.path, e.message);
  } on TokenError catch (e) {
    return TokensInvalid(source.path, '$e');
  } on FileSystemException catch (e) {
    return TokensInvalid(source.path, e.message);
  } on FormatterException catch (e) {
    return TokensInvalid(
      source.path,
      'the generated Dart cannot be formatted: ${e.message()}',
    );
  }
  final current = target.existsSync() ? target.readAsStringSync() : null;
  if (!check) removeTemporaries(dir);
  if (current == generated) return const TokensUpToDate();
  if (check) return TokensStale(target.path);
  target.writeAsStringSync(generated);
  return TokensWritten(target.path);
}

/// `tokens.g.dart` pour le fichier de jetons [json], décodé, normalisé par le
/// `dart_style` embarqué. Lève [TokenError], ou [FormatterException] si le
/// Dart généré ne se formate pas.
String renderTokensDart(Object? json, {required String prefix}) => normalize(
  tokensDart(
    FliinTokens.read(resolveTokens(TokenDocument.fromJson(json))),
    prefix: prefix,
  ),
);

/// Le texte de `fliin.tokens.json` pour [json] : le sérialiseur de
/// [TokenDocument], indentation de deux espaces, comme le fichier du
/// registre.
String tokensJsonText(Object? json) =>
    '${const JsonEncoder.withIndent('  ').convert(TokenDocument.fromJson(json).toJson())}\n';

const _temporarySuffix = '.fliin-tmp';

/// Supprime les temporaires de [replaceFiles] restés dans [dir] : un arrêt
/// brutal entre l'écriture et le renommage les y laisse.
void removeTemporaries(Directory dir) {
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.endsWith(_temporarySuffix)) {
      entity.deleteSync();
    }
  }
}

/// Écrit chaque fichier de [contents] tout ou rien : chacun dans un fichier
/// temporaire voisin, puis renommés ; si un renommage échoue, ceux déjà
/// faits reprennent leur contenu d'avant et l'erreur remonte.
void replaceFiles(Map<File, String> contents) {
  final temporaries = {
    for (final file in contents.keys)
      file: File('${file.path}$_temporarySuffix'),
  };
  final before = {
    for (final file in contents.keys)
      file: file.existsSync() ? file.readAsStringSync() : null,
  };
  final replaced = <File>[];
  try {
    for (final MapEntry(key: file, value: text) in contents.entries) {
      temporaries[file]!.writeAsStringSync(text);
    }
    for (final file in contents.keys) {
      temporaries[file]!.renameSync(file.path);
      replaced.add(file);
    }
  } on FileSystemException {
    for (final file in replaced) {
      switch (before[file]) {
        case final String text:
          file.writeAsStringSync(text);
        case null:
          file.deleteSync();
      }
    }
    for (final temporary in temporaries.values) {
      if (temporary.existsSync()) temporary.deleteSync();
    }
    rethrow;
  }
}

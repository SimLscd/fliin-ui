// Génère flutter/registry/lib/core/tokens/tokens.g.dart (préfixe Fl) depuis
// fliin.tokens.json à côté, par le même générateur que `fliin tokens`, puis
// flutter/registry/test/torture/torture.g.dart depuis les *.tokens.json de ce
// dossier (les thèmes de torture, DESIGN.md §2.1 ; torture_a.tokens.json
// devient `tortureA`). `--check` : sortie 1 si un fichier commité dérive de
// la génération ; puis flutter/registry/test/presets/presets.g.dart depuis
// presets.json, les préréglages des goldens de l'ADR 0016 appliqués au
// fichier du registre. Lancer depuis la racine du dépôt :
// dart run packages/fliin/tool/gen_tokens.dart
import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/install/normalizer.dart';
import 'package:fliin/src/tokens/generate.dart';
import 'package:fliin/src/tokens/project_tokens.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;

const dir = 'flutter/registry/lib/core/tokens';
const tortureDir = 'flutter/registry/test/torture';
const presetsDir = 'flutter/registry/test/presets';

void main(List<String> args) {
  final check = args.contains('--check');
  final outcomes = {
    '$dir/$tokensDartName': generateTokens(
      Directory(dir),
      prefix: 'Fl',
      check: check,
    ),
    '$tortureDir/torture.g.dart': generateTortureTokens(
      Directory(tortureDir),
      check: check,
    ),
    '$presetsDir/presets.g.dart': generatePresetTokens(
      Directory(presetsDir),
      File('$dir/$tokensJsonName'),
      check: check,
    ),
  };
  var failed = false;
  for (final MapEntry(key: target, value: outcome) in outcomes.entries) {
    switch (outcome) {
      case TokensWritten():
        stdout.writeln('gen_tokens: $target écrit');
      case TokensUpToDate():
        stdout.writeln('gen_tokens: $target à jour');
      case TokensStale():
        stderr.writeln(
          'gen_tokens: $target dérive de ses *.tokens.json, '
          'lancez dart run packages/fliin/tool/gen_tokens.dart',
        );
        failed = true;
      case TokensInvalid(:final path, :final error):
        stderr.writeln('gen_tokens: $path : $error');
        failed = true;
    }
  }
  if (failed) exit(1);
}

/// Les thèmes de torture du registre (DESIGN.md §2.1) : chaque
/// `<nom>.tokens.json` de [dir] devient une variable `Fl` + `Tokens` nommée
/// en camelCase (`torture_a` → `tortureA`) dans `torture.g.dart`, à côté.
/// Même profil, même générateur et même normaliseur que `tokens.g.dart` ;
/// [check] compare seulement.
TokensOutcome generateTortureTokens(Directory dir, {required bool check}) {
  final target = File(p.join(dir.path, 'torture.g.dart'));
  final sources = [
    for (final entity in dir.listSync())
      if (entity is File && entity.path.endsWith('.tokens.json')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  final named = <String, FliinTokens>{};
  for (final source in sources) {
    try {
      named[_camelCase(
        p.basename(source.path).split('.').first,
      )] = FliinTokens.read(
        resolveTokens(
          TokenDocument.fromJson(jsonDecode(source.readAsStringSync())),
        ),
      );
    } on FormatException catch (e) {
      return TokensInvalid(source.path, e.message);
    } on TokenError catch (e) {
      return TokensInvalid(source.path, '$e');
    }
  }
  final generated = normalize(
    tokensValuesDart(
      named,
      prefix: 'Fl',
      tokensImport: 'package:fliin_ui/core/tokens/$tokensDartName',
    ),
  );
  final current = target.existsSync() ? target.readAsStringSync() : null;
  if (current == generated) return const TokensUpToDate();
  if (check) return TokensStale(target.path);
  target.writeAsStringSync(generated);
  return TokensWritten(target.path);
}

/// Les préréglages des goldens (ADR 0016 §8) : `presets.json` de [dir]
/// nomme des codes, chacun appliqué par `applyPreset` au fichier [registry]
/// devient une variable `Fl` + `Tokens` dans `presets.g.dart`, à côté. Le
/// chemin est celui de `fliin theme --preset`, jusqu'au Dart généré.
TokensOutcome generatePresetTokens(
  Directory dir,
  File registry, {
  required bool check,
}) {
  final source = File(p.join(dir.path, 'presets.json'));
  final target = File(p.join(dir.path, 'presets.g.dart'));
  final named = <String, FliinTokens>{};
  try {
    final defaults = jsonDecode(registry.readAsStringSync());
    final codes = (jsonDecode(source.readAsStringSync()) as Map<String, Object?>)
        .cast<String, String>();
    for (final MapEntry(key: name, value: code) in codes.entries) {
      switch (applyPreset(defaults, defaults, Preset.decode(code))) {
        case ThemeSolved(:final patch):
          named[name] = FliinTokens.read(
            resolveTokens(TokenDocument.fromJson(applyJsonPatch(defaults, patch))),
          );
        case Unsatisfiable():
          return TokensInvalid(source.path, '$name ($code) : UNSATISFIABLE');
      }
    }
  } on FormatException catch (e) {
    return TokensInvalid(source.path, e.message);
  } on PresetError catch (e) {
    return TokensInvalid(source.path, '$e');
  } on TokenError catch (e) {
    return TokensInvalid(source.path, '$e');
  }
  final generated = normalize(
    tokensValuesDart(
      named,
      prefix: 'Fl',
      tokensImport: 'package:fliin_ui/core/tokens/$tokensDartName',
    ),
  );
  final current = target.existsSync() ? target.readAsStringSync() : null;
  if (current == generated) return const TokensUpToDate();
  if (check) return TokensStale(target.path);
  target.writeAsStringSync(generated);
  return TokensWritten(target.path);
}

String _camelCase(String snake) =>
    snake.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

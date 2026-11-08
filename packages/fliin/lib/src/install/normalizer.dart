import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';

/// La version de `dart_style` embarquée, inscrite dans le lockfile (règle 3).
/// Le pubspec l'épingle en version exacte, et un test la compare à celle que
/// le workspace résout.
final dartStyleVersion = Version(3, 1, 14);

final _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
  pageWidth: 80,
);

/// LF puis `dart_style` à largeur et version de langage fixes : jamais le
/// `dart format` du SDK de l'utilisateur, dont la sortie varie.
String normalize(String source) =>
    _formatter.format(source.replaceAll('\r\n', '\n'));

import 'package:fliin_schema/fliin_schema.dart';

/// Le préréglage décodé, champ par champ, tel que `fliin theme --preset` et
/// `fliin init --preset` l'impriment.
List<String> presetLines(Preset preset) => [
  'Preset ${preset.encode()}:',
  for (final MapEntry(:key, :value) in preset.describe.entries)
    '  ${key.padRight(8)} $value',
];

/// Les familles nommées du préréglage, texte puis titres, sans doublon.
Set<PresetFamily> _families(Preset preset) => {?preset.body, ?preset.heading};

/// Une ligne par famille nommée : Fliin écrit son nom dans les jetons, l'app
/// embarque ses fichiers (ADR 0016 §3.4).
List<String> presetFontWarnings(Preset preset) => [
  for (final family in _families(preset))
    'font ${family.family}: fliin does not download it. Add its files to '
        'the app (${family.url}) and declare them in pubspec.yaml (block '
        'below)',
];

/// Les graisses que les rôles de l'échelle emploient (`typography.weight`) :
/// sans elles déclarées, Flutter synthétise le gras.
const _weights = {400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold'};

/// Le bloc `flutter: fonts:` à coller dans `pubspec.yaml`, une entrée par
/// graisse employée ; vide sans famille nommée.
String presetPubspecBlock(Preset preset) {
  final families = _families(preset);
  if (families.isEmpty) return '';
  final out = StringBuffer()
    ..writeln('flutter:')
    ..writeln('  fonts:');
  for (final family in families) {
    final file = family.family.replaceAll(' ', '');
    out
      ..writeln('    - family: ${family.family}')
      ..writeln('      fonts:');
    for (final MapEntry(key: weight, value: name) in _weights.entries) {
      out
        ..writeln('        - asset: assets/fonts/$file-$name.ttf')
        ..writeln('          weight: $weight');
    }
  }
  out.writeln(
    '# For a variable font, a single asset entry without weight is enough.',
  );
  return '$out';
}

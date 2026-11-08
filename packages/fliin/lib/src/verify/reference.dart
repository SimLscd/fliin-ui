import 'package:fliin_schema/fliin_schema.dart';

/// Pourquoi un rendu n'est pas comparé à sa référence publiée (ADR 0011).
enum ReferenceGap {
  /// La version installée ne publie pas de goldens.
  unpublished,

  /// `--entry` rend autre chose que `verify.entry`.
  customEntry,

  /// Le système, l'architecture, Flutter ou une police diffèrent de ceux
  /// de la référence.
  otherHost,

  /// `fliin.tokens.json` n'est plus celui que `core` a installé : un thème
  /// change chaque pixel, l'écart ne mesurerait que lui.
  customTheme,

  /// L'élément dessine des icônes, et le projet a choisi un autre jeu que
  /// Gravity UI, celui des références (ADR 0016 §3.8).
  otherIconSet;

  String describe(
    ItemGoldens? goldens,
    String host,
    List<String> drift,
  ) => switch (this) {
    unpublished => 'the registry publishes no reference for this version',
    customEntry => '--entry renders something other than the reference',
    otherHost when drift.isNotEmpty =>
      'the reference was rendered differently: ${drift.join(', ')}',
    otherHost =>
      'the reference was rendered on ${goldens?.host.name}, this host is $host',
    customTheme =>
      'fliin.tokens.json differs from the one core installed (theme)',
    otherIconSet =>
      'the references use Gravity UI, the default icon set, and this '
          'project draws another set',
  };
}

/// Ce que `verify` fait des goldens de référence de la version installée.
sealed class ReferencePlan {
  const ReferencePlan();

  /// `reference` du rapport.
  Map<String, Object?> toJson();
}

/// Les références sont téléchargées et passées au harnais.
final class CompareToReference extends ReferencePlan {
  const CompareToReference(this.goldens);

  final ItemGoldens goldens;

  @override
  Map<String, Object?> toJson() => {
    'status': 'compared',
    'host': goldens.host.name,
    'rendering': goldens.rendering.toJson(),
  };
}

final class SkipReference extends ReferencePlan {
  const SkipReference(this.gap, this.reason, {this.drift = const []});

  final ReferenceGap gap;
  final String reason;

  /// Pour [ReferenceGap.otherHost] constaté après le rendu : chaque valeur
  /// qui diffère de la référence.
  final List<String> drift;

  @override
  Map<String, Object?> toJson() => {
    'status': 'skipped',
    'gap': gap.name,
    'reason': reason,
    if (drift.isNotEmpty) 'drift': drift,
  };
}

/// Pur : la comparaison n'a lieu que pour `verify.entry`, sur l'hôte des
/// références, aux jetons installés par `core`, et, si l'élément dessine
/// des icônes, avec le jeu par défaut ([defaultIcons]). Le préfixe et `root` ne
/// changent aucun pixel. Une modification locale des fichiers de l'élément
/// est comparée : l'écart la mesure, c'est son but. [rendered] est ce que le
/// harnais rapporte de son rendu (architecture, Flutter, polices) : connu
/// après le rendu seulement, il rend la référence non comparable dès qu'une
/// valeur diffère de `goldens.rendering`.
ReferencePlan planReference({
  required ItemGoldens? goldens,
  required bool customEntry,
  required String host,
  required bool defaultTheme,
  bool defaultIcons = true,
  Rendering? rendered,
}) {
  final drift = switch ((goldens, rendered)) {
    (final ItemGoldens goldens, final Rendering rendered) =>
      goldens.rendering.differences(rendered),
    _ => const <String>[],
  };
  final ReferenceGap? gap = switch (goldens) {
    _ when customEntry => ReferenceGap.customEntry,
    null => ReferenceGap.unpublished,
    ItemGoldens(host: final reference) when reference.name != host =>
      ReferenceGap.otherHost,
    _ when drift.isNotEmpty => ReferenceGap.otherHost,
    _ when !defaultTheme => ReferenceGap.customTheme,
    _ when !defaultIcons => ReferenceGap.otherIconSet,
    _ => null,
  };
  return gap == null
      ? CompareToReference(goldens!)
      : SkipReference(gap, gap.describe(goldens, host, drift), drift: drift);
}

/// Ce que `report.json` du harnais dit de son rendu, null s'il ne le dit pas.
Rendering? renderingOf(Map<String, Object?> report) => switch (report) {
  {
    'host': final String abi,
    'flutter': final String flutter,
    'fonts': final Map<String, Object?> fonts,
  } =>
    Rendering(
      abi: abi,
      flutter: flutter,
      fonts: {
        for (final MapEntry(:key, :value) in fonts.entries) key: '$value',
      },
    ),
  _ => null,
};

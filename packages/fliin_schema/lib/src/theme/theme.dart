import 'dart:math' as math;

import '../tokens/fliin_tokens.dart';
import '../tokens/reference.dart';
import '../tokens/token_document.dart';
import '../tokens/token_error.dart';
import '../tokens/token_resolver.dart';
import '../tokens/token_value.dart';
import 'color_space.dart';
import 'json_patch.dart';

enum Appearance { light, dark }

/// Les neutres de `fliin theme --neutral` : une teinte OKLCH et un facteur
/// sur la chroma du neutre Fliin, qui est faible (0,016 au plus) et s'annule
/// vers le blanc et le noir. `sand`, sans teinte, redonne le neutre du
/// registre au bit près : les gris d'Izydesk n'ont pas tous la même teinte,
/// et aucune teinte unique ne les redonne tous (ADR 0019 §3). Les autres
/// viennent des couleurs de base des préréglages (ADR 0016 §3.1).
enum NeutralTone {
  sand(null, 1),
  cool(286, 1),
  neutral(0, 0),
  warm(70, 1),
  slate(257, 1.8),
  mauve(320, 1.4),
  olive(115, 1.4);

  const NeutralTone(this.hue, this.chromaFactor);

  /// Nulle : chaque pas garde la sienne.
  final double? hue;
  final double chromaFactor;

  /// Le pas [step] du neutre Fliin dans ce ton.
  Rgb8 step(String step) {
    final color = Rgb8.parse(neutralSteps[step]!);
    final hue = this.hue;
    if (hue == null) return color;
    final base = toOklch(color);
    return fromOklch((l: base.l, c: base.c * chromaFactor, h: hue)).color;
  }
}

/// Le neutre du registre, les gris d'Izydesk, pas par pas : sa clarté et sa
/// chroma définissent les autres tons.
const neutralRamp = {
  '0': '#FFFFFF',
  '31': '#F5F5F0',
  '36': '#F4F3EF',
  '70': '#E9E8E2',
  '88': '#E3E2DC',
  '189': '#C2C2B8',
  '317': '#9A9A8F',
  '365': '#8C8B82',
  '475': '#6B6B63',
  '593': '#4A4A44',
  '701': '#2E2E29',
  '734': '#26261F',
  '783': '#1A1A17',
  '832': '#0F0F0D',
};

/// Le neutre de `core` 0.1.x : une app qui n'a pas encore
/// monté `core` garde ces pas, et `fliin theme --neutral` doit encore les
/// décliner. Ses noms ne croisent ceux de [neutralRamp] qu'en `0`, le blanc
/// des deux.
const legacyNeutralRamp = {
  '0': '#FFFFFF',
  '9': '#FCFCFC',
  '30': '#F5F5F5',
  '48': '#EFEFF0',
  '54': '#EDEDED',
  '60': '#EBEBEC',
  '63': '#EAEAEB',
  '84': '#E3E3E4',
  '99': '#DEDEE0',
  '105': '#DCDCDD',
  '133': '#D3D3D4',
  '154': '#CCCCCD',
  '242': '#B0B0B1',
  '261': '#AAAAAD',
  '294': '#9F9FA9',
  '448': '#71717A',
  '489': '#666668',
  '590': '#4A4A4C',
  '601': '#47474B',
  '604': '#46464C',
  '616': '#434346',
  '650': '#3A3A3D',
  '690': '#303032',
  '714': '#2A2A2D',
  '722': '#28282C',
  '726': '#27272A',
  '743': '#232325',
  '790': '#18181B',
  '877': '#060607',
};

/// Les pas que le solveur reconnaît et décline : ceux du registre, puis ceux
/// de `core` 0.1.x.
final neutralSteps = {...legacyNeutralRamp, ...neutralRamp};

/// L'accent du registre. La couleur de marque prend la place de
/// [accentRampAnchor] ; chaque autre pas en garde l'écart de clarté et de
/// teinte, et la même part de chroma.
const accentRamp = {
  '100': '#7AA7FF',
  '200': '#1D4ED8',
  '300': '#3B63F6',
  '500': '#2563EB',
  '600': '#1D4ED8',
};
const accentRampAnchor = '500';

final class ThemeRequest {
  const ThemeRequest({
    this.primary,
    this.neutral,
    this.button,
    this.radius,
    this.font,
    this.headingFont,
    this.dimensions = const {},
    this.numbers = const {},
    this.flatShadows = false,
    this.flatShadowNames = const {},
  });

  /// La couleur de marque. Une couleur `--primary #RRGGBB` passe par
  /// [toOklch] ; une chroma hors du gamut sRGB est permise, [fromOklch] la
  /// réduit. Nulle : les pas d'accent du fichier sont gardés, et ne bougent
  /// que si une paire l'exige.
  final Oklch? primary;

  /// Nul : les pas du neutre restent ceux du fichier.
  final NeutralTone? neutral;
  final ButtonShape? button;

  /// `shape.radius.control`, en px.
  final double? radius;

  /// La police de `typography.family.{ios, android}`.
  final ThemeFont? font;

  /// La police de `typography.headingFamily.{ios, android}`.
  final HeadingFont? headingFont;

  /// Des dimensions en px, par chemin de jeton (`shape.radius.card`,
  /// `space.md`) : les échelles d'un préréglage, déjà calculées depuis les
  /// jetons livrés pour que l'appliquer deux fois donne le même fichier.
  /// [radius], s'il est donné, l'emporte sur `shape.radius.control`.
  final Map<String, double> dimensions;

  /// Des nombres sans unité, par chemin de jeton (`motion.spring.press.stiffness`),
  /// écrits à `$value`.
  final Map<String, num> numbers;

  /// Vrai : chaque ombre de `shadow.light` et `shadow.dark` devient une
  /// couche transparente.
  final bool flatShadows;

  /// Les ombres de `shadow.light` et `shadow.dark` à rendre transparentes
  /// par nom (`surface`), quand [flatShadows] ne les prend pas toutes.
  final Set<String> flatShadowNames;
}

/// La police des titres : celle du texte, ou une famille nommée.
sealed class HeadingFont {
  const HeadingFont();
}

/// `inherit` : les titres prennent la police du texte.
final class InheritedFont extends HeadingFont {
  const InheritedFont();
}

sealed class ThemeFont {
  const ThemeFont();
}

/// `--font system` : la police de la plateforme (`platform-default`).
final class SystemFont extends ThemeFont {
  const SystemFont();
}

/// Une famille que l'app déclare dans son pubspec (`named`).
final class NamedFont extends ThemeFont implements HeadingFont {
  const NamedFont(this.family);

  final String family;
}

/// Une paire mesurée dans une apparence. [exception] est l'exception que le
/// fichier déclare pour elle, quand le thème la garde (sans `--primary`).
typedef ContrastCheck = ({
  Appearance appearance,
  ContrastPair pair,
  double ratio,
  double threshold,
  ContrastException? exception,
});

extension ContrastCheckOk on ContrastCheck {
  bool get ok => ratio >= threshold;

  /// Sous son seuil, mais déclarée : un avertissement visible, pas une
  /// réussite.
  bool get excused => !ok && exception != null;
}

/// [check] tel que `fliin theme --json` et la page thème du site l'écrivent.
Map<String, Object?> contrastCheckJson(ContrastCheck check) => {
  'foreground': check.pair.foreground,
  'background': check.pair.background,
  if (check.pair.over.isNotEmpty) 'over': check.pair.over,
  'kind': check.pair.kind.name,
  'mode': check.appearance.name,
  'ratio': check.ratio,
  'threshold': check.threshold,
  'ok': check.ok,
  if (check.excused)
    'exception': {
      'ratio': check.exception!.ratio,
      'reason': check.exception!.reason,
    },
};

/// Deux rôles que l'interface oppose (le bord en erreur et le bord
/// focalisé), trop proches dans le thème obtenu : [deltaE] en ΔE OK.
typedef RoleClash = ({
  Appearance appearance,
  String role,
  String other,
  double deltaE,
});

/// Les paires de rôles qui doivent rester discernables. `fliin theme` ne
/// déplace `danger` qu'en clarté, et seulement si une paire l'exige avec une
/// marque (ADR 0014) : il prévient quand il se confond avec l'accent.
const distinctRoles = [('danger', 'accent')];

/// Sous ce ΔE OK, deux couleurs d'état se confondent d'un coup d'œil :
/// 7,5 fois la différence juste perceptible (0,02). Le rouge de `danger`
/// est à 0,10 d'une marque #E11D48 et à 0,14 d'un rose #DB2777, à plus de
/// 0,28 des bleus, verts et violets mesurés (ADR 0006).
const distinctDeltaE = 0.15;

sealed class ThemeOutcome {
  const ThemeOutcome();
}

/// [patch] mène le fichier lu au thème ; [contrast] mesure chaque paire du
/// thème obtenu, en clair puis en sombre.
///
/// [clashes] liste les paires de [distinctRoles] qui se confondent dans le
/// thème obtenu. C'est une alerte, pas un échec : l'erreur reste dite par
/// son texte (WCAG 1.4.1).
final class ThemeSolved extends ThemeOutcome {
  const ThemeSolved(this.patch, this.contrast, {this.clashes = const []});

  final List<PatchOp> patch;
  final List<ContrastCheck> contrast;
  final List<RoleClash> clashes;
}

/// Aucune clarté ne satisfait [failing] sans que l'accent perde plus d'un
/// tiers de la chroma que la marque lui donne. Ce plancher est un choix de
/// fidélité à la marque, plus strict que la teinte seule : un jaune assombri
/// à teinte égale devient olive. [failing] est la paire la plus loin de son
/// seuil au meilleur compromis permis, avec le ratio qu'elle y atteint.
///
/// [sameHue] est la même couleur de marque à la plus grande chroma qui donne
/// un thème conforme (dichotomie de 20 pas sur la chroma, clarté et teinte
/// gardées) ; [primary] en est l'accent clair. Nulle si seule une chroma
/// nulle passe.
///
/// [nearestHue] est la teinte OKLCH la plus proche de celle de la marque,
/// par pas de 1° depuis sa teinte arrondie (à égale distance, la teinte
/// au-dessus d'abord), qui donne un thème conforme avec la clarté et la
/// chroma de la marque ; [primary] est l'accent clair de ce thème, et
/// `fliin theme --primary` le prend tel quel. Nulle pour une marque sans
/// chroma, ou quand aucune teinte ne suffit.
final class Unsatisfiable extends ThemeOutcome {
  const Unsatisfiable(this.failing, {this.sameHue, this.nearestHue});

  final ContrastCheck failing;
  final ({double chroma, Rgb8 primary})? sameHue;
  final ({int hue, Rgb8 primary})? nearestHue;
}

/// Calcule le thème de [request] sur le fichier de jetons [json], décodé.
/// Lève une [TokenError] si le fichier ne suit pas le profil Fliin, n'a pas
/// la forme que le thème réécrit (couleur translucide, valeur héritée par
/// `$extends` là où le thème lit ou écrit), ou si une paire échoue entre
/// deux couleurs que le thème ne bouge pas.
ThemeOutcome solveTheme(Object? json, ThemeRequest request) {
  final document = TokenDocument.fromJson(json);
  final tokens = resolveTokens(document);
  final profile = FliinTokens.read(tokens);
  final problem = _Problem.read(
    tokens,
    profile,
    request.neutral,
    branded: request.primary != null,
  );
  switch (problem.solve(request.primary)) {
    case _Fits(:final colors, :final contrast):
      final patch = [
        ...problem.colorPatch(json, colors),
        ..._settingsPatch(json, request),
      ];
      return ThemeSolved(patch, contrast, clashes: problem.clashes(colors));
    case _Fails(:final failing):
      final brand = request.primary ?? problem.currentAccent;
      return Unsatisfiable(
        failing,
        sameHue: problem.sameHue(brand),
        nearestHue: problem.nearestHue(brand),
      );
  }
}

sealed class _Fit {
  const _Fit();
}

final class _Fits extends _Fit {
  const _Fits(this.colors, [this.contrast = const []]);

  final Map<String, Rgb8> colors;
  final List<ContrastCheck> contrast;
}

final class _Fails extends _Fit {
  const _Fails(this.failing);

  final ContrastCheck failing;
}

/// Un pas réécrit par le thème : son chemin (`color.accent.500`) et sa
/// couleur de départ, avant tout ajustement de clarté.
typedef _Start = ({String path, Oklch lch, Rgb8 rgb});

/// Des pas dont la clarté bouge d'un même écart : le bloc d'accent d'une
/// apparence, ou un pas de neutre seul. [minChroma] borne la chroma de
/// [anchor] : les deux tiers de celle demandée pour l'accent, rien pour un
/// neutre.
final class _Unit {
  _Unit.accent(this.steps, this.anchor) : minChroma = anchor.lch.c * 2 / 3;

  _Unit.single(_Start step) : steps = [step], anchor = step, minChroma = 0;

  final List<_Start> steps;
  final _Start anchor;
  final double minChroma;

  /// Les décalages de clarté essayés : aucun d'abord, puis l'ancre sur une
  /// grille de 1/1000, du plus proche au plus loin de son départ (le plus
  /// sombre d'abord à égalité).
  Iterable<double> get shifts sync* {
    yield 0;
    final l = anchor.lch.l;
    // Deux curseurs partent de part et d'autre de l'ancre sur la grille : à
    // chaque pas, le plus proche passe, le plus sombre d'abord à égalité.
    var below = math.min(1000, (l * 1000).floor());
    var above = below + 1;
    while (below >= 0 || above <= 1000) {
      final down = below >= 0 ? l - below / 1000 : double.infinity;
      final up = above <= 1000 ? above / 1000 - l : double.infinity;
      if (down <= up) {
        yield below / 1000 - l;
        below--;
      } else {
        yield above / 1000 - l;
        above++;
      }
    }
  }

  late final List<double> _shifts = shifts.toList();
  final Map<double, Map<String, Rgb8>?> _at = {};

  /// Les candidats de [shifts] au centième de clarté près, et l'ancre, dans
  /// leur ordre : la première passe d'une recherche en deux temps.
  late final List<({double shift, Map<String, Rgb8> colors})> coarse = [
    for (final shift in _shifts)
      if (shift == 0 || ((anchor.lch.l + shift) * 1000).round() % 10 == 0)
        if (_cached(shift) case final colors?) (shift: shift, colors: colors),
  ];

  /// Les candidats au millième dont l'écart à l'ancre tombe dans
  /// [`from`, `to`], dans l'ordre de [shifts].
  Iterable<({double shift, Map<String, Rgb8> colors})> fine(
    double from,
    double to,
  ) sync* {
    for (final shift in _shifts) {
      if (shift < from || shift > to) continue;
      if (_cached(shift) case final colors?) {
        yield (shift: shift, colors: colors);
      }
    }
  }

  Map<String, Rgb8>? _cached(double shift) =>
      _at.putIfAbsent(shift, () => at(shift));

  /// Les couleurs des pas décalés de [shift], ou nul si l'ancre y perd trop
  /// de chroma.
  Map<String, Rgb8>? at(double shift) {
    if (shift == 0) {
      return fromOklch(anchor.lch).chroma < minChroma
          ? null
          : {for (final step in steps) step.path: step.rgb};
    }
    final colors = <String, Rgb8>{};
    for (final step in steps) {
      final mapped = fromOklch((
        l: step.lch.l + shift,
        c: step.lch.c,
        h: step.lch.h,
      ));
      if (step.path == anchor.path && mapped.chroma < minChroma) return null;
      colors[step.path] = mapped.color;
    }
    return colors;
  }
}

/// Une paire mesurée dans une apparence, ses chemins résolus : [foreground]
/// et, du haut vers le bas, ses couches, chacune un `0xAARRGGBB` écrit en
/// valeur ([key] nul) ou l'alpha de la couche à poser sur la couleur de [key].
final class _Plan {
  const _Plan({
    required this.appearance,
    required this.pair,
    required this.foreground,
    required this.layers,
    required this.keys,
    required this.movers,
    required this.threshold,
    required this.exception,
  });

  final Appearance appearance;
  final ContrastPair pair;
  final String foreground;
  final List<({int base, String? key})> layers;

  /// Les chemins dont dépend le contraste, et ceux que le solveur déplace.
  final List<String> keys;
  final List<String> movers;
  final double threshold;
  final ContrastException? exception;
}

final class _Problem {
  _Problem({
    required this.profile,
    required this.branded,
    required this.targets,
    required this.fixed,
    required this.layers,
    required this.neutral,
    required this.accent,
    required this.blocks,
    required this.solo,
    required this.roleUnits,
  });

  final FliinTokens profile;

  /// Vrai quand une couleur de marque est demandée : le thème obtenu est
  /// alors conforme sans exception, et les rôles écrits en valeur bougent
  /// aussi (ADR 0014).
  final bool branded;

  /// Par apparence et rôle, le pas de neutre ou d'accent que le rôle
  /// désigne par alias ; absent, le rôle garde sa couleur.
  final Map<(Appearance, String), String> targets;

  /// La couleur actuelle de chaque rôle plein et de chaque pas.
  final Map<String, Rgb8> fixed;

  /// Les rôles translucides qu'une paire pose sur des couches : leur
  /// `0xAARRGGBB`, et le chemin dont ils reprennent les composantes par
  /// `$ref` (`accentSoft` suit son pas d'accent), s'il y en a un.
  final Map<String, ({int argb, String? source})> layers;

  /// Les pas de neutre réécrits, à leur couleur de départ.
  final Map<String, Rgb8> neutral;

  /// Les pas d'accent présents dans le fichier, par nom.
  final List<String> accent;

  /// Par apparence, le pas d'accent que désigne le rôle `accent`.
  final Map<Appearance, List<String>> blocks;

  /// Les autres pas d'accent, et les pas de neutre qui ne servent qu'au
  /// premier plan d'une paire : chacun bouge seul.
  final List<String> solo;

  /// Avec une marque, les rôles écrits en valeur qu'une paire mesure
  /// (`danger`, `dangerFill`, `onDangerSoft`…) : chacun bouge seul.
  final List<String> roleUnits;

  static const _neutralGroup = 'color.neutral';
  static const _accentGroup = 'color.accent';

  static String _rolePath(Appearance appearance, String role) =>
      'color.${appearance.name}.$role';

  factory _Problem.read(
    ResolvedTokens tokens,
    FliinTokens profile,
    NeutralTone? tone, {
    required bool branded,
  }) {
    Rgb8 current(String path) => switch (tokens[path]!.value) {
      ColorValue(:final alpha) when alpha != 1 => throw MissingFliinToken(
        path,
        'expected an opaque color (alpha $alpha). fliin theme measures the '
        'contrast of an opaque color',
      ),
      final ColorValue color => Rgb8(color.argb(path)),
      _ => throw MissingFliinToken(path, 'expected a color'),
    };
    final targets = <(Appearance, String), String>{};
    final fixed = <String, Rgb8>{};
    final layers = <String, ({int argb, String? source})>{};
    final opaque = {
      for (final pair in profile.contrastPairs) ...[
        pair.foreground,
        if (pair.over.isEmpty) pair.background else pair.over.last,
      ],
      'accent',
    };
    final translucent = {
      for (final pair in profile.contrastPairs)
        if (pair.over.isNotEmpty) ...[
          pair.background,
          ...pair.over.take(pair.over.length - 1),
        ],
    }.difference(opaque);
    for (final appearance in Appearance.values) {
      for (final role in profile.roles) {
        final path = _rolePath(appearance, role);
        if (opaque.contains(role)) {
          fixed[path] = current(path);
        } else if (translucent.contains(role)) {
          final value = tokens[path]!.value;
          if (value is! ColorValue) {
            throw MissingFliinToken(path, 'expected a color');
          }
          layers[path] = (
            argb: value.argb(path),
            source: _componentsSource(tokens[path]!.token.value),
          );
          continue;
        } else {
          continue;
        }
        if (tokens[path]!.token.value case final String text
            when text.startsWith('{')) {
          final target = CurlyAlias.parse(text, path).segments.join('.');
          if (_isRampStep(target)) targets[(appearance, role)] = target;
        }
      }
    }
    final neutral = <String, Rgb8>{};
    final accent = <String>[];
    for (final (group, ramp) in [
      (_neutralGroup, neutralSteps),
      (_accentGroup, accentRamp),
    ]) {
      for (final name in ramp.keys) {
        final path = '$group.$name';
        if (tokens[path] == null) continue;
        fixed[path] = current(path);
        if (group == _accentGroup) {
          accent.add(name);
        } else {
          neutral[path] = tone?.step(name) ?? fixed[path]!;
        }
      }
    }
    // Une teinte dont la source n'est ni un rôle ni un pas de rampe suit une
    // couleur que le solveur ne déplace pas : elle reste fixe.
    for (final (argb: _, :source) in layers.values) {
      if (source != null &&
          tokens[source] != null &&
          !source.startsWith('color.light.') &&
          !source.startsWith('color.dark.')) {
        fixed.putIfAbsent(source, () => current(source));
      }
    }
    for (final appearance in Appearance.values) {
      final path = _rolePath(appearance, 'accent');
      if (!(targets[(appearance, 'accent')]?.startsWith('$_accentGroup.') ??
          false)) {
        throw MissingFliinToken(
          path,
          'fliin theme expects an alias to a step of $_accentGroup '
          '(${accentRamp.keys.join(', ')})',
        );
      }
    }
    final pairs = [
      for (final appearance in Appearance.values)
        for (final pair in profile.contrastPairs) (appearance, pair),
    ];
    final backgrounds = {
      for (final (appearance, pair) in pairs)
        for (final role in [pair.background, ...pair.over])
          ?targets[(appearance, role)],
    };
    final foregrounds = {
      for (final (appearance, pair) in pairs)
        ?targets[(appearance, pair.foreground)],
    };
    final solo = [
      for (final path in neutral.keys)
        if (foregrounds.contains(path) && !backgrounds.contains(path)) path,
    ];
    final blocks = <Appearance, List<String>>{};
    final owner = <String, Appearance>{};
    for (final appearance in Appearance.values) {
      final anchor = targets[(appearance, 'accent')]!;
      blocks[appearance] = [anchor];
      for (final role in profile.roles) {
        final target = targets[(appearance, role)];
        if (target == null || !target.startsWith('$_accentGroup.')) continue;
        if (owner[target] case final other? when other != appearance) {
          throw MissingFliinToken(
            target,
            'accent step used in both light and dark. fliin theme shifts the '
            'lightness of each appearance separately',
          );
        }
        owner[target] = appearance;
        // Un pas d'accent autre que celui du rôle `accent` (voile d'appui,
        // texte d'accent) bouge seul : décalé avec le fond d'accent, un texte
        // d'accent deviendrait illisible sur une surface sombre là où le fond
        // doit foncer sous un texte blanc.
        if (target != anchor && !solo.contains(target)) solo.add(target);
      }
    }
    final roleUnits = [
      if (branded)
        for (final appearance in Appearance.values)
          for (final role in opaque)
            if (targets[(appearance, role)] == null && role != 'accent')
              _rolePath(appearance, role),
    ];
    final problem = _Problem(
      profile: profile,
      branded: branded,
      targets: targets,
      fixed: fixed,
      layers: layers,
      neutral: neutral,
      accent: accent,
      blocks: blocks,
      solo: solo,
      roleUnits: roleUnits,
    );
    final mobile = {
      ...blocks.values.expand((steps) => steps),
      ...solo,
      ...roleUnits,
    };
    for (final plan in problem._plans) {
      if (plan.keys.any(mobile.contains)) continue;
      final check = problem._check(neutral, plan);
      if (check.ok || check.excused) continue;
      final pair = plan.pair;
      throw MissingFliinToken(
        _rolePath(plan.appearance, pair.foreground),
        'on ${pair.background}: ${_floor(check.ratio)}:1 for a threshold of '
        '${check.threshold}:1, whatever the brand. Neither role points to a '
        'step that fliin theme adjusts, and the file declares no exception '
        'for this pair',
      );
    }
    return problem;
  }

  /// Le chemin dont un rôle translucide reprend les composantes par `$ref`.
  static String? _componentsSource(Object? raw) => switch (raw) {
    {'components': {r'$ref': final String ref}}
        when ref.startsWith('#/') && ref.endsWith(r'/$value/components') =>
      ref
          .substring(2, ref.length - r'/$value/components'.length)
          .replaceAll('/', '.'),
    _ => null,
  };

  static String _floor(double ratio) =>
      ((ratio * 100).floor() / 100).toStringAsFixed(2);

  /// L'accent clair du fichier : la marque quand `--primary` manque.
  Oklch get currentAccent =>
      toOklch(fixed[targets[(Appearance.light, 'accent')]]!);

  static bool _isRampStep(String path) => switch (path.split('.')) {
    ['color', 'neutral', final name] => neutralSteps.containsKey(name),
    ['color', 'accent', final name] => accentRamp.containsKey(name),
    _ => false,
  };

  late final List<(Appearance, ContrastPair)> _pairs = [
    for (final appearance in Appearance.values)
      for (final pair in profile.contrastPairs) (appearance, pair),
  ];

  /// Chaque paire de [_pairs] résolue une fois pour toutes : le solveur en
  /// mesure des centaines de milliers, sans rebâtir leurs chemins à chaque
  /// mesure.
  late final List<_Plan> _plans = [
    for (final (appearance, pair) in _pairs) _plan(appearance, pair),
  ];

  _Plan _plan(Appearance appearance, ContrastPair pair) => _Plan(
    appearance: appearance,
    pair: pair,
    foreground: _key(appearance, pair.foreground),
    layers: [
      for (final role in [pair.background, ...pair.over])
        // Une couche écrite en valeur garde la sienne ; une couche par `$ref`
        // prend la couleur, peut-être déplacée, de sa source.
        switch (layers[_rolePath(appearance, role)]) {
          (:final argb, source: null) => (base: argb, key: null),
          final layer? => (
            base: (layer.argb >>> 24) << 24,
            key: _key(appearance, role),
          ),
          null => (base: 0xFF << 24, key: _key(appearance, role)),
        },
    ],
    keys: _keys(appearance, pair).toList(),
    movers: _movers(appearance, pair).toList(),
    threshold: contrastThreshold(pair.kind),
    exception: branded
        ? null
        : profile.contrastExceptions
              .where(
                (e) =>
                    e.appearance == appearance.name && samePair(e.pair, pair),
              )
              .firstOrNull,
  );

  /// Le chemin qui porte la couleur de [role] : son pas, ou le rôle lui-même.
  late final Map<(Appearance, String), String> _keyCache = {};

  String _key(Appearance appearance, String role) =>
      _keyCache[(appearance, role)] ??= _resolveKey(appearance, role);

  String _resolveKey(Appearance appearance, String role) {
    final path = _rolePath(appearance, role);
    final source = layers[path]?.source;
    if (source != null) {
      final segments = source.split('.');
      if (segments case ['color', final mode, final sourceRole]
          when mode == appearance.name) {
        return _resolveKey(appearance, sourceRole);
      }
      return source;
    }
    return targets[(appearance, role)] ?? path;
  }

  /// Les chemins dont dépend le contraste de [pair].
  Iterable<String> _keys(Appearance appearance, ContrastPair pair) => [
    for (final role in [pair.foreground, pair.background, ...pair.over])
      _key(appearance, role),
  ];

  /// Les chemins que le solveur déplace pour [pair] : ceux de [_keys], sauf
  /// la source d'une teinte posée en fond. Le texte sur une teinte bouge, sa
  /// source non : éclaircir `success` pour lire `onSuccessSoft` sur
  /// `successSoft` le rendrait presque blanc.
  Iterable<String> _movers(Appearance appearance, ContrastPair pair) => [
    _key(appearance, pair.foreground),
    for (final role in [pair.background, ...pair.over])
      if (layers[_rolePath(appearance, role)]?.source == null)
        _key(appearance, role),
  ];

  Rgb8 _rgb(Map<String, Rgb8> colors, Appearance appearance, String role) {
    final key = _key(appearance, role);
    return colors[key] ?? fixed[key]!;
  }

  ContrastCheck _check(
    Map<String, Rgb8> colors,
    _Plan plan, [
    Map<String, Rgb8> overlay = const {},
  ]) {
    Rgb8 at(String key) => overlay[key] ?? colors[key] ?? fixed[key]!;
    final ratio = contrastRatio(
      at(plan.foreground),
      composite([
        for (final (:base, :key) in plan.layers)
          key == null ? base : base | at(key).value,
      ]),
    );
    return (
      appearance: plan.appearance,
      pair: plan.pair,
      ratio: ratio,
      threshold: plan.threshold,
      exception: plan.exception,
    );
  }

  /// Les unités d'un seul pas qui ne suit pas la marque : leurs candidats
  /// valent pour chaque appel de [solve], que sameHue et nearestHue
  /// enchaînent par centaines.
  final Map<String, _Unit> _fixedUnits = {};

  /// [brand] est la couleur de marque, que le pas [accentRampAnchor] prend
  /// tel quel ; sa chroma peut dépasser le gamut, que [fromOklch] réduit.
  _Fit solve(Oklch? brand) {
    final anchor = toOklch(Rgb8.parse(accentRamp[accentRampAnchor]!));
    final accentStarts = <String, _Start>{};
    for (final name in accent) {
      if (brand == null) {
        final path = '$_accentGroup.$name';
        final rgb = fixed[path]!;
        accentStarts[path] = (path: path, lch: toOklch(rgb), rgb: rgb);
        continue;
      }
      final step = toOklch(Rgb8.parse(accentRamp[name]!));
      final lch = (
        l: brand.l + step.l - anchor.l,
        c: anchor.c == 0 ? 0.0 : brand.c * step.c / anchor.c,
        h: (brand.h + step.h - anchor.h) % 360,
      );
      final path = '$_accentGroup.$name';
      accentStarts[path] = (path: path, lch: lch, rgb: fromOklch(lch).color);
    }
    _Start start(String path) => (
      path: path,
      lch: toOklch(neutral[path] ?? fixed[path]!),
      rgb: neutral[path] ?? fixed[path]!,
    );
    final units = [
      for (final appearance in Appearance.values)
        _Unit.accent([
          for (final path in blocks[appearance]!) accentStarts[path]!,
        ], accentStarts[targets[(appearance, 'accent')]]!),
      // Les rôles écrits en valeur avant les pas partagés : un pas de neutre
      // de premier plan (le blanc des textes) ne bouge que si son propre
      // fond l'exige, jamais pour compenser le fond d'un autre rôle.
      for (final path in [...roleUnits, ...solo])
        if (accentStarts.containsKey(path))
          _Unit.single(accentStarts[path]!)
        else
          _fixedUnits[path] ??= _Unit.single(start(path)),
    ];
    final colors = {
      ...neutral,
      for (final MapEntry(:key, :value) in accentStarts.entries) key: value.rgb,
    };
    // Un tour qui ne réduit plus la somme des manques ne convergera pas :
    // le thème est hors d'atteinte, inutile d'en faire d'autres.
    var deficit = double.infinity;
    for (var round = 0; round < 16; round++) {
      var changed = false;
      for (final unit in units) {
        for (final MapEntry(:key, :value) in _fit(
          unit,
          colors,
        ).colors.entries) {
          if (colors[key] != value) changed = true;
          colors[key] = value;
        }
      }
      final now = _deficit(_checks(colors));
      if (!changed || (now > 0 && now >= deficit)) break;
      deficit = now;
    }
    final contrast = _checks(colors).toList();
    final failing = _worst(contrast);
    return failing == null ? _Fits(colors, contrast) : _Fails(failing);
  }

  /// Le premier décalage de [unit] qui satisfait toutes ses paires, sinon
  /// celui du meilleur compromis : une paire qu'une unité ne peut pas sauver
  /// seule (le texte blanc sur le voile d'appui du danger) l'est par l'unité
  /// de son autre rôle, au tour suivant.
  _Fits _fit(_Unit unit, Map<String, Rgb8> colors) {
    final paths = {for (final step in unit.steps) step.path};
    final pairs = [
      for (final plan in _plans)
        if (plan.movers.any(paths.contains)) plan,
    ];
    // Le compromis minimise la somme des manques : une paire que l'unité ne
    // peut pas sauver seule ne doit pas l'empêcher d'améliorer les autres.
    // La recherche se fait au centième de clarté, puis au millième entre le
    // premier centième qui passe et le précédent : les contrastes sont
    // monotones en clarté, la frontière trouvée est celle d'un balayage fin.
    double deficitOf(Map<String, Rgb8> candidate) =>
        _deficit(_checks(colors, pairs, candidate));
    ({double shift, Map<String, Rgb8> colors, double deficit})? best;
    for (final candidate in unit.coarse) {
      final deficit = deficitOf(candidate.colors);
      if (deficit == 0) {
        final distance = candidate.shift.abs();
        final nearer =
            [
              ...unit.fine(-distance, -distance + 0.01),
              ...unit.fine(distance - 0.01, distance),
            ]..sort((a, b) {
              final da = a.shift.abs(), db = b.shift.abs();
              return da == db ? a.shift.compareTo(b.shift) : da.compareTo(db);
            });
        for (final fine in nearer) {
          if (deficitOf(fine.colors) == 0) return _Fits(fine.colors);
        }
        return _Fits(candidate.colors);
      }
      if (best == null || deficit < best.deficit) {
        best = (
          shift: candidate.shift,
          colors: candidate.colors,
          deficit: deficit,
        );
      }
    }
    if (best case final coarseBest?) {
      for (final fine in unit.fine(
        coarseBest.shift - 0.01,
        coarseBest.shift + 0.01,
      )) {
        final deficit = deficitOf(fine.colors);
        if (deficit < best!.deficit) {
          best = (shift: fine.shift, colors: fine.colors, deficit: deficit);
        }
      }
    }
    // Aucun décalage ne garde assez de chroma, ce qu'en pratique seule une
    // teinte essayée par nearestHue provoque : l'unité reste à son départ.
    return _Fits(
      best?.colors ?? {for (final step in unit.steps) step.path: step.rgb},
    );
  }

  List<RoleClash> clashes(Map<String, Rgb8> colors) => [
    for (final appearance in Appearance.values)
      for (final (role, other) in distinctRoles)
        if (deltaEOk(
              _rgb(colors, appearance, role),
              _rgb(colors, appearance, other),
            )
            case final deltaE when deltaE < distinctDeltaE)
          (appearance: appearance, role: role, other: other, deltaE: deltaE),
  ];

  Iterable<ContrastCheck> _checks(
    Map<String, Rgb8> colors, [
    List<_Plan>? plans,
    Map<String, Rgb8> overlay = const {},
  ]) => [for (final plan in plans ?? _plans) _check(colors, plan, overlay)];

  /// La somme des manques relatifs des paires en échec, hors exceptions
  /// gardées : nulle quand toutes passent.
  static double _deficit(Iterable<ContrastCheck> checks) => checks
      .where((check) => !check.ok && !check.excused)
      .fold(0.0, (sum, check) => sum + check.threshold / check.ratio - 1);

  /// La paire la plus loin de son seuil, hors exceptions gardées ; nulle
  /// quand toutes passent.
  static ContrastCheck? _worst(Iterable<ContrastCheck> checks) => checks
      .where((check) => !check.ok && !check.excused)
      .fold<ContrastCheck?>(
        null,
        (worst, check) =>
            worst == null ||
                check.ratio / check.threshold < worst.ratio / worst.threshold
            ? check
            : worst,
      );

  /// L'accent clair du thème de [brand], s'il est conforme et que
  /// `--primary` avec cet accent l'est aussi.
  Rgb8? _conformingAccent(Oklch brand) {
    if (solve(brand) case _Fits(:final colors)) {
      final primary = colors[targets[(Appearance.light, 'accent')]]!;
      if (solve(toOklch(primary)) is _Fits) return primary;
    }
    return null;
  }

  ({double chroma, Rgb8 primary})? sameHue(Oklch brand) {
    if (brand.c < 1e-4) return null;
    var low = 0.0;
    var high = brand.c;
    Rgb8? best;
    for (var i = 0; i < 20; i++) {
      final mid = (low + high) / 2;
      if (_conformingAccent((l: brand.l, c: mid, h: brand.h)) case final p?) {
        low = mid;
        best = p;
      } else {
        high = mid;
      }
    }
    return best == null ? null : (chroma: low, primary: best);
  }

  ({int hue, Rgb8 primary})? nearestHue(Oklch brand) {
    if (brand.c < 1e-4) return null;
    final origin = brand.h.round();
    for (var distance = 1; distance <= 180; distance++) {
      for (final hue in {
        (origin + distance) % 360,
        (origin - distance) % 360,
      }) {
        final primary = _conformingAccent((
          l: brand.l,
          c: brand.c,
          h: hue.toDouble(),
        ));
        if (primary != null) return (hue: hue, primary: primary);
      }
    }
    return null;
  }

  /// Les couleurs qui changent, précédées d'un `test` sur tout ce que le
  /// calcul a lu et qui ne change pas : les paires, et la valeur de chaque
  /// rôle et de chaque pas qu'elles désignent. Rejoué sur un fichier dont
  /// une de ces valeurs a bougé, le patch échoue au lieu de produire un
  /// contraste faux.
  List<PatchOp> colorPatch(Object? json, Map<String, Rgb8> colors) {
    final replaces = [
      for (final MapEntry(key: path, value: rgb) in colors.entries)
        if (fixed[path] != rgb)
          ..._replace(
            json,
            [...path.split('.'), r'$value'],
            {
              'colorSpace': 'srgb',
              'components': [
                for (final channel in [rgb.r, rgb.g, rgb.b])
                  double.parse((channel / 255).toStringAsFixed(4)),
              ],
              'hex': rgb.hex,
            },
          ),
      // Avec une marque, le thème obtenu est conforme : les exceptions du
      // fichier n'ont plus d'objet (ADR 0014).
      if (branded && profile.contrastExceptions.isNotEmpty)
        ..._replace(json, [
          'color',
          r'$extensions',
          FliinTokens.contrastExceptionsExtension,
        ], const <Object?>[]),
    ];
    if (replaces.isEmpty) return const [];
    final replaced = {for (final op in replaces) op.path};
    final read = <List<String>>[
      ['color', r'$extensions', FliinTokens.contrastExtension],
      for (final (appearance, pair) in _pairs)
        for (final role in [
          pair.foreground,
          pair.background,
          ...pair.over,
        ]) ...[
          ['color', appearance.name, role, r'$value'],
          if (targets[(appearance, role)] case final target?)
            [...target.split('.'), r'$value'],
        ],
    ];
    final guarded = <String>{};
    return [
      for (final segments in read)
        if (jsonPointer(segments) case final path
            when !replaced.contains(path) && guarded.add(path))
          (op: PatchOperation.test, path: path, value: _own(json, segments)),
      ...replaces,
    ];
  }
}

List<PatchOp> _settingsPatch(Object? json, ThemeRequest request) => [
  if (request.button case final shape?)
    ..._replace(json, [
      'shape',
      'button',
      r'$extensions',
      FliinTokens.buttonShapeExtension,
      'value',
    ], shape.name),
  for (final MapEntry(key: path, value: px) in request.dimensions.entries)
    if (request.radius == null || path != 'shape.radius.control')
      ..._replace(json, [...path.split('.'), r'$value', 'value'], _px(px)),
  if (request.radius case final radius?)
    ..._replace(json, [
      'shape',
      'radius',
      'control',
      r'$value',
      'value',
    ], _px(radius)),
  for (final MapEntry(key: path, value: number) in request.numbers.entries)
    ..._replace(json, [...path.split('.'), r'$value'], number),
  if (request.flatShadows || request.flatShadowNames.isNotEmpty)
    for (final appearance in FliinTokens.appearances)
      for (final name in _ownNames(json, ['shadow', appearance]))
        if (request.flatShadows || request.flatShadowNames.contains(name))
          ..._replace(json, [
            'shadow',
            appearance,
            name,
            r'$value',
          ], _flatShadow),
  if (request.font case final font?)
    for (final platform in FliinTokens.platforms)
      ..._familyPatch(
        json,
        ['typography', 'family', platform],
        switch (font) {
          NamedFont(:final family) => family,
          SystemFont() => null,
        },
        quiet: 'platform-default',
      ),
  if (request.headingFont case final font?)
    for (final platform in FliinTokens.platforms)
      ..._familyPatch(
        json,
        ['typography', 'headingFamily', platform],
        switch (font) {
          NamedFont(:final family) => family,
          InheritedFont() => null,
        },
        quiet: 'inherit',
      ),
];

/// Un entier quand [px] n'a pas de décimale, comme le fichier du registre.
num _px(double px) => px == px.roundToDouble() ? px.round() : px;

/// Les noms des jetons écrits sous [segments], dans l'ordre du fichier.
List<String> _ownNames(Object? json, List<String> segments) =>
    switch (_own(json, segments)) {
      final Map<String, Object?> group => [
        for (final key in group.keys)
          if (!key.startsWith(r'$')) key,
      ],
      _ => throw MissingFliinToken(segments.join('.'), 'expected a group'),
    };

/// Une ombre sans effet : la forme de l'ombre sombre `surface` de `core`
/// 0.1.x.
const _flatShadow = [
  {
    'color': {
      'colorSpace': 'srgb',
      'components': [0, 0, 0],
      'alpha': 0,
      'hex': '#000000',
    },
    'offsetX': {'value': 0, 'unit': 'px'},
    'offsetY': {'value': 0, 'unit': 'px'},
    'blur': {'value': 0, 'unit': 'px'},
    'spread': {'value': 0, 'unit': 'px'},
  },
];

/// `$value` et la source de la police à [segments] : [family] nommée, ou,
/// nulle, la source [quiet] (`platform-default` ou `inherit`).
List<PatchOp> _familyPatch(
  Object? json,
  List<String> segments,
  String? family, {
  required String quiet,
}) => [
  ..._replace(
    json,
    [...segments, r'$value'],
    [?family, ...FliinTokens.platformDefaultFamily],
  ),
  ..._replace(
    json,
    [...segments, r'$extensions', FliinTokens.fontFamilyExtension],
    {'source': family == null ? quiet : 'named'},
  ),
];

/// `test` sur la valeur actuelle puis `replace`, ou rien si elle ne change
/// pas.
List<PatchOp> _replace(Object? json, List<String> segments, Object? value) {
  final path = jsonPointer(segments);
  final current = _own(json, segments);
  if (jsonEquals(current, value)) return const [];
  return [
    (op: PatchOperation.test, path: path, value: current),
    (op: PatchOperation.replace, path: path, value: value),
  ];
}

/// La valeur écrite à [segments] dans le fichier. Une valeur héritée par
/// `$extends` n'a pas d'emplacement : le thème ne peut ni la garder par un
/// `test` ni la remplacer.
Object? _own(Object? json, List<String> segments) {
  try {
    return valueAt(json, jsonPointer(segments));
  } on JsonPatchError {
    throw MissingFliinToken(
      segments.takeWhile((segment) => !segment.startsWith(r'$')).join('.'),
      'fliin theme reads or rewrites ${jsonPointer(segments)}. The value must '
      'be written at this location, not inherited through \$extends',
    );
  }
}

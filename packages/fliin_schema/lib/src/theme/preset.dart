import 'dart:convert';
import 'dart:math' as math;

import '../tokens/fliin_tokens.dart';
import 'color_space.dart';
import 'json_patch.dart';
import 'theme.dart';

/// La couleur de base d'un préréglage : un ton de neutres (ADR 0016 §3.1).
/// `sand`, les gris d'Izydesk, est celle du registre (ADR 0019).
enum PresetBase {
  sand(NeutralTone.sand),
  zinc(NeutralTone.cool),
  neutral(NeutralTone.neutral),
  stone(NeutralTone.warm),
  slate(NeutralTone.slate),
  mauve(NeutralTone.mauve),
  olive(NeutralTone.olive);

  const PresetBase(this.tone);

  final NeutralTone tone;
}

/// La couleur primaire d'un préréglage : une couleur de Tailwind au pas 600,
/// ou [custom], la couleur de marque que le code porte ; le solveur l'ajuste
/// jusqu'au contraste (ADR 0016 §3.2). `blue`, en tête, est l'accent du
/// registre (ADR 0019) ; [azure], l'accent du thème d'avant `core` 0.2.0,
/// vient après les couleurs de Tailwind.
enum PresetPrimary {
  blue('#2563EB'),
  indigo('#4F46E5'),
  violet('#7C3AED'),
  purple('#9333EA'),
  fuchsia('#C026D3'),
  pink('#DB2777', shuffled: false),
  rose('#E11D48', shuffled: false),
  red('#DC2626', shuffled: false),
  orange('#EA580C', shuffled: false),
  amber('#D97706', shuffled: false),
  yellow('#CA8A04'),
  lime('#65A30D'),
  green('#16A34A'),
  emerald('#059669'),
  teal('#0D9488'),
  cyan('#0891B2'),
  sky('#0284C7'),
  azure('#0485F7'),
  custom(null, shuffled: false);

  const PresetPrimary(this.hex, {this.shuffled = true});

  /// La couleur demandée au solveur, avant ajustement ; nulle pour
  /// [custom], dont la couleur est [Preset.brand].
  final String? hex;

  /// Faux pour une couleur que le solveur rend trop proche de `danger`
  /// (ΔE OK sous 0,15, ADR 0016 §6), et pour [custom] : on peut la choisir,
  /// le mélange au hasard ne la tire pas. `preset_contrast_test.dart` le
  /// mesure.
  final bool shuffled;
}

enum FontCategory { sans, serif, mono }

/// Une famille de Google Fonts (ADR 0016 §3.4). L'app embarque ses
/// fichiers : Fliin écrit seulement son nom dans les jetons.
enum PresetFamily {
  inter('Inter', FontCategory.sans),
  geist('Geist', FontCategory.sans),
  figtree('Figtree', FontCategory.sans),
  manrope('Manrope', FontCategory.sans),
  dmSans('DM Sans', FontCategory.sans),
  instrumentSans('Instrument Sans', FontCategory.sans),
  ibmPlexSans('IBM Plex Sans', FontCategory.sans),
  spaceGrotesk('Space Grotesk', FontCategory.sans),
  publicSans('Public Sans', FontCategory.sans),
  outfit('Outfit', FontCategory.sans),
  nunitoSans('Nunito Sans', FontCategory.sans),
  lora('Lora', FontCategory.serif),
  merriweather('Merriweather', FontCategory.serif),
  playfairDisplay('Playfair Display', FontCategory.serif),
  notoSerif('Noto Serif', FontCategory.serif),
  sourceSerif4('Source Serif 4', FontCategory.serif),
  ebGaramond('EB Garamond', FontCategory.serif),
  robotoSlab('Roboto Slab', FontCategory.serif),
  jetBrainsMono('JetBrains Mono', FontCategory.mono),
  geistMono('Geist Mono', FontCategory.mono);

  const PresetFamily(this.family, this.category);

  /// Le nom de la famille, tel que `pubspec.yaml` le déclare.
  final String family;
  final FontCategory category;

  /// La page de la famille sur Google Fonts.
  String get url =>
      'https://fonts.google.com/specimen/${family.replaceAll(' ', '+')}';
}

/// L'échelle des rayons de `shape.radius` (ADR 0016 §3.5).
enum PresetRadius {
  standard(1),
  none(0),
  small(0.5),
  large(1.5);

  const PresetRadius(this.scale);

  final double scale;
}

/// L'échelle des pas de `space` (ADR 0016 §3.6).
enum PresetSpacing {
  standard(1),
  compact(0.75),
  relaxed(1.25);

  const PresetSpacing(this.scale);

  final double scale;
}

/// Les ombres de `shadow` (ADR 0016 §3.7).
enum PresetShadow { standard, none }

/// Le jeu d'icônes (ADR 0016 §3.8) : celui que `icons/fl_icons.dart` dessine,
/// mêmes 46 noms `FlIcons.*` dans chacun. [fliin], le défaut, est Gravity UI ;
/// les autres arrivent en fin de liste, sans changer la version du code.
enum PresetIcons {
  fliin,
  lucide,
  tabler,
  phosphor;

  /// La clé de la variante de fichier qui porte ce jeu dans le manifeste de
  /// `icons` (`files[].variants`) ; nulle pour le défaut, le fichier même.
  String? get variant => this == fliin ? null : name;

  /// Le nom du jeu tel que l'affiche une sortie : `fliin` est Gravity UI.
  String get label => switch (this) {
    fliin => 'Gravity UI',
    lucide => 'Lucide',
    tabler => 'Tabler',
    phosphor => 'Phosphor',
  };
}

/// Le fond des menus, popovers, feuilles et dialogues, `surfaceOverlay`
/// (ADR 0016 §3.11) : le neutre du registre, ou teinté de la primaire.
enum PresetMenu { standard, tinted }

/// Les cartes et groupes (`FlSurface`) : posées par leur ombre, ou à plat
/// avec un trait de `size.surfaceBorder` (ADR 0016 §3.11).
enum PresetCards { raised, outlined }

/// L'épaisseur des traits, `size.border` (ADR 0016 §3.7).
enum PresetBorder {
  regular(1),
  medium(1.5),
  bold(2);

  const PresetBorder(this.scale);

  final double scale;
}

/// L'échelle de taille du texte, sur chaque style de `typography.scale`
/// (ADR 0016 §3.12). La taille choisie par l'utilisateur de l'app s'y
/// ajoute à l'exécution.
enum PresetTextSize {
  regular(1),
  small(0.9),
  large(1.1);

  const PresetTextSize(this.scale);

  final double scale;
}

/// Le tempo des animations : les durées de `motion.duration` multipliées
/// par [scale], la raideur des ressorts de `motion.spring` divisée par son
/// carré (ADR 0016 §3.13). Le mouvement réduit de l'utilisateur de l'app
/// reste lu à l'exécution.
enum PresetMotion {
  regular(1),
  fast(0.7),
  slow(1.4);

  const PresetMotion(this.scale);

  final double scale;
}

/// Un préréglage de thème, décodé. Chaque champ à son premier indice est le
/// thème livré, Izydesk (ADR 0019).
final class Preset {
  const Preset({
    this.base = PresetBase.sand,
    this.primary = PresetPrimary.blue,
    this.body,
    this.heading,
    this.radius = PresetRadius.standard,
    this.spacing = PresetSpacing.standard,
    this.shadow = PresetShadow.standard,
    this.button = ButtonShape.pill,
    this.icons = PresetIcons.fliin,
    this.menu = PresetMenu.standard,
    this.cards = PresetCards.raised,
    this.border = PresetBorder.regular,
    this.text = PresetTextSize.regular,
    this.motion = PresetMotion.regular,
    this.brand,
  });

  /// Lit [code] : `c` puis treize chiffres base62 (ADR 0016 §4, ADR 0019
  /// §5). Lève une [PresetError] dont le message dit quoi faire, sans jamais
  /// retomber sur un défaut.
  factory Preset.decode(String code) {
    if (code.isEmpty) {
      throw const PresetError(
        'empty preset. A code starts with its version, like c0000000000000',
      );
    }
    final version = code[0];
    final layout = _layouts[version];
    // La version d'abord : un code d'une version future peut avoir une
    // autre longueur, et c'est la mise à jour de fliin qu'il faut dire.
    if (isRetiredPresetCode(code)) {
      throw PresetError(retiredPresetMessage(version));
    }
    if (layout == null) {
      throw PresetError(
        RegExp('^[a-z]').hasMatch(version)
            ? 'unknown version $version. This fliin reads versions '
                  '${_layouts.keys.join(' and ')}. Update fliin'
            : '$version is not a version. A preset starts with its version '
                  'letter (${_layouts.keys.join(', ')}), like c0000000000000',
      );
    }
    if (code.length != layout.length) {
      throw PresetError(
        'a version $version preset has ${layout.length} characters, '
        '$code has ${code.length}',
      );
    }
    final indices = <String, int>{};
    var at = 1;
    for (final (:digits, :fields) in layout.segments) {
      var bits = 0;
      for (var i = at; i < at + digits; i++) {
        final digit = _base62.indexOf(code[i]);
        if (digit < 0) {
          throw PresetError(
            '${code[i]} at position ${i + 1}: expected a base62 digit '
            '(0-9, A-Z, a-z)',
          );
        }
        bits = bits * 62 + digit;
      }
      at += digits;
      for (final field in fields) {
        final index = bits % field.size;
        bits ~/= field.size;
        if (index >= field.count) {
          throw PresetError(
            '${field.name}: unknown value $index in version $version '
            '(${field.count} known). A newer fliin may know it',
          );
        }
        indices[field.name] = index;
      }
      if (bits != 0) {
        throw PresetError(
          '$code has bits beyond the last field of version $version',
        );
      }
    }
    return Preset.fromIndices(indices);
  }

  /// Le préréglage dont chaque champ a l'indice de [indices] (les clés de
  /// [Preset.indices] ; un champ absent est à son défaut, 0 ; `brand` est
  /// la couleur `0xRRGGBB`). Lève une [PresetError] sur un champ inconnu,
  /// un indice hors de sa liste, ou une couleur de marque sans la primaire
  /// `custom`.
  factory Preset.fromIndices(Map<String, int> indices) {
    final fields = _layouts.values.last.segments.expand((s) => s.fields);
    for (final name in indices.keys) {
      if (!fields.any((field) => field.name == name)) {
        throw PresetError('unknown field $name');
      }
    }
    int at(String name) {
      final field = fields.firstWhere((field) => field.name == name);
      final index = indices[name] ?? 0;
      if (index < 0 || index >= field.count) {
        throw PresetError(
          '$name: unknown value $index (${field.count} known). A newer '
          'fliin may know it',
        );
      }
      return index;
    }

    // Dans l'ordre des champs : le premier indice refusé est celui que le
    // décodage rencontre d'abord, du bit 0 vers le haut.
    for (final field in fields) {
      at(field.name);
    }
    final primary = PresetPrimary.values[at('primary')];
    if (primary != PresetPrimary.custom && at('brand') != 0) {
      throw const PresetError(
        'brand: a brand color only goes with the custom primary',
      );
    }
    return Preset(
      base: PresetBase.values[at('base')],
      primary: primary,
      body: at('body') == 0 ? null : PresetFamily.values[at('body') - 1],
      heading: at('heading') == 0
          ? null
          : PresetFamily.values[at('heading') - 1],
      radius: PresetRadius.values[at('radius')],
      spacing: PresetSpacing.values[at('spacing')],
      shadow: PresetShadow.values[at('shadow')],
      button: presetButtons[at('button')],
      icons: PresetIcons.values[at('icons')],
      menu: PresetMenu.values[at('menu')],
      cards: PresetCards.values[at('cards')],
      border: PresetBorder.values[at('border')],
      text: PresetTextSize.values[at('text')],
      motion: PresetMotion.values[at('motion')],
      brand: primary == PresetPrimary.custom ? Rgb8(at('brand')) : null,
    );
  }

  final PresetBase base;
  final PresetPrimary primary;

  /// La police du texte ; nulle, celle de la plateforme.
  final PresetFamily? body;

  /// La police des titres ; nulle, celle du texte.
  final PresetFamily? heading;
  final PresetRadius radius;
  final PresetSpacing spacing;
  final PresetShadow shadow;
  final ButtonShape button;
  final PresetIcons icons;
  final PresetMenu menu;
  final PresetCards cards;
  final PresetBorder border;
  final PresetTextSize text;
  final PresetMotion motion;

  /// La couleur de marque de la primaire [PresetPrimary.custom] ; ignorée
  /// sous une autre primaire, noire si elle manque.
  final Rgb8? brand;

  /// La couleur que le solveur reçoit pour la primaire, avant ajustement.
  Rgb8 get primaryColor => switch (primary.hex) {
    final hex? => Rgb8.parse(hex),
    null => brand ?? const Rgb8(0),
  };

  /// Vrai quand aucun réglage ne touche aux couleurs : base et primaire du
  /// registre, menus neutres. Les couleurs du registre restent alors telles
  /// quelles, exceptions déclarées comprises.
  bool get exactColors =>
      base == PresetBase.sand &&
      primary == PresetPrimary.blue &&
      menu == PresetMenu.standard;

  /// Les champs dans l'ordre du code, chacun avec son indice ; `brand` est
  /// la couleur `0xRRGGBB` de la primaire `custom`, 0 sinon.
  Map<String, int> get indices => {
    'base': base.index,
    'primary': primary.index,
    'body': body == null ? 0 : body!.index + 1,
    'heading': heading == null ? 0 : heading!.index + 1,
    'radius': radius.index,
    'spacing': spacing.index,
    'shadow': shadow.index,
    'button': presetButtons.indexOf(button),
    'icons': icons.index,
    'menu': menu.index,
    'cards': cards.index,
    'border': border.index,
    'text': text.index,
    'motion': motion.index,
    'brand': primary == PresetPrimary.custom
        ? (brand ?? const Rgb8(0)).value
        : 0,
  };

  /// Le code de ce préréglage, l'inverse de [Preset.decode].
  String encode() {
    final values = indices;
    final layout = _layouts.entries.firstWhere((entry) {
      final fields = entry.value.segments.expand((s) => s.fields);
      return values.entries.every(
        (value) => switch (fields.where((f) => f.name == value.key).toList()) {
          [final field] => value.value < field.count,
          _ => value.value == 0,
        },
      );
    });
    final out = StringBuffer(layout.key);
    for (final (:digits, :fields) in layout.value.segments) {
      var bits = 0;
      for (final field in fields.reversed) {
        bits = bits * field.size + values[field.name]!;
      }
      final chunk = List.filled(digits, '0');
      for (var i = digits - 1; i >= 0; i--) {
        chunk[i] = _base62[bits % 62];
        bits ~/= 62;
      }
      out.writeAll(chunk);
    }
    return '$out';
  }

  /// La demande au solveur, sur des jetons déjà remis au thème livré
  /// [defaults] : les échelles se calculent depuis ses valeurs, jamais
  /// depuis le fichier de l'app, pour que deux passages donnent le même
  /// résultat et qu'une clé ajoutée par l'app ne bouge pas.
  ThemeRequest requestFor(Object? defaults) {
    final border = _dimension(defaults, ['size', 'border']);
    return ThemeRequest(
      primary: exactColors ? null : toOklch(primaryColor),
      neutral: exactColors ? null : base.tone,
      button: button,
      font: switch (body) {
        final family? => NamedFont(family.family),
        null => const SystemFont(),
      },
      // Sans police de titres, rien à écrire : les jetons remis au thème
      // livré ont déjà `inherit`.
      headingFont: switch (heading) {
        final family? => NamedFont(family.family),
        null => null,
      },
      dimensions: {
        for (final (name, px) in _dimensions(defaults, ['shape', 'radius']))
          'shape.radius.$name': switch (name) {
            // Le bouton `rounded` du registre est déjà une capsule à sa
            // taille : plus grand ne changerait rien et ferait deux codes
            // pour un même rendu (ADR 0016 §3.5).
            'button' ||
            'buttonLarge' => math.min((px * radius.scale).roundToDouble(), px),
            _ => (px * radius.scale).roundToDouble(),
          },
        for (final (name, px) in _dimensions(defaults, ['space']))
          'space.$name': (px * spacing.scale).roundToDouble(),
        for (final name in presetSpacingSizes)
          if (_dimension(defaults, ['size', name]) case final px?)
            'size.$name': (px * spacing.scale).roundToDouble(),
        if (border != null) ...{
          'size.border': border * this.border.scale,
          if (_dimension(defaults, ['size', 'surfaceBorder']) != null)
            'size.surfaceBorder': cards == PresetCards.outlined
                ? border * this.border.scale
                : 0,
        },
        for (final platform in FliinTokens.platforms)
          for (final role in _keys(defaults, ['typography', 'scale', platform]))
            for (final property in ['size', 'lineHeight'])
              if (_dimension(defaults, [
                    'typography',
                    'scale',
                    platform,
                    role,
                    property,
                  ])
                  case final px?)
                'typography.scale.$platform.$role.$property': (px * text.scale)
                    .roundToDouble(),
        for (final (name, ms) in _dimensions(defaults, ['motion', 'duration']))
          'motion.duration.$name': (ms * motion.scale).roundToDouble(),
      },
      numbers: {
        for (final name in _keys(defaults, ['motion', 'spring']))
          if (_number(defaults, ['motion', 'spring', name, 'stiffness'])
              case final stiffness?)
            'motion.spring.$name.stiffness': _tenth(
              stiffness / (motion.scale * motion.scale),
            ),
      },
      flatShadows: shadow == PresetShadow.none,
      flatShadowNames: {if (cards == PresetCards.outlined) 'surface'},
    );
  }

  /// Un préréglage tiré par [random] parmi ceux que le mélange propose :
  /// chaque champ au hasard, la primaire parmi celles qui ne se confondent
  /// pas avec `danger`. Le contraste de chacun est prouvé
  /// par `preset_contrast_test.dart`.
  static Preset shuffle(math.Random random) {
    T pick<T>(List<T> values) => values[random.nextInt(values.length)];
    return Preset(
      base: pick(PresetBase.values),
      primary: pick([
        for (final primary in PresetPrimary.values)
          if (primary.shuffled) primary,
      ]),
      body: pick([null, ...PresetFamily.values]),
      heading: pick([null, ...PresetFamily.values]),
      radius: pick(PresetRadius.values),
      spacing: pick(PresetSpacing.values),
      shadow: pick(PresetShadow.values),
      button: pick(presetButtons),
      menu: pick(PresetMenu.values),
      cards: pick(PresetCards.values),
      border: pick(PresetBorder.values),
      text: pick(PresetTextSize.values),
      motion: pick(PresetMotion.values),
    );
  }

  /// Chaque champ par son nom, pour l'afficher (`fliin theme --preset`).
  Map<String, String> get describe => {
    'base': base.name,
    'primary': primary == PresetPrimary.custom
        ? 'custom ${primaryColor.hex}'
        : primary.name,
    'body': body?.family ?? 'system',
    'heading': heading?.family ?? 'inherit',
    'radius': radius.name,
    'spacing': spacing.name,
    'shadow': shadow.name,
    'button': button.name,
    'icons': icons.name,
    'menu': menu.name,
    'cards': cards.name,
    'border': border.name,
    'text': text.name,
    'motion': motion.name,
  };

  @override
  bool operator ==(Object other) =>
      other is Preset && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;

  @override
  String toString() => encode();
}

/// La version que ce fliin écrit et lit.
const presetVersion = 'c';

/// La longueur d'un code de chaque version.
final presetLengths = {
  for (final MapEntry(:key, :value) in _layouts.entries) key: value.length,
};

/// Vrai pour un code des versions `a` et `b`, celles du thème d'avant
/// `core` 0.2.0 (ADR 0019 §5) : refusé en argument, ignoré avec un
/// avertissement quand `fliin.yaml` le garde.
bool isRetiredPresetCode(String code) =>
    code.startsWith('a') || code.startsWith('b');

/// Ce qu'on dit d'un code de la version [version], retirée.
String retiredPresetMessage(String version) =>
    'version $version: these codes describe the theme from before core '
    '0.2.0, which this fliin no longer ships. Make the code again on the '
    'theme page';

/// Les formes du bouton dans l'ordre du code : `pill`, celle du registre,
/// d'abord.
const presetButtons = [
  ButtonShape.pill,
  ButtonShape.rounded,
  ButtonShape.square,
];

const _base62 =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

typedef _Field = ({String name, int bits, int count});

/// Les champs de la version c, du bit 0 vers le haut, en deux blocs : six
/// chiffres pour ceux que la version a avait déjà (35 bits), puis sept pour
/// les réglages ajoutés et la couleur de marque (34 bits sur 41). Les
/// versions a et b avaient les mêmes champs, sur le thème d'avant et avec un
/// autre ordre des valeurs (ADR 0019 §5). On n'ordonne jamais autrement une
/// liste de valeurs et on n'ajoute qu'à la fin ; un champ de plus fait une
/// version de plus (ADR 0016 §4.2). Chaque bloc reste sous les 53 bits d'un
/// entier exact en JavaScript : le même code Dart tourne dans la VM et dans
/// le navigateur. Le code multiplie et divise au lieu de décaler : en
/// JavaScript, un décalage tronque à 32 bits.
final _layouts =
    <
      String,
      ({int length, List<({int digits, List<_Field> fields})> segments})
    >{
      'c': (
        length: 14,
        segments: [
          (
            digits: 6,
            fields: [
              (name: 'base', bits: 4, count: PresetBase.values.length),
              (name: 'primary', bits: 6, count: PresetPrimary.values.length),
              (name: 'body', bits: 6, count: PresetFamily.values.length + 1),
              (name: 'heading', bits: 6, count: PresetFamily.values.length + 1),
              (name: 'radius', bits: 3, count: PresetRadius.values.length),
              (name: 'spacing', bits: 2, count: PresetSpacing.values.length),
              (name: 'shadow', bits: 2, count: PresetShadow.values.length),
              (name: 'button', bits: 2, count: presetButtons.length),
              (name: 'icons', bits: 4, count: PresetIcons.values.length),
            ],
          ),
          (
            digits: 7,
            fields: [
              (name: 'menu', bits: 2, count: PresetMenu.values.length),
              (name: 'cards', bits: 2, count: PresetCards.values.length),
              (name: 'border', bits: 2, count: PresetBorder.values.length),
              (name: 'text', bits: 2, count: PresetTextSize.values.length),
              (name: 'motion', bits: 2, count: PresetMotion.values.length),
              (name: 'brand', bits: 24, count: 1 << 24),
            ],
          ),
        ],
      ),
    };

/// Un code de préréglage refusé.
final class PresetError implements Exception {
  const PresetError(this.message);

  final String message;

  @override
  String toString() => 'preset: $message';
}

/// Les chemins qu'un préréglage possède : il les remet au thème livré avant
/// de régler, et ne touche à rien d'autre (ADR 0016 §4.4). La taille et la
/// hauteur de ligne de chaque rôle de `typography.scale` et la raideur de
/// chaque ressort de `motion.spring` s'y ajoutent, d'après les jetons livrés
/// ([presetPathsIn]).
final presetPaths = [
  ['color'],
  ['shape', 'radius'],
  ['shape', 'button'],
  ['space'],
  for (final name in presetSpacingSizes) ['size', name],
  ['size', 'border'],
  ['size', 'surfaceBorder'],
  ['shadow'],
  ['typography', 'family'],
  ['typography', 'headingFamily'],
  ['motion', 'duration'],
];

/// [presetPaths], la taille et la hauteur de ligne de chaque rôle de texte,
/// et la raideur de chaque ressort que [defaults] déclare : la graisse,
/// l'approche, l'amortissement et la masse restent à l'app.
List<List<String>> presetPathsIn(Object? defaults) => [
  ...presetPaths,
  for (final platform in FliinTokens.platforms)
    for (final role in _keys(defaults, ['typography', 'scale', platform]))
      for (final property in ['size', 'lineHeight'])
        ['typography', 'scale', platform, role, property],
  for (final name in _keys(defaults, ['motion', 'spring']))
    ['motion', 'spring', name, 'stiffness'],
];

/// Les marges et écarts de `size` que l'échelle d'espacement suit avec
/// `space` (ADR 0016 §3.6) : celles d'une surface, d'un bouton, d'un champ
/// et du code. Les hauteurs de contrôle, les cibles tactiles et les marges
/// de liste de la densité n'y sont pas.
const presetSpacingSizes = [
  'surfacePadding',
  'buttonPaddingSm',
  'buttonPaddingMd',
  'buttonPaddingLg',
  'buttonGapSm',
  'buttonGapMd',
  'buttonGapLg',
  'fieldInset',
  'codePaddingX',
  'codePaddingY',
];

extension on _Field {
  int get size => 1 << bits;
}

/// Un nombre au dixième, entier quand il tombe juste : la VM et JavaScript
/// l'écrivent alors pareil (`714.3`, `2000`).
num _tenth(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}

/// Les noms des jetons et groupes sous [segments] dans [json].
List<String> _keys(Object? json, List<String> segments) {
  try {
    return switch (valueAt(json, jsonPointer(segments))) {
      final Map<String, Object?> group => [
        for (final key in group.keys)
          if (!key.startsWith(r'$')) key,
      ],
      _ => const [],
    };
  } on JsonPatchError {
    return const [];
  }
}

double? _number(Object? json, List<String> segments) {
  try {
    return switch (valueAt(json, jsonPointer([...segments, r'$value']))) {
      final num value => value.toDouble(),
      _ => null,
    };
  } on JsonPatchError {
    return null;
  }
}

/// Les dimensions en px des jetons sous [segments] dans [json], par nom.
List<(String, double)> _dimensions(Object? json, List<String> segments) {
  final Object? group;
  try {
    group = valueAt(json, jsonPointer(segments));
  } on JsonPatchError {
    return const [];
  }
  return [
    if (group is Map<String, Object?>)
      for (final name in group.keys)
        if (!name.startsWith(r'$'))
          if (_dimension(json, [...segments, name]) case final px?) (name, px),
  ];
}

double? _dimension(Object? json, List<String> segments) {
  try {
    return switch (valueAt(
      json,
      jsonPointer([...segments, r'$value', 'value']),
    )) {
      final num px => px.toDouble(),
      _ => null,
    };
  } on JsonPatchError {
    return null;
  }
}

/// [preset] appliqué au fichier de jetons [current], décodé : les chemins de
/// [presetPathsIn] repartent de [defaults], le fichier livré par le registre
/// pour la version de `core` installée, puis passent par le solveur. Le
/// patch d'un [ThemeSolved] mène [current] au résultat ; il ne garde par
/// `test` que les valeurs qu'il remplace, puisque le résultat ne dépend pas
/// de ce que [current] avait sous ces chemins. Lève une `TokenError` comme
/// [solveTheme], et une [PresetError] si [defaults] vient d'un `core` qui ne
/// connaît pas un réglage nommé par [preset].
ThemeOutcome applyPreset(Object? current, Object? defaults, Preset preset) {
  if (preset.heading != null) {
    try {
      valueAt(defaults, jsonPointer(['typography', 'headingFamily']));
    } on JsonPatchError {
      throw const PresetError(
        'this preset names a heading font, which the tokens shipped with '
        'this core do not know. core 0.1.2 or later is required. Run fliin '
        'update core',
      );
    }
  }
  if (preset.cards == PresetCards.outlined &&
      _dimension(defaults, ['size', 'surfaceBorder']) == null) {
    throw const PresetError(
      'this preset draws flat cards with an outline, which the tokens '
      'shipped with this core do not know. core 0.1.3 or later is '
      'required. Run fliin update core',
    );
  }
  final reset = _tinted(_reset(current, defaults), preset);
  switch (solveTheme(reset, preset.requestFor(defaults))) {
    case final Unsatisfiable outcome:
      return outcome;
    case ThemeSolved(:final patch, :final contrast, :final clashes):
      final result = applyJsonPatch(reset, patch);
      return ThemeSolved(
        [
          for (final segments in presetPathsIn(defaults))
            ..._diff(current, result, segments),
        ],
        contrast,
        clashes: clashes,
      );
  }
}

/// Une retouche à la main que le patch d'un préréglage écrase : la valeur
/// [before] du fichier à [path], qui devient [after].
typedef PresetOverwrite = ({String path, Object? before, Object? after});

/// Les retouches de [current] que [patch] (de [applyPreset]) écrase : sous
/// les chemins du préréglage, une valeur qui n'est pas celle que
/// [previous], le préréglage appliqué la fois d'avant (nul : le thème
/// livré), aurait écrite depuis [defaults].
List<PresetOverwrite> presetOverwrites(
  Object? current,
  Object? defaults,
  Preset? previous,
  List<PatchOp> patch,
) {
  Object? expected;
  try {
    expected = switch (applyPreset(
      current,
      defaults,
      previous ?? const Preset(),
    )) {
      ThemeSolved(:final patch) => applyJsonPatch(current, patch),
      Unsatisfiable() => _reset(current, defaults),
    };
  } on Exception {
    expected = _reset(current, defaults);
  }
  Object? at(Object? json, String path) {
    try {
      return valueAt(json, path);
    } on JsonPatchError {
      return null;
    }
  }

  return [
    for (final op in patch)
      if (op.op == PatchOperation.replace &&
          !jsonEquals(at(current, op.path), at(expected, op.path)))
        (path: op.path, before: at(current, op.path), after: op.value),
  ];
}

/// [current] dont chaque valeur sous [presetPathsIn] que [defaults] écrit
/// reprend celle de [defaults]. Ce que [current] a de plus (un rôle ajouté
/// par l'app) reste.
Object? _reset(Object? current, Object? defaults) {
  final copy = jsonDecode(jsonEncode(current));
  for (final segments in presetPathsIn(defaults)) {
    final pointer = jsonPointer(segments);
    final Object? fallback;
    try {
      fallback = valueAt(defaults, pointer);
    } on JsonPatchError {
      continue;
    }
    _merge(copy, segments, fallback);
  }
  return copy;
}

void _merge(Object? document, List<String> segments, Object? value) {
  var node = document;
  for (final segment in segments.take(segments.length - 1)) {
    if (node is! Map<String, Object?>) return;
    node = node[segment];
  }
  if (node is! Map<String, Object?>) return;
  final key = segments.last;
  final existing = node[key];
  if (existing is Map<String, Object?> && value is Map<String, Object?>) {
    for (final MapEntry(key: child, value: inner) in value.entries) {
      _merge(existing, [child], inner);
    }
  } else {
    node[key] = jsonDecode(jsonEncode(value));
  }
}

/// `test` puis `replace` sur chaque valeur de [after] sous [segments] qui
/// diffère de [before], `add` sur celles que [before] n'a pas.
List<PatchOp> _diff(Object? before, Object? after, List<String> segments) {
  final pointer = jsonPointer(segments);
  final Object? next;
  try {
    next = valueAt(after, pointer);
  } on JsonPatchError {
    return const [];
  }
  final Object? previous;
  try {
    previous = valueAt(before, pointer);
  } on JsonPatchError {
    return [(op: PatchOperation.add, path: pointer, value: next)];
  }
  if (jsonEquals(previous, next)) return const [];
  if (previous is Map<String, Object?> && next is Map<String, Object?>) {
    return [
      for (final key in next.keys) ..._diff(before, after, [...segments, key]),
    ];
  }
  return [
    (op: PatchOperation.test, path: pointer, value: previous),
    (op: PatchOperation.replace, path: pointer, value: next),
  ];
}

/// [json] dont `surfaceOverlay`, clair et sombre, est teinté de la primaire
/// de [preset] quand ses menus le sont (ADR 0016 §3.11) : une chroma faible
/// à la teinte de la primaire, à la clarté du neutre qu'il remplace. Le
/// solveur mesure ensuite chaque paire posée dessus, et peut en déplacer la
/// clarté.
Object? _tinted(Object? json, Preset preset) {
  if (preset.menu != PresetMenu.tinted) return json;
  final brand = toOklch(preset.primaryColor);
  // La teinte d'une marque presque grise est du bruit (le noir tombait sur
  // un rose) : les menus prennent alors celle de la base, à sa chroma, et
  // restent gris sur une base sans teinte (`sand`).
  final tone = preset.base.tone;
  final achromatic = brand.c < 0.02;
  final hue = achromatic ? tone.hue ?? 0 : brand.h;
  final chroma = !achromatic
      ? 1
      : tone.hue == null
      ? 0
      : math.min(tone.chromaFactor, 1);
  final dark = toOklch(tone.step('790'));
  Map<String, Object?> color(Oklch lch) {
    final rgb = fromOklch((l: lch.l, c: lch.c * chroma, h: lch.h)).color;
    return {
      'colorSpace': 'srgb',
      'components': [
        for (final channel in [rgb.r, rgb.g, rgb.b])
          double.parse((channel / 255).toStringAsFixed(4)),
      ],
      'hex': rgb.hex,
    };
  }

  return applyJsonPatch(json, [
    // Comme sous une marque, le thème est conforme sans exception : celles du
    // registre mesurent des paires que la teinte déplace.
    (
      op: PatchOperation.replace,
      path: jsonPointer([
        'color',
        r'$extensions',
        FliinTokens.contrastExceptionsExtension,
      ]),
      value: const <Object?>[],
    ),
    (
      op: PatchOperation.replace,
      path: jsonPointer(['color', 'light', 'surfaceOverlay', r'$value']),
      value: color((l: 0.975, c: 0.016, h: hue)),
    ),
    (
      op: PatchOperation.replace,
      path: jsonPointer(['color', 'dark', 'surfaceOverlay', r'$value']),
      value: color((l: dark.l + 0.035, c: 0.03, h: hue)),
    ),
  ]);
}

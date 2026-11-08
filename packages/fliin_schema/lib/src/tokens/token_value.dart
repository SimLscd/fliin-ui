import 'token_error.dart';

/// Les 13 types du Format 2025.10 (§8 et l'énumération du schéma). Aucun
/// type `string`, aucun ressort.
enum TokenType {
  color,
  dimension,
  fontFamily,
  fontWeight,
  duration,
  cubicBezier,
  number,
  strokeStyle,
  border,
  transition,
  shadow,
  gradient,
  typography;

  /// Un type composite accepte un alias `{…}` ou un `$ref` à la place de
  /// chacune de ses propriétés (Format §9). Un type simple ne l'accepte que
  /// pour sa valeur entière.
  bool get isComposite => switch (this) {
    strokeStyle ||
    border ||
    transition ||
    shadow ||
    gradient ||
    typography => true,
    color ||
    dimension ||
    fontFamily ||
    fontWeight ||
    duration ||
    cubicBezier ||
    number => false,
  };

  static TokenType? parse(String text) {
    for (final type in values) {
      if (type.name == text) return type;
    }
    return null;
  }
}

/// La plage d'une composante de couleur (module Color §4, schéma
/// `values/color.json`).
enum ComponentRange {
  zeroToOne,
  hue,
  percentage,
  chroma,
  unbounded;

  bool contains(double value) => switch (this) {
    zeroToOne => value >= 0 && value <= 1,
    hue => value >= 0 && value < 360,
    percentage => value >= 0 && value <= 100,
    chroma => value >= 0,
    unbounded => true,
  };

  String get description => switch (this) {
    zeroToOne => 'between 0 and 1',
    hue => 'from 0 included to 360 excluded',
    percentage => 'between 0 and 100',
    chroma => 'zero or positive',
    unbounded => 'a number',
  };
}

/// Les espaces du module Color, chacun avec les plages de ses trois
/// composantes.
enum ColorSpace {
  srgb('srgb', _rgb),
  srgbLinear('srgb-linear', _rgb),
  hsl('hsl', [
    ComponentRange.hue,
    ComponentRange.percentage,
    ComponentRange.percentage,
  ]),
  hwb('hwb', [
    ComponentRange.hue,
    ComponentRange.percentage,
    ComponentRange.percentage,
  ]),
  lab('lab', [
    ComponentRange.percentage,
    ComponentRange.unbounded,
    ComponentRange.unbounded,
  ]),
  lch('lch', [
    ComponentRange.percentage,
    ComponentRange.chroma,
    ComponentRange.hue,
  ]),
  oklab('oklab', [
    ComponentRange.zeroToOne,
    ComponentRange.unbounded,
    ComponentRange.unbounded,
  ]),
  oklch('oklch', [
    ComponentRange.zeroToOne,
    ComponentRange.chroma,
    ComponentRange.hue,
  ]),
  displayP3('display-p3', _rgb),
  a98Rgb('a98-rgb', _rgb),
  prophotoRgb('prophoto-rgb', _rgb),
  rec2020('rec2020', _rgb),
  xyzD65('xyz-d65', _rgb),
  xyzD50('xyz-d50', _rgb);

  const ColorSpace(this.wire, this.ranges);

  final String wire;
  final List<ComponentRange> ranges;

  static const _rgb = [
    ComponentRange.zeroToOne,
    ComponentRange.zeroToOne,
    ComponentRange.zeroToOne,
  ];

  static ColorSpace? parse(String text) {
    for (final space in values) {
      if (space.wire == text) return space;
    }
    return null;
  }
}

/// Une composante : un nombre dans la plage de son espace, ou `none`.
sealed class ColorComponent {
  const ColorComponent();
}

final class NumericComponent extends ColorComponent {
  const NumericComponent(this.value);

  final double value;
}

final class NoneComponent extends ColorComponent {
  const NoneComponent();
}

/// Une valeur résolue : plus aucune référence, type connu.
sealed class TokenValue {
  const TokenValue();

  TokenType get type;
}

final class ColorValue extends TokenValue {
  const ColorValue({
    required this.colorSpace,
    required this.components,
    this.alpha = 1,
    this.hex,
  });

  final ColorSpace colorSpace;
  final List<ColorComponent> components;
  final double alpha;

  /// Repli `#RRGGBB`, optionnel.
  final String? hex;

  @override
  TokenType get type => TokenType.color;

  /// `0xAARRGGBB`, composantes arrondies sur 8 bits. Lève
  /// [UnsupportedColorSpace] hors sRGB, et [InvalidTokenValue] si une
  /// composante est `none`. La résolution a déjà refusé un [hex] qui
  /// contredit les composantes.
  int argb(String at) {
    if (colorSpace != ColorSpace.srgb) {
      throw UnsupportedColorSpace(at, colorSpace.wire);
    }
    final channels = [
      for (final component in components)
        switch (component) {
          NumericComponent(:final value) => (value * 255).round(),
          NoneComponent() => throw InvalidTokenValue(
            at,
            'a none component has no Color equivalent',
          ),
        },
    ];
    final rgb = (channels[0] << 16) | (channels[1] << 8) | channels[2];
    return ((alpha * 255).round() << 24) | rgb;
  }
}

enum DimensionUnit { px, rem }

final class DimensionValue extends TokenValue {
  const DimensionValue(this.value, this.unit);

  final double value;
  final DimensionUnit unit;

  @override
  TokenType get type => TokenType.dimension;
}

final class FontFamilyValue extends TokenValue {
  const FontFamilyValue(this.names);

  /// De la plus à la moins préférée.
  final List<String> names;

  @override
  TokenType get type => TokenType.fontFamily;
}

final class FontWeightValue extends TokenValue {
  const FontWeightValue(this.weight);

  /// Entre 1 et 1000 ; un mot-clé vaut son nombre (Format §8.4).
  final double weight;

  @override
  TokenType get type => TokenType.fontWeight;

  static const keywords = {
    'thin': 100,
    'hairline': 100,
    'extra-light': 200,
    'ultra-light': 200,
    'light': 300,
    'normal': 400,
    'regular': 400,
    'book': 400,
    'medium': 500,
    'semi-bold': 600,
    'demi-bold': 600,
    'bold': 700,
    'extra-bold': 800,
    'ultra-bold': 800,
    'black': 900,
    'heavy': 900,
    'extra-black': 950,
    'ultra-black': 950,
  };
}

enum DurationUnit { ms, s }

final class DurationValue extends TokenValue {
  const DurationValue(this.value, this.unit);

  final double value;
  final DurationUnit unit;

  double get milliseconds => switch (unit) {
    DurationUnit.ms => value,
    DurationUnit.s => value * 1000,
  };

  @override
  TokenType get type => TokenType.duration;
}

final class CubicBezierValue extends TokenValue {
  const CubicBezierValue(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  TokenType get type => TokenType.cubicBezier;
}

final class NumberValue extends TokenValue {
  const NumberValue(this.value);

  final double value;

  @override
  TokenType get type => TokenType.number;
}

enum StrokeStyleKeyword {
  solid,
  dashed,
  dotted,
  double,
  groove,
  ridge,
  outset,
  inset,
}

enum LineCap { round, butt, square }

sealed class StrokeStyleValue extends TokenValue {
  const StrokeStyleValue();

  @override
  TokenType get type => TokenType.strokeStyle;
}

final class StrokeStyleName extends StrokeStyleValue {
  const StrokeStyleName(this.keyword);

  final StrokeStyleKeyword keyword;
}

final class StrokeStyleDash extends StrokeStyleValue {
  const StrokeStyleDash({required this.dashArray, required this.lineCap});

  final List<DimensionValue> dashArray;
  final LineCap lineCap;
}

final class BorderValue extends TokenValue {
  const BorderValue({
    required this.color,
    required this.width,
    required this.style,
  });

  final ColorValue color;
  final DimensionValue width;
  final StrokeStyleValue style;

  @override
  TokenType get type => TokenType.border;
}

final class TransitionValue extends TokenValue {
  const TransitionValue({
    required this.duration,
    required this.delay,
    required this.timingFunction,
  });

  final DurationValue duration;
  final DurationValue delay;
  final CubicBezierValue timingFunction;

  @override
  TokenType get type => TokenType.transition;
}

final class ShadowLayer {
  const ShadowLayer({
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.blur,
    required this.spread,
    this.inset = false,
  });

  final ColorValue color;
  final DimensionValue offsetX;
  final DimensionValue offsetY;
  final DimensionValue blur;
  final DimensionValue spread;
  final bool inset;
}

final class ShadowValue extends TokenValue {
  const ShadowValue(this.layers);

  /// Une ombre écrite comme objet donne une seule couche.
  final List<ShadowLayer> layers;

  @override
  TokenType get type => TokenType.shadow;
}

final class GradientStop {
  const GradientStop({required this.color, required this.position});

  final ColorValue color;
  final double position;
}

final class GradientValue extends TokenValue {
  const GradientValue(this.stops);

  final List<GradientStop> stops;

  @override
  TokenType get type => TokenType.gradient;
}

final class TypographyValue extends TokenValue {
  const TypographyValue({
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.lineHeight,
  });

  final FontFamilyValue fontFamily;
  final DimensionValue fontSize;
  final FontWeightValue fontWeight;
  final DimensionValue letterSpacing;

  /// Sans unité, multiple de la taille.
  final double lineHeight;

  @override
  TokenType get type => TokenType.typography;
}

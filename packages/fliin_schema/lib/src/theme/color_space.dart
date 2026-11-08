import 'dart:math' as math;

/// Une couleur sRGB opaque, 8 bits par canal : `0xRRGGBB`. C'est ce que
/// `tokens.g.dart` finit par porter, donc ce sur quoi le contraste se mesure.
extension type const Rgb8._(int value) {
  const Rgb8(int rgb) : value = rgb & 0xFFFFFF;

  Rgb8.channels(int r, int g, int b) : value = (r << 16) | (g << 8) | b;

  /// `#RRGGBB`, sinon [FormatException].
  static Rgb8 parse(String hex) => _hex.hasMatch(hex)
      ? Rgb8(int.parse(hex.substring(1), radix: 16))
      : throw FormatException('expected #RRGGBB', hex);

  /// `#RRGGBB`, sinon nul.
  static Rgb8? tryParse(String hex) => _hex.hasMatch(hex) ? parse(hex) : null;

  int get r => value >> 16 & 0xFF;
  int get g => value >> 8 & 0xFF;
  int get b => value & 0xFF;

  String get hex => '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';

  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');
}

/// OKLCH (Ottosson 2020) : clarté perceptuelle [l] de 0 à 1, chroma [c],
/// teinte [h] en degrés dans [0, 360).
typedef Oklch = ({double l, double c, double h});

Oklch toOklch(Rgb8 color) {
  final r = _linear(color.r / 255);
  final g = _linear(color.g / 255);
  final b = _linear(color.b / 255);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  final hue = math.atan2(bb, a) * 180 / math.pi;
  return (
    l: lightness,
    c: math.sqrt(a * a + bb * bb),
    h: hue < 0 ? hue + 360 : hue,
  );
}

/// La distance euclidienne dans OKLab (ΔE OK de CSS Color 4 §13.2, où une
/// différence juste perceptible vaut 0,02).
double deltaEOk(Rgb8 x, Rgb8 y) {
  final a = toOklch(x);
  final b = toOklch(y);
  double da(Oklch c) => c.c * math.cos(c.h * math.pi / 180);
  double db(Oklch c) => c.c * math.sin(c.h * math.pi / 180);
  final dl = a.l - b.l;
  final dA = da(a) - da(b);
  final dB = db(a) - db(b);
  return math.sqrt(dl * dl + dA * dA + dB * dB);
}

/// La couleur sRGB la plus proche de [color] à clarté et teinte égales :
/// [color] elle-même si elle est dans le gamut sRGB, sinon la plus grande
/// chroma qui y tient, trouvée par dichotomie (la « réduction de chroma » de
/// CSS Color 4 §13.2, sans son repli par distance). [chroma] est la chroma
/// gardée, avant l'arrondi sur 8 bits.
({Rgb8 color, double chroma}) fromOklch(Oklch color) {
  final l = color.l.clamp(0.0, 1.0);
  final h = color.h * math.pi / 180;
  final cos = math.cos(h);
  final sin = math.sin(h);
  _Linear at(double c) => _oklabToLinear(l, c * cos, c * sin);
  var chroma = color.c;
  var rgb = at(chroma);
  if (!_inGamut(rgb)) {
    var low = 0.0;
    var high = chroma;
    for (var i = 0; i < 32; i++) {
      final mid = (low + high) / 2;
      if (_inGamut(at(mid))) {
        low = mid;
      } else {
        high = mid;
      }
    }
    chroma = low;
    rgb = at(chroma);
  }
  int channel(double v) => (_gamma(v.clamp(0.0, 1.0)) * 255).round();
  return (
    color: Rgb8.channels(channel(rgb.r), channel(rgb.g), channel(rgb.b)),
    chroma: chroma,
  );
}

/// Ratio de contraste WCAG 2, avec le seuil 0,03928 de la formule que
/// `flutter/registry/test/tokens_test.dart` applique aux jetons commités.
double contrastRatio(Rgb8 a, Rgb8 b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

final _luminances = <int, double>{};

double relativeLuminance(Rgb8 color) =>
    _luminances[color.value] ??= _relativeLuminance(color);

double _relativeLuminance(Rgb8 color) {
  double channel(int v) {
    final c = v / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// sRGB linéaire, avant gamma ; hors de [0, 1] hors du gamut.
typedef _Linear = ({double r, double g, double b});

_Linear _oklabToLinear(double l, double a, double b) {
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
  final ll = l_ * l_ * l_;
  final mm = m_ * m_ * m_;
  final ss = s_ * s_ * s_;
  return (
    r: 4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
    g: -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
    b: -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss,
  );
}

/// Une tolérance d'arrondi : le blanc et le noir, à chroma nulle, sortent de
/// la conversion à 1e-10 près de leurs bornes.
bool _inGamut(_Linear rgb) =>
    _inUnit(rgb.r) && _inUnit(rgb.g) && _inUnit(rgb.b);

bool _inUnit(double v) => v >= -1e-7 && v <= 1 + 1e-7;

double _linear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _gamma(double c) =>
    c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;

double _cbrt(double v) =>
    v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

/// La couleur que l'œil lit sous des couches posées les unes sur les autres :
/// [layers] du haut vers le bas, en `0xAARRGGBB`, la dernière pleine.
Rgb8 composite(List<int> layers) {
  var (r, g, b) = (0.0, 0.0, 0.0);
  for (final argb in layers.reversed) {
    final alpha = (argb >>> 24) / 255;
    r = (argb >> 16 & 0xFF) * alpha + r * (1 - alpha);
    g = (argb >> 8 & 0xFF) * alpha + g * (1 - alpha);
    b = (argb & 0xFF) * alpha + b * (1 - alpha);
  }
  return Rgb8.channels(r.round(), g.round(), b.round());
}

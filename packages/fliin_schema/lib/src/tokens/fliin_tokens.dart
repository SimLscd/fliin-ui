import 'dart:convert';

import '../theme/color_space.dart';

import 'token_error.dart';
import 'token_resolver.dart';
import 'token_value.dart';

/// Ce que `fliin.tokens.json` doit contenir pour produire `tokens.g.dart`
/// (DESIGN.md §2.1 à §2.5, ADR 0003). Les chemins sont fixes ; les rôles de
/// couleur, les espacements, les tailles, les ressorts, les courbes, les
/// durées et les rôles typographiques sont lus dans l'ordre du fichier, les
/// noms requis par `core/` devant être présents.
final class FliinTokens {
  const FliinTokens({
    required this.roles,
    required this.light,
    required this.dark,
    required this.contrastPairs,
    required this.button,
    required this.radius,
    required this.space,
    required this.size,
    required this.springs,
    required this.curves,
    required this.durations,
    required this.pressedScale,
    required this.typography,
    required this.fontFamily,
    this.headingFamily = const {'ios': null, 'android': null},
    required this.monospaceFamily,
    required this.fontWeights,
    required this.shadows,
    this.contrastExceptions = const [],
    this.notice,
  });

  /// Lève une [TokenError] (le plus souvent [MissingFliinToken]) si un
  /// jeton attendu manque, n'a pas le type voulu, ou si `color.light` et
  /// `color.dark` n'ont pas les mêmes rôles (règle 8 de l'ADR 0001).
  factory FliinTokens.read(ResolvedTokens tokens) => _Reader(tokens).read();

  /// Les rôles de `color.light`, dans l'ordre du fichier.
  final List<String> roles;

  /// Par rôle, `0xAARRGGBB`.
  final Map<String, int> light;
  final Map<String, int> dark;
  final List<ContrastPair> contrastPairs;
  final ButtonShape button;

  /// `control`, `card`, `sheet`, en px.
  final Map<String, double> radius;
  final Map<String, double> space;
  final Map<String, double> size;
  final Map<String, Spring> springs;
  final Map<String, CubicBezierValue> curves;
  final Map<String, DurationValue> durations;
  final double pressedScale;

  /// `ios` et `android`, chacune par rôle.
  final Map<String, Map<String, TypeStyle>> typography;

  /// `ios` et `android` : la famille nommée, ou nul pour la police système.
  final Map<String, String?> fontFamily;

  /// `ios` et `android` : la famille nommée des titres
  /// (`typography.headingFamily`), ou nul pour celle du texte. Le groupe est
  /// facultatif : absent, les titres prennent la police du texte.
  final Map<String, String?> headingFamily;

  /// `ios` et `android` : la police à chasse fixe du code
  /// (`typography.monospace`), toujours nommée.
  final Map<String, String> monospaceFamily;

  /// Les graisses de `typography.weight`, par nom, dans l'ordre du fichier.
  final Map<String, double> fontWeights;

  /// `light` et `dark`, chacune par nom d'ombre (`shadow.<apparence>`), dans
  /// l'ordre du fichier : les couches DTCG `shadow`, en px.
  final Map<String, Map<String, List<TokenShadow>>> shadows;

  /// Les paires que le thème déclare sous leur seuil, une par apparence,
  /// avec leur ratio mesuré et leur raison (ADR 0014).
  final List<ContrastException> contrastExceptions;

  /// La mention d'origine du thème (`$extensions.dev.fliin.notice` à la
  /// racine), recopiée en tête de `tokens.g.dart` ; nulle sans mention.
  final String? notice;

  static const colorRoles = [
    'surface',
    'surfaceRaised',
    'surfaceOverlay',
    'surfacePressed',
    'onSurface',
    'onSurfaceMuted',
    'border',
    'accent',
    'accentPressed',
    'onAccent',
    'disabled',
    'onDisabled',
    'focusRing',
    'danger',
    'selection',
  ];
  static const radiusNames = ['control', 'card', 'sheet'];
  static const spaceNames = ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'];
  static const sizeNames = [
    'controlCompact',
    'controlComfortable',
    'controlSpacious',
    'listPaddingCompact',
    'listPaddingComfortable',
    'listPaddingSpacious',
    'hitTargetIos',
    'hitTargetAndroid',
    'hitTargetDesktop',
    'border',
    'focusRing',
    'focusRingGap',
    'indicatorStroke',
    'iconMaxScale',
    'cursorWidth',
  ];
  static const springNames = [
    'press',
    'spatial',
    'spatialSlow',
    'release',
    'effects',
    'effectsFast',
  ];
  static const curveNames = ['standard'];
  static const durationNames = [
    'short2',
    'short3',
    'short4',
    'medium2',
    'indicatorTurn',
  ];
  static const platforms = ['ios', 'android'];
  static const appearances = ['light', 'dark'];
  static const shadowNames = ['surface', 'overlay', 'field'];
  static const fontWeightNames = ['normal', 'medium', 'semibold', 'bold'];

  /// La valeur de `typography.family.*` tant que leur source est
  /// `platform-default` : `FlTypography` ne fixe alors aucune police.
  static const platformDefaultFamily = ['system-ui', 'sans-serif'];
  static const textRoles = [
    'display',
    'title1',
    'title2',
    'title3',
    'headline',
    'body',
    'callout',
    'label',
    'footnote',
    'caption',
  ];

  /// Clés d'`$extensions` propres à Fliin (ADR 0003).
  static const contrastExtension = 'dev.fliin.contrast';
  static const contrastExceptionsExtension = 'dev.fliin.contrastExceptions';
  static const noticeExtension = 'dev.fliin.notice';
  static const buttonShapeExtension = 'dev.fliin.buttonShape';
  static const springExtension = 'dev.fliin.spring';
  static const typeStyleExtension = 'dev.fliin.typeStyle';
  static const fontFamilyExtension = 'dev.fliin.fontFamily';
}

enum ButtonShape { square, rounded, pill }

enum ContrastKind { text, ui }

/// [foreground] lu sur [background], lui-même posé sur les couches [over]
/// (du haut vers le bas, la dernière pleine) : un fond translucide se mesure
/// sur ce qu'il laisse voir.
typedef ContrastPair = ({
  String foreground,
  String background,
  List<String> over,
  ContrastKind kind,
});

/// Deux paires de même premier plan, même fond et mêmes couches.
bool samePair(ContrastPair a, ContrastPair b) =>
    a.foreground == b.foreground &&
    a.background == b.background &&
    a.over.length == b.over.length &&
    [for (var i = 0; i < a.over.length; i++) a.over[i] == b.over[i]]
        .every((same) => same);

/// Une paire que le thème déclare sous son seuil dans une apparence : son
/// [ratio] mesuré, au centième inférieur, et la [reason] du choix.
typedef ContrastException = ({
  ContrastPair pair,
  String appearance,
  double ratio,
  String reason,
});

/// Le seuil WCAG d'un [kind] : 4,5:1 pour un texte, 3:1 pour un composant.
double contrastThreshold(ContrastKind kind) => switch (kind) {
  ContrastKind.text => 4.5,
  ContrastKind.ui => 3.0,
};

/// Le contraste de [pair] dans une apparence dont [colors] donne chaque
/// rôle en `0xAARRGGBB`.
double pairContrast(ContrastPair pair, Map<String, int> colors) =>
    contrastRatio(
      Rgb8(colors[pair.foreground]!),
      composite([
        colors[pair.background]!,
        for (final role in pair.over) colors[role]!,
      ]),
    );

/// [ratio] au centième inférieur, comme `fliin theme` l'affiche et comme une
/// exception le déclare.
double floorRatio(double ratio) => (ratio * 100).floor() / 100;

/// Une couche d'ombre DTCG `shadow`, couleur en `0xAARRGGBB` et longueurs en
/// px : décalage, flou (le rayon CSS, deux fois l'écart type) et étalement ;
/// [inset] la peint à l'intérieur de la forme.
typedef TokenShadow = ({
  int color,
  double offsetX,
  double offsetY,
  double blur,
  double spread,
  bool inset,
});

/// `SpringDescription.withDampingRatio` (DESIGN.md §2.4), trois jetons
/// `number` sous un groupe marqué `dev.fliin.spring`.
final class Spring {
  const Spring({
    required this.mass,
    required this.stiffness,
    required this.dampingRatio,
  });

  final double mass;
  final double stiffness;
  final double dampingRatio;
}

/// Taille et interligne en px, graisse numérique (DESIGN.md §2.3), et
/// approche facultative, sous un groupe marqué `dev.fliin.typeStyle`.
final class TypeStyle {
  const TypeStyle({
    required this.size,
    required this.lineHeight,
    required this.weight,
    this.tracking = 0,
  });

  final double size;
  final double lineHeight;
  final double weight;

  /// L'approche en px, `tracking` facultatif : celle que Core Text applique
  /// à SF par sa table `trak`, et que Skia n'applique pas (ADR 0014).
  final double tracking;
}

final class _Reader {
  _Reader(this.tokens);

  final ResolvedTokens tokens;

  FliinTokens read() {
    final roles = _children(
      'color.light',
      FliinTokens.colorRoles,
      taken: const {'contrastPairs'},
    );
    _sameNames(
      'color.dark',
      _children('color.dark', FliinTokens.colorRoles),
      'color.light',
      roles,
    );
    final springs = _children('motion.spring', FliinTokens.springNames);
    final motionTaken = {'pressedScale', ...springs};
    final curves = _children(
      'motion.curve',
      FliinTokens.curveNames,
      taken: motionTaken,
    );
    final durations = _children(
      'motion.duration',
      FliinTokens.durationNames,
      taken: {...motionTaken, ...curves},
    );
    final typography = {
      for (final platform in FliinTokens.platforms) platform: _scale(platform),
    };
    _sameNames(
      'typography.scale.android',
      typography['android']!.keys,
      'typography.scale.ios',
      typography['ios']!.keys,
    );
    final light = {for (final role in roles) role: _argb('color.light.$role')};
    final dark = {for (final role in roles) role: _argb('color.dark.$role')};
    final contrastPairs = _contrastPairs(roles);
    return FliinTokens(
      roles: roles,
      light: light,
      dark: dark,
      contrastPairs: contrastPairs,
      contrastExceptions: _contrastExceptions(contrastPairs, {
        'light': light,
        'dark': dark,
      }),
      notice:
          switch (tokens.groupExtensions[r'$']?[FliinTokens.noticeExtension]) {
            null => null,
            final String notice when notice.trim().isNotEmpty => notice,
            _ => throw const MissingFliinToken(
              '',
              '${FliinTokens.noticeExtension}: expected text',
            ),
          },
      button: _buttonShape(),
      radius: {
        for (final name in _children('shape.radius', FliinTokens.radiusNames))
          name: _px('shape.radius.$name'),
      },
      space: {
        for (final name in _children('space', FliinTokens.spaceNames))
          name: _px('space.$name'),
      },
      size: {
        for (final name in _children('size', FliinTokens.sizeNames))
          name: _size(name),
      },
      springs: {
        for (final name in springs) name: _spring('motion.spring.$name'),
      },
      curves: {
        for (final name in curves)
          name: _value<CubicBezierValue>('motion.curve.$name'),
      },
      durations: {
        for (final name in durations)
          name: _value<DurationValue>('motion.duration.$name'),
      },
      pressedScale: _value<NumberValue>('motion.pressedScale').value,
      typography: typography,
      fontFamily: {
        for (final platform in FliinTokens.platforms)
          platform: _family('typography.family.$platform'),
      },
      headingFamily: {
        for (final platform in FliinTokens.platforms)
          platform: tokens['typography.headingFamily.$platform'] == null
              ? null
              : _family('typography.headingFamily.$platform', heading: true),
      },
      monospaceFamily: {
        for (final platform in FliinTokens.platforms)
          platform:
              _family('typography.monospace.$platform') ??
              (throw MissingFliinToken(
                'typography.monospace.$platform',
                'expected a named font. Code does not use the system font',
              )),
      },
      fontWeights: {
        for (final name in _children(
          'typography.weight',
          FliinTokens.fontWeightNames,
        ))
          name: _weight('typography.weight.$name'),
      },
      shadows: _shadows(),
    );
  }

  /// [actual], les noms sous [path], doit être [expected], ceux de
  /// [reference], dans le même ordre : les deux deviennent les mêmes champs.
  void _sameNames(
    String path,
    Iterable<String> actual,
    String reference,
    Iterable<String> expected,
  ) {
    if (actual.join(',') != expected.join(',')) {
      throw MissingFliinToken(
        path,
        'the roles must be the same as in $reference, in the same order: '
        '${expected.join(', ')}',
      );
    }
  }

  /// Les noms directement sous [group], dans l'ordre du fichier ; chaque
  /// nom de [required] doit y être. Chacun devient un identifiant Dart :
  /// lowerCamelCase, ni réservé, ni dans [taken], les autres membres de la
  /// classe générée.
  List<String> _children(
    String group,
    List<String> required, {
    Set<String> taken = const {},
  }) {
    final prefix = '$group.';
    final names = <String>[];
    for (final path in tokens.tokens.keys) {
      if (!path.startsWith(prefix)) continue;
      final name = path.substring(prefix.length).split('.').first;
      if (names.contains(name)) continue;
      if (!_identifier.hasMatch(name)) {
        throw MissingFliinToken(
          '$group.$name',
          'expected a lowerCamelCase name ([a-z][A-Za-z0-9]*). It becomes a '
              'Dart identifier',
        );
      }
      if (_reserved.contains(name)) {
        throw MissingFliinToken(
          '$group.$name',
          '$name is reserved in Dart (a keyword, a member of Object or Enum, '
              'or the double type)',
        );
      }
      if (taken.contains(name)) {
        throw MissingFliinToken(
          '$group.$name',
          '$name is already a member of the generated class',
        );
      }
      names.add(name);
    }
    for (final name in required) {
      if (!names.contains(name)) {
        throw MissingFliinToken('$group.$name', 'token expected by core/');
      }
    }
    return names;
  }

  static final _identifier = RegExp(r'^[a-z][A-Za-z0-9]*$');
  static final _control = RegExp(r'[\x00-\x1F\x7F]');

  /// Les noms qui empêchent `tokens.g.dart` de compiler : les mots réservés,
  /// les membres d'`Object` et d'`Enum` (les rôles de couleur sont aussi un
  /// enum), et `double`, qui masquerait le type des champs.
  static final _reserved = {
    ...'assert break case catch class const continue default do else enum '
            'extends false final finally for if in is new null rethrow return '
            'super switch this throw true try var void while with'
        .split(' '),
    'hashCode',
    'runtimeType',
    'toString',
    'noSuchMethod',
    'index',
    'name',
    'values',
    'double',
  };

  T _value<T extends TokenValue>(String path) {
    final token = tokens[path];
    if (token == null) {
      final prefix = '$path.';
      throw MissingFliinToken(
        path,
        tokens.tokens.keys.any((key) => key.startsWith(prefix))
            ? 'found a group, expected a token. core/ does not read a nested '
                  'group here'
            : 'token expected by core/',
      );
    }
    return switch (token.value) {
      final T value => value,
      final other => throw MissingFliinToken(
        path,
        'found type ${other.type.name}, expected another type here',
      ),
    };
  }

  int _argb(String path) => _value<ColorValue>(path).argb(path);

  double _px(String path) => _pxOf(_value<DimensionValue>(path), path);

  double _pxOf(DimensionValue value, String path) => switch (value) {
    DimensionValue(:final value, unit: DimensionUnit.px) => value,
    DimensionValue(unit: DimensionUnit.rem) => throw MissingFliinToken(
      path,
      'expected px. Flutter has no rem unit',
    ),
  };

  /// Les tailles qui ne sont pas des longueurs : des échelles, des opacités
  /// et un interligne (ADR 0003 §2, ADR 0007 §2, ADR 0008 §5, ADR 0014 §17).
  static const _sizeNumbers = {
    'iconMaxScale',
    'scrimOpacity',
    'disabledOpacity',
    'pressedOverlayOpacity',
    'hoverBrightness',
    'pressHighlightOpacity',
    'controlPressedScale',
    'snugLineHeight',
  };

  /// Une dimension en px, sauf [_sizeNumbers].
  double _size(String name) {
    final path = 'size.$name';
    final number = _sizeNumbers.contains(name);
    return switch ((name, number, tokens[path]?.value)) {
      (_, _, NumberValue(:final value))
          when name.endsWith('Opacity') && (value < 0 || value > 1) =>
        throw MissingFliinToken(
          path,
          'expected an opacity between 0 and 1: $value',
        ),
      (_, true, NumberValue(:final value)) => value,
      (_, true, _) => throw MissingFliinToken(
        path,
        'expected a number. $name is not a length',
      ),
      (_, false, NumberValue()) => throw MissingFliinToken(
        path,
        'expected a dimension in px. Only ${_sizeNumbers.map((n) => 'size.$n').join(' and ')} are numbers',
      ),
      _ => _px(path),
    };
  }

  List<ContrastPair> _contrastPairs(List<String> roles) {
    final pairs = _extension(
      'color',
      FliinTokens.contrastExtension,
      _groupExtensions('color'),
    );
    final parsed = switch (pairs) {
      final List<Object?> pairs => [
        for (final (i, pair) in pairs.indexed) _pair(roles, pair, i),
      ],
      _ => throw MissingFliinToken(
        'color',
        '${FliinTokens.contrastExtension}: expected an array of pairs',
      ),
    };
    // Deux branches qui ajoutent la même paire avec deux seuils fusionnent
    // sans conflit textuel : la seconde serait mesurée en silence.
    for (final (i, pair) in parsed.indexed) {
      if (parsed.take(i).any((other) => samePair(other, pair))) {
        throw MissingFliinToken(
          'color',
          '${FliinTokens.contrastExtension}[$i]: pair '
              '${pair.foreground}/${pair.background} already declared',
        );
      }
      // Un contraste ne se mesure que sur ce que l'œil voit : le premier plan
      // et la dernière couche sont pleins, un fond translucide se pose sur
      // des couches.
      final opaque = [
        pair.foreground,
        if (pair.over.isEmpty) pair.background else pair.over.last,
      ];
      for (final role in opaque) {
        for (final appearance in ['light', 'dark']) {
          final path = 'color.$appearance.$role';
          if (_argb(path) >>> 24 != 0xFF) {
            throw MissingFliinToken(
              path,
              'expected an opaque color. The pair ${pair.foreground}/${pair.background} '
              'measures a contrast, which transparency makes undefined',
            );
          }
        }
      }
    }
    return parsed;
  }

  ContrastPair _pair(List<String> roles, Object? json, int i) {
    final at = '${FliinTokens.contrastExtension}[$i]';
    return switch (json) {
      {
        'foreground': final String foreground,
        'background': final String background,
        'kind': final String kind,
      } =>
        (
          foreground: _role(roles, foreground, 'color', i),
          background: _role(roles, background, 'color', i),
          over: switch (json['over']) {
            null => const <String>[],
            final List<Object?> over => [
              for (final role in over)
                role is String
                    ? _role(roles, role, 'color', i)
                    : throw MissingFliinToken(
                        'color',
                        '$at.over: expected role names',
                      ),
            ],
            _ => throw MissingFliinToken(
              'color',
              '$at.over: expected an array',
            ),
          },
          kind: switch (kind) {
            'text' => ContrastKind.text,
            'ui' => ContrastKind.ui,
            _ => throw MissingFliinToken(
              'color',
              '$at.kind: expected text or ui',
            ),
          },
        ),
      _ => throw MissingFliinToken(
        'color',
        '$at: expected {foreground, background, kind}',
      ),
    };
  }

  /// Chaque exception nomme une paire déclarée, dans une apparence où elle
  /// échoue vraiment, avec son ratio mesuré au centième inférieur : une
  /// couleur qui bouge oblige à la redéclarer, une paire qui passe à la
  /// retirer.
  List<ContrastException> _contrastExceptions(
    List<ContrastPair> pairs,
    Map<String, Map<String, int>> colors,
  ) {
    final raw = _groupExtensions(
      'color',
    )[FliinTokens.contrastExceptionsExtension];
    if (raw == null) return const [];
    const at = 'color';
    const name = FliinTokens.contrastExceptionsExtension;
    if (raw is! List<Object?>) {
      throw MissingFliinToken(at, '$name: expected an array');
    }
    final parsed = <ContrastException>[];
    for (final (i, json) in raw.indexed) {
      final exception = switch (json) {
        {
          'appearance': final String appearance,
          'ratio': final num ratio,
          'reason': final String reason,
        }
            when (appearance == 'light' || appearance == 'dark') &&
                reason.trim().isNotEmpty =>
          (
            pair: _pair(colors['light']!.keys.toList(), json, i),
            appearance: appearance,
            ratio: ratio.toDouble(),
            reason: reason,
          ),
        _ => throw MissingFliinToken(
          at,
          '$name[$i]: expected {foreground, background, kind, appearance light or dark, ratio, reason}',
        ),
      };
      final declared = pairs.where(
        (p) => samePair(p, exception.pair) && p.kind == exception.pair.kind,
      );
      if (declared.isEmpty) {
        throw MissingFliinToken(
          at,
          '$name[$i]: ${exception.pair.foreground}/${exception.pair.background} is not a declared pair',
        );
      }
      if (parsed.any(
        (e) =>
            samePair(e.pair, exception.pair) &&
            e.appearance == exception.appearance,
      )) {
        throw MissingFliinToken(at, '$name[$i]: exception already declared');
      }
      final measured = pairContrast(
        exception.pair,
        colors[exception.appearance]!,
      );
      final threshold = contrastThreshold(exception.pair.kind);
      if (measured >= threshold) {
        throw MissingFliinToken(
          at,
          '$name[$i]: ${exception.pair.foreground}/${exception.pair.background} passes in '
          '${exception.appearance} (${floorRatio(measured)}:1 for $threshold:1). Remove the exception',
        );
      }
      if (floorRatio(measured) != exception.ratio) {
        throw MissingFliinToken(
          at,
          '$name[$i]: declared ratio ${exception.ratio}, measured ${floorRatio(measured)}. Declare the exception again',
        );
      }
      parsed.add(exception);
    }
    return parsed;
  }

  String _role(List<String> roles, String role, String at, int i) =>
      roles.contains(role)
      ? role
      : throw MissingFliinToken(
          at,
          '${FliinTokens.contrastExtension}[$i]: unknown role $role',
        );

  ButtonShape _buttonShape() {
    final shape = _extension(
      'shape.button',
      FliinTokens.buttonShapeExtension,
      _groupExtensions('shape.button'),
    );
    const allowed = ['square', 'rounded', 'pill'];
    return switch (shape) {
      {'value': final String value, 'allowed': final List<Object?> list}
          when list.join(',') == allowed.join(',') && allowed.contains(value) =>
        ButtonShape.values.byName(value),
      _ => throw MissingFliinToken(
        'shape.button',
        '${FliinTokens.buttonShapeExtension}: expected {value: square | '
            'rounded | pill, allowed: [square, rounded, pill]}',
      ),
    };
  }

  Spring _spring(String path) {
    _extension(path, FliinTokens.springExtension, _groupExtensions(path));
    return Spring(
      mass: _value<NumberValue>('$path.mass').value,
      stiffness: _value<NumberValue>('$path.stiffness').value,
      dampingRatio: _value<NumberValue>('$path.dampingRatio').value,
    );
  }

  /// `platform-default` : rien n'est émis, et la valeur doit rester
  /// [FliinTokens.platformDefaultFamily] pour qu'une police changée sans
  /// effet ne passe pas en silence. `named` : la première famille de la
  /// liste, que l'app déclare dans son pubspec. Une police de titres
  /// ([heading]) prend `inherit` (celle du texte) au lieu de
  /// `platform-default`, aux mêmes conditions.
  String? _family(String path, {bool heading = false}) {
    final quiet = heading ? 'inherit' : 'platform-default';
    final names = _value<FontFamilyValue>(path).names;
    final source = _extension(
      path,
      FliinTokens.fontFamilyExtension,
      tokens[path]!.token.extensions,
    );
    return switch (source) {
      {'source': final String s}
          when s == quiet &&
              names.join(',') == FliinTokens.platformDefaultFamily.join(',') =>
        null,
      {'source': final String s} when s == quiet => throw MissingFliinToken(
        path,
        '$quiet: the value must stay '
        '${jsonEncode(FliinTokens.platformDefaultFamily)}. For another font, '
        'use source named',
      ),
      {'source': 'named'}
          when names.isNotEmpty &&
              names.first.trim().isNotEmpty &&
              !names.first.contains(_control) =>
        names.first,
      {'source': 'named'} => throw MissingFliinToken(
        path,
        'named: the first family in the list is the generated one. It must '
        'be non-empty, with no control character',
      ),
      _ => throw MissingFliinToken(
        path,
        '${FliinTokens.fontFamilyExtension}.source: expected $quiet or named',
      ),
    };
  }

  Map<String, TypeStyle> _scale(String platform) {
    final scale = 'typography.scale.$platform';
    return {
      for (final role in _children(
        scale,
        FliinTokens.textRoles,
        taken: const {'fontFamily', 'headingFamily'},
      ))
        role: _typeStyle('$scale.$role'),
    };
  }

  double _weight(String path) {
    final weight = _value<FontWeightValue>(path).weight;
    if (weight % 100 != 0 || weight < 100 || weight > 900) {
      throw MissingFliinToken(
        path,
        'expected a weight from 100 to 900 in steps of 100, the only ones '
        'FontWeight knows',
      );
    }
    return weight;
  }

  /// `shadow.light` et `shadow.dark` portent les mêmes noms, dans le même
  /// ordre (règle 8) : chacun devient un champ de la classe générée.
  Map<String, Map<String, List<TokenShadow>>> _shadows() {
    final names = _children('shadow.light', FliinTokens.shadowNames);
    _sameNames(
      'shadow.dark',
      _children('shadow.dark', FliinTokens.shadowNames),
      'shadow.light',
      names,
    );
    return {
      for (final appearance in FliinTokens.appearances)
        appearance: {
          for (final name in names) name: _shadow('shadow.$appearance.$name'),
        },
    };
  }

  List<TokenShadow> _shadow(String path) => [
    for (final layer in _value<ShadowValue>(path).layers)
      (
        color: layer.color.argb(path),
        offsetX: _pxOf(layer.offsetX, path),
        offsetY: _pxOf(layer.offsetY, path),
        blur: _pxOf(layer.blur, path),
        spread: _pxOf(layer.spread, path),
        inset: layer.inset,
      ),
  ];

  TypeStyle _typeStyle(String path) {
    _extension(path, FliinTokens.typeStyleExtension, _groupExtensions(path));
    return TypeStyle(
      size: _px('$path.size'),
      lineHeight: _px('$path.lineHeight'),
      weight: _weight('$path.weight'),
      tracking: tokens['$path.tracking'] == null ? 0 : _px('$path.tracking'),
    );
  }

  Map<String, Object?> _groupExtensions(String path) =>
      tokens.groupExtensions[path] ??
      (throw MissingFliinToken(path, 'expected a group'));

  Object? _extension(String at, String key, Map<String, Object?> extensions) =>
      extensions.containsKey(key)
      ? extensions[key]
      : throw MissingFliinToken(at, 'expected \$extensions.$key');
}

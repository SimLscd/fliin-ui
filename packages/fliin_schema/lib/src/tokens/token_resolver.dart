import 'reference.dart';
import 'token_document.dart';
import 'token_error.dart';
import 'token_value.dart';

/// Un jeton dont la valeur est connue : alias et pointeurs suivis, type
/// vérifié.
final class ResolvedToken {
  const ResolvedToken({
    required this.path,
    required this.type,
    required this.value,
    required this.token,
  });

  final String path;
  final TokenType type;
  final TokenValue value;

  /// Le nœud tel qu'écrit, pour ses `$extensions` et sa `$description`.
  final Token token;
}

/// Tous les jetons d'un document, par chemin pointé. Un groupe étendu par
/// `$extends` expose aussi les jetons hérités sous son propre chemin ; le
/// jeton `$root` d'un groupe est rangé sous le chemin du groupe.
final class ResolvedTokens {
  const ResolvedTokens(this.tokens, this.groupExtensions);

  final Map<String, ResolvedToken> tokens;

  /// Les `$extensions` de chaque groupe, par chemin (`$` pour la racine),
  /// y compris les groupes sans jeton.
  final Map<String, Map<String, Object?>> groupExtensions;

  ResolvedToken? operator [](String path) => tokens[path];
}

/// Un groupe après `$extends` : les enfants du groupe étendu, remplacés un
/// par un par les enfants locaux, et le `$type` local sinon hérité.
typedef _Effective = ({
  TokenType? type,
  Token? root,
  Map<String, TokenNode> children,
});

typedef _Found = ({TokenNode node, String path, TokenType? inheritedType});

/// Résout chaque jeton d'un [TokenDocument] (Format §7) : alias `{a.b}`,
/// pointeurs `$ref`, groupes `$extends`, héritage du `$type`, cycles. Lève
/// une [TokenError] au premier jeton invalide.
ResolvedTokens resolveTokens(TokenDocument document) =>
    _Resolver(document).all();

final class _Resolver {
  _Resolver(this.document);

  final TokenDocument document;
  final _effectives = <String, _Effective>{};
  final _resolved = <String, ResolvedToken>{};
  final _groupExtensions = <String, Map<String, Object?>>{};

  /// Les résolutions en cours : chemins de jetons, textes de pointeurs et
  /// `$extends <groupe>`. Revenir sur un maillon est un cycle.
  final _stack = <String>[];

  /// Les groupes en cours de parcours, du document à la feuille, et leur
  /// chemin. Un groupe qui reparaît sous lui-même hérite d'un ancêtre par
  /// `$extends` (Format §6.4.4, exemple 16) : ses chemins s'allongeraient
  /// sans fin.
  final _walking = Map<TokenGroup, String>.identity();

  ResolvedTokens all() {
    _walk(document.root, r'$', null);
    return ResolvedTokens(
      Map.unmodifiable(_resolved),
      Map.unmodifiable(_groupExtensions),
    );
  }

  void _walk(TokenGroup group, String path, TokenType? inherited) {
    if (_walking[group] case final first?) {
      throw ReferenceCycle(first, [first, path]);
    }
    _walking[group] = path;
    _groupExtensions[path] = group.extensions;
    final effective = _effective(group, path);
    final type = effective.type ?? inherited;
    if (effective.root case final root?) _token(path, root, type);
    for (final MapEntry(key: name, value: node) in effective.children.entries) {
      final childPath = _join(path, name);
      switch (node) {
        case Token():
          _token(childPath, node, type);
        case TokenGroup():
          _walk(node, childPath, type);
      }
    }
    _walking.remove(group);
  }

  ResolvedToken _token(String path, Token token, TokenType? inherited) {
    if (_resolved[path] case final done?) return done;
    _enter(path, path);
    try {
      var type = token.type ?? inherited;
      final TokenValue value;
      if (token.ref case final ref?) {
        final target = _locate(ref, path);
        type ??= target.tokenType;
        if (type == null) throw UndeterminedTokenType(path);
        value = _parse(target.raw, type, path);
      } else if (token.value case final String text when text.startsWith('{')) {
        final target = _alias(CurlyAlias.parse(text, path), path);
        type ??= target.type;
        if (target.type != type) {
          throw ReferenceTypeMismatch(path, type.name, target.type.name);
        }
        value = target.value;
      } else {
        if (type == null) throw UndeterminedTokenType(path);
        value = _parse(token.value, type, path);
      }
      return _resolved[path] = ResolvedToken(
        path: path,
        type: type,
        value: value,
        token: token,
      );
    } finally {
      _stack.removeLast();
    }
  }

  _Effective _effective(TokenGroup group, String path) {
    if (_effectives[path] case final done?) return done;
    final extends_ = group.extends_;
    if (extends_ == null) {
      return _effectives[path] = (
        type: group.type,
        root: group.root,
        children: group.children,
      );
    }
    _enter('\$extends $path', path);
    try {
      final found = _lookup(extends_, path);
      final base = switch (found.node) {
        final TokenGroup target => _effective(target, found.path),
        Token() => throw UnresolvedReference(
          path,
          extends_.text,
          r'$extends points to a token, expected a group',
        ),
      };
      return _effectives[path] = (
        type: group.type ?? base.type,
        root: group.root ?? base.root,
        children: {...base.children, ...group.children},
      );
    } finally {
      _stack.removeLast();
    }
  }

  /// Le nœud que désigne [reference] en suivant les groupes effectifs, et
  /// le `$type` que recevrait un jeton à cette place. Le segment `$root`
  /// désigne le jeton `$root` du groupe, rangé sous le chemin du groupe.
  _Found _lookup(Reference reference, String at) {
    final segments = switch (reference) {
      CurlyAlias(:final segments) || JsonPointer(:final segments) => segments,
    };
    var group = document.root;
    var path = r'$';
    var type = _effective(group, path).type;
    for (final (i, segment) in segments.indexed) {
      final effective = _effective(group, path);
      final child = segment == r'$root'
          ? effective.root
          : effective.children[segment];
      if (child == null) {
        throw UnresolvedReference(at, reference.text, 'not found');
      }
      if (segment != r'$root') path = _join(path, segment);
      if (i == segments.length - 1) {
        return (node: child, path: path, inheritedType: type);
      }
      switch (child) {
        case TokenGroup():
          group = child;
          type = _effective(child, path).type ?? type;
        case Token():
          throw UnresolvedReference(
            at,
            reference.text,
            '$segment is a token, not a group',
          );
      }
    }
    throw UnresolvedReference(at, reference.text, 'empty reference');
  }

  ResolvedToken _alias(CurlyAlias alias, String at) {
    final found = _lookup(alias, at);
    return switch (found.node) {
      final Token token => _token(found.path, token, found.inheritedType),
      TokenGroup() => throw UnresolvedReference(
        at,
        alias.text,
        r'points to a group, expected a token (the $root of group g is '
        r'written {g.$root})',
      ),
    };
  }

  /// Le JSON brut sous [pointer], et le type du jeton dont c'est exactement
  /// le `$value`, s'il y en a un. Un pointeur désigne le document tel
  /// qu'écrit (RFC 6901) : il ne voit pas les jetons hérités par `$extends`.
  ({Object? raw, TokenType? tokenType}) _locate(
    JsonPointer pointer,
    String at,
  ) {
    Never unresolved(String reason) =>
        throw UnresolvedReference(at, pointer.text, reason);
    final segments = pointer.segments;
    TokenGroup group = document.root;
    var type = group.type;
    for (final (i, segment) in segments.indexed) {
      final TokenNode child;
      if (segment == r'$root') {
        child = group.root ?? unresolved('not found');
      } else if (segment.startsWith(r'$')) {
        unresolved('a pointer points to a value under \$value, not $segment');
      } else {
        child =
            group.children[segment] ??
            unresolved(
              group.extends_ == null
                  ? 'not found'
                  : r'not found in the file as written. A pointer does not '
                        r'follow $extends, an alias {…} does',
            );
      }
      switch (child) {
        case TokenGroup():
          group = child;
          type = child.type ?? type;
        case Token(:final value, :final ref, type: final own):
          final tokenType = own ?? type;
          if (i + 1 >= segments.length || segments[i + 1] != r'$value') {
            unresolved(r'a pointer points to a value under $value');
          }
          final raw = switch ((value, ref)) {
            (final value?, _) => value,
            (null, final ref?) => _follow(ref, at),
            (null, null) => unresolved('token without a value'),
          };
          final rest = segments.sublist(i + 2);
          return (
            raw: _descend(raw, rest, at, pointer.text),
            tokenType: rest.isEmpty ? tokenType : null,
          );
      }
    }
    unresolved(r'points to a group, expected a value under $value');
  }

  Object? _follow(JsonPointer pointer, String at) {
    _enter(pointer.text, at);
    try {
      return _locate(pointer, at).raw;
    } finally {
      _stack.removeLast();
    }
  }

  Object? _descend(Object? raw, List<String> segments, String at, String text) {
    var current = raw;
    for (final segment in segments) {
      current = _dereference(current, at);
      switch (current) {
        case final Map<Object?, Object?> map when map.containsKey(segment):
          current = map[segment];
        case final List<Object?> list:
          final index = int.tryParse(segment);
          if (index == null || !_digits.hasMatch(segment)) {
            throw UnresolvedReference(at, text, '$segment: expected an index');
          }
          if (index >= list.length) {
            throw UnresolvedReference(
              at,
              text,
              'index $index is outside the array',
            );
          }
          current = list[index];
        default:
          throw UnresolvedReference(at, text, '$segment not found');
      }
    }
    return current;
  }

  static final _digits = RegExp(r'^\d+$');

  /// [raw] s'il n'est pas un `{"$ref": …}`, sinon ce que le pointeur
  /// désigne, en suivant les `$ref` en chaîne. Le pointeur reste sur la pile
  /// tant que [parse] lit son résultat, pour qu'un cycle à travers plusieurs
  /// `$ref` soit vu.
  T _withReference<T>(Object? raw, String at, T Function(Object? raw) parse) {
    var pushed = 0;
    try {
      var current = raw;
      while (_isReferenceObject(current)) {
        final text = (current! as Map<Object?, Object?>)[r'$ref'];
        if (text is! String) {
          throw InvalidTokenValue(at, r'$ref: expected a string');
        }
        final pointer = JsonPointer.parse(text, at);
        _enter(pointer.text, at);
        pushed++;
        current = _locate(pointer, at).raw;
      }
      return parse(current);
    } finally {
      for (var i = 0; i < pushed; i++) {
        _stack.removeLast();
      }
    }
  }

  static bool _isReferenceObject(Object? raw) =>
      raw is Map<Object?, Object?> &&
      raw.length == 1 &&
      raw.containsKey(r'$ref');

  Object? _dereference(Object? raw, String at) =>
      _withReference(raw, at, (raw) => raw);

  /// Une valeur complète du type [type] : un alias `{…}`, un `$ref` ou la
  /// syntaxe du type.
  TokenValue _parse(Object? raw, TokenType type, String at) =>
      _withReference(raw, at, (raw) {
        if (raw case final String text when text.startsWith('{')) {
          final target = _alias(CurlyAlias.parse(text, at), at);
          if (target.type != type) {
            throw ReferenceTypeMismatch(at, type.name, target.type.name);
          }
          return target.value;
        }
        return switch (type) {
          TokenType.color => _color(raw, at),
          TokenType.dimension => _dimension(raw, at),
          TokenType.fontFamily => _fontFamily(raw, at),
          TokenType.fontWeight => _fontWeight(raw, at),
          TokenType.duration => _duration(raw, at),
          TokenType.cubicBezier => _cubicBezier(raw, at),
          TokenType.number => NumberValue(_number(raw, at)),
          TokenType.strokeStyle => _strokeStyle(raw, at),
          TokenType.border => _border(raw, at),
          TokenType.transition => _transition(raw, at),
          TokenType.shadow => _shadow(raw, at),
          TokenType.gradient => _gradient(raw, at),
          TokenType.typography => _typography(raw, at),
        };
      });

  T _sub<T extends TokenValue>(Object? raw, TokenType type, String at) =>
      _parse(raw, type, at) as T;

  ColorValue _color(Object? raw, String at) {
    final map = _object(raw, at, const {
      'colorSpace',
      'components',
      'alpha',
      'hex',
    });
    final colorSpace = _dereference(_required(map, 'colorSpace', at), at);
    final space = switch (colorSpace) {
      final String text =>
        ColorSpace.parse(text) ??
            (throw InvalidTokenValue(at, 'unknown colorSpace $text')),
      _ => throw InvalidTokenValue(at, 'colorSpace: expected a string'),
    };
    final components = _list(_required(map, 'components', at), at);
    if (components.length != space.ranges.length) {
      throw InvalidTokenValue(
        at,
        '${space.wire}: expected ${space.ranges.length} components, got '
        '${components.length}',
      );
    }
    final alpha = map.containsKey('alpha') ? _number(map['alpha'], at) : 1.0;
    if (alpha < 0 || alpha > 1) {
      throw InvalidTokenValue(at, 'alpha $alpha: expected between 0 and 1');
    }
    final hex = switch (_dereference(map['hex'], at)) {
      null => null,
      final String text when _hex.hasMatch(text) => text,
      final String text => throw InvalidTokenValue(
        at,
        'hex $text: expected a six-digit #RRGGBB',
      ),
      _ => throw InvalidTokenValue(at, 'hex: expected a string'),
    };
    final color = ColorValue(
      colorSpace: space,
      components: [
        for (final (i, component) in components.indexed)
          switch (_dereference(component, at)) {
            'none' => const NoneComponent(),
            final num value when space.ranges[i].contains(value.toDouble()) =>
              NumericComponent(value.toDouble()),
            final num value => throw InvalidTokenValue(
              at,
              'component $i = $value: expected ${space.ranges[i].description} '
              '(${space.wire})',
            ),
            _ => throw InvalidTokenValue(
              at,
              'component $i: expected a number or none',
            ),
          },
      ],
      alpha: alpha,
      hex: hex,
    );
    if (hex != null &&
        space == ColorSpace.srgb &&
        color.components.every((c) => c is NumericComponent)) {
      final rgb = color.argb(at) & 0xFFFFFF;
      if (int.parse(hex.substring(1), radix: 16) != rgb) {
        throw InvalidTokenValue(
          at,
          'hex $hex does not match the components '
          '(#${rgb.toRadixString(16).padLeft(6, '0')})',
        );
      }
    }
    return color;
  }

  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  DimensionValue _dimension(Object? raw, String at) {
    final map = _object(raw, at, const {'value', 'unit'});
    return DimensionValue(
      _number(_required(map, 'value', at), at),
      _keyword(_required(map, 'unit', at), DimensionUnit.values, at),
    );
  }

  DurationValue _duration(Object? raw, String at) {
    final map = _object(raw, at, const {'value', 'unit'});
    return DurationValue(
      _number(_required(map, 'value', at), at),
      _keyword(_required(map, 'unit', at), DurationUnit.values, at),
    );
  }

  FontFamilyValue _fontFamily(Object? raw, String at) =>
      switch (_dereference(raw, at)) {
        final String name => FontFamilyValue([name]),
        final List<Object?> names => FontFamilyValue([
          for (final name in names)
            switch (_dereference(name, at)) {
              final String name => name,
              _ => throw InvalidTokenValue(
                at,
                'fontFamily: expected strings in the array',
              ),
            },
        ]),
        _ => throw InvalidTokenValue(
          at,
          'fontFamily: expected a string or an array of strings',
        ),
      };

  FontWeightValue _fontWeight(Object? raw, String at) =>
      switch (_dereference(raw, at)) {
        final num weight when weight >= 1 && weight <= 1000 => FontWeightValue(
          weight.toDouble(),
        ),
        final num weight => throw InvalidTokenValue(
          at,
          'fontWeight $weight: expected between 1 and 1000',
        ),
        final String keyword => FontWeightValue(
          (FontWeightValue.keywords[keyword] ??
                  (throw InvalidTokenValue(
                    at,
                    'fontWeight $keyword: unknown keyword',
                  )))
              .toDouble(),
        ),
        _ => throw InvalidTokenValue(
          at,
          'fontWeight: expected a number or a keyword',
        ),
      };

  CubicBezierValue _cubicBezier(Object? raw, String at) {
    final points = [for (final p in _list(raw, at)) _number(p, at)];
    if (points.length != 4) {
      throw InvalidTokenValue(at, 'cubicBezier: expected four numbers');
    }
    for (final x in [points[0], points[2]]) {
      if (x < 0 || x > 1) {
        throw InvalidTokenValue(at, 'cubicBezier: x = $x is outside [0, 1]');
      }
    }
    return CubicBezierValue(points[0], points[1], points[2], points[3]);
  }

  StrokeStyleValue _strokeStyle(Object? raw, String at) =>
      switch (_dereference(raw, at)) {
        final String keyword => StrokeStyleName(
          _keyword(keyword, StrokeStyleKeyword.values, at),
        ),
        final Map<Object?, Object?> map => _dash(map, at),
        _ => throw InvalidTokenValue(
          at,
          'strokeStyle: expected a keyword or an object',
        ),
      };

  StrokeStyleDash _dash(Map<Object?, Object?> raw, String at) {
    final map = _object(raw, at, const {'dashArray', 'lineCap'});
    final dashes = _list(_required(map, 'dashArray', at), at);
    if (dashes.isEmpty) {
      throw InvalidTokenValue(at, 'dashArray: expected at least one dash');
    }
    return StrokeStyleDash(
      dashArray: [
        for (final dash in dashes) _sub(dash, TokenType.dimension, at),
      ],
      lineCap: _keyword(_required(map, 'lineCap', at), LineCap.values, at),
    );
  }

  BorderValue _border(Object? raw, String at) {
    final map = _object(raw, at, const {'color', 'width', 'style'});
    return BorderValue(
      color: _sub(_required(map, 'color', at), TokenType.color, at),
      width: _sub(_required(map, 'width', at), TokenType.dimension, at),
      style: _sub(_required(map, 'style', at), TokenType.strokeStyle, at),
    );
  }

  TransitionValue _transition(Object? raw, String at) {
    final map = _object(raw, at, const {'duration', 'delay', 'timingFunction'});
    return TransitionValue(
      duration: _sub(_required(map, 'duration', at), TokenType.duration, at),
      delay: _sub(_required(map, 'delay', at), TokenType.duration, at),
      timingFunction: _sub(
        _required(map, 'timingFunction', at),
        TokenType.cubicBezier,
        at,
      ),
    );
  }

  ShadowValue _shadow(Object? raw, String at) =>
      switch (_dereference(raw, at)) {
        final List<Object?> layers when layers.isNotEmpty => ShadowValue([
          for (final layer in layers) _shadowLayer(layer, at),
        ]),
        List() => throw InvalidTokenValue(
          at,
          'shadow: expected at least one layer',
        ),
        final layer => ShadowValue([_shadowLayer(layer, at)]),
      };

  ShadowLayer _shadowLayer(Object? raw, String at) {
    final map = _object(raw, at, const {
      'color',
      'offsetX',
      'offsetY',
      'blur',
      'spread',
      'inset',
    });
    DimensionValue dimension(String key) =>
        _sub(_required(map, key, at), TokenType.dimension, at);
    return ShadowLayer(
      color: _sub(_required(map, 'color', at), TokenType.color, at),
      offsetX: dimension('offsetX'),
      offsetY: dimension('offsetY'),
      blur: dimension('blur'),
      spread: dimension('spread'),
      inset: switch (_dereference(map['inset'], at)) {
        null => false,
        final bool inset => inset,
        _ => throw InvalidTokenValue(at, 'inset: expected a boolean'),
      },
    );
  }

  GradientValue _gradient(Object? raw, String at) {
    final stops = _list(raw, at);
    if (stops.isEmpty) {
      throw InvalidTokenValue(at, 'gradient: expected at least one stop');
    }
    return GradientValue([
      for (final stop in stops)
        switch (_object(stop, at, const {'color', 'position'})) {
          final map => GradientStop(
            color: _sub(_required(map, 'color', at), TokenType.color, at),
            position: _sub<NumberValue>(
              _required(map, 'position', at),
              TokenType.number,
              at,
            ).value,
          ),
        },
    ]);
  }

  TypographyValue _typography(Object? raw, String at) {
    final map = _object(raw, at, const {
      'fontFamily',
      'fontSize',
      'fontWeight',
      'letterSpacing',
      'lineHeight',
    });
    return TypographyValue(
      fontFamily: _sub(
        _required(map, 'fontFamily', at),
        TokenType.fontFamily,
        at,
      ),
      fontSize: _sub(_required(map, 'fontSize', at), TokenType.dimension, at),
      fontWeight: _sub(
        _required(map, 'fontWeight', at),
        TokenType.fontWeight,
        at,
      ),
      letterSpacing: _sub(
        _required(map, 'letterSpacing', at),
        TokenType.dimension,
        at,
      ),
      lineHeight: _sub<NumberValue>(
        _required(map, 'lineHeight', at),
        TokenType.number,
        at,
      ).value,
    );
  }

  Map<String, Object?> _object(Object? raw, String at, Set<String> allowed) {
    final map = switch (_dereference(raw, at)) {
      final Map<Object?, Object?> map => map,
      _ => throw InvalidTokenValue(at, 'expected an object'),
    };
    for (final key in map.keys) {
      if (key is! String || !allowed.contains(key)) {
        throw InvalidTokenValue(at, 'unexpected property $key');
      }
    }
    return map.cast<String, Object?>();
  }

  Object? _required(Map<String, Object?> map, String key, String at) =>
      map.containsKey(key)
      ? map[key]
      : throw InvalidTokenValue(at, 'missing property $key');

  List<Object?> _list(Object? raw, String at) =>
      switch (_dereference(raw, at)) {
        final List<Object?> list => list,
        _ => throw InvalidTokenValue(at, 'expected an array'),
      };

  double _number(Object? raw, String at) => switch (_dereference(raw, at)) {
    final num value when value.isFinite => value.toDouble(),
    num() => throw InvalidTokenValue(
      at,
      'number outside the range of a double',
    ),
    _ => throw InvalidTokenValue(at, 'expected a number'),
  };

  T _keyword<T extends Enum>(Object? raw, List<T> values, String at) =>
      switch (_dereference(raw, at)) {
        final String text =>
          values.where((v) => v.name == text).firstOrNull ??
              (throw InvalidTokenValue(
                at,
                '$text: expected ${values.map((v) => v.name).join(', ')}',
              )),
        _ => throw InvalidTokenValue(at, 'expected a string'),
      };

  void _enter(String key, String at) {
    final start = _stack.indexOf(key);
    if (start >= 0) {
      throw ReferenceCycle(at, [..._stack.sublist(start), key]);
    }
    _stack.add(key);
  }

  static String _join(String path, String name) =>
      path == r'$' ? name : '$path.$name';
}

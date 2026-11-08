import 'reference.dart';
import 'token_error.dart';
import 'token_value.dart';

/// `$deprecated` : un booléen, ou un message qui vaut `true`.
final class Deprecation {
  const Deprecation.flag(this.active) : message = null;

  const Deprecation.message(String this.message) : active = true;

  final bool active;
  final String? message;

  Object toJson() => message ?? active;
}

/// Un nœud tel qu'écrit dans le fichier. Les `$extensions` sont gardées
/// telles quelles, connues ou non (Format §5.2.3 : un outil les conserve).
sealed class TokenNode {
  const TokenNode({
    required this.description,
    required this.deprecation,
    required this.extensions,
    required this.order,
  });

  final String? description;
  final Deprecation? deprecation;
  final Map<String, Object?> extensions;

  /// Les clés dans l'ordre du fichier lu. Vide pour un nœud construit en
  /// code : [toJson] suit alors l'ordre canonique, et y range à la fin les
  /// clés que [order] ne connaît pas.
  final List<String> order;

  Map<String, Object?> toJson();

  Map<String, Object?> _inOrder(Map<String, Object?> json) => {
    for (final key in order)
      if (json.containsKey(key)) key: json[key],
    ...json,
  };
}

/// Un objet qui porte `$value` ou `$ref` (Format §5.1). [value] est le JSON
/// brut, références comprises : la résolution en fait une [TokenValue].
final class Token extends TokenNode {
  const Token({
    required this.type,
    required this.value,
    required this.ref,
    super.description,
    super.deprecation,
    super.extensions = const {},
    super.order = const [],
  }) : assert((value == null) != (ref == null));

  final TokenType? type;
  final Object? value;
  final JsonPointer? ref;

  @override
  Map<String, Object?> toJson() => _inOrder({
    r'$type': ?type?.name,
    r'$value': ?value,
    r'$ref': ?ref?.text,
    r'$description': ?description,
    r'$deprecated': ?deprecation?.toJson(),
    if (extensions.isNotEmpty) r'$extensions': extensions,
  });
}

final class TokenGroup extends TokenNode {
  const TokenGroup({
    this.type,
    this.extends_,
    this.root,
    this.children = const {},
    this.schema,
    super.description,
    super.deprecation,
    super.extensions = const {},
    super.order = const [],
  });

  final TokenType? type;
  final Reference? extends_;

  /// Le jeton `$root` du groupe, que `{groupe}` désigne.
  final Token? root;
  final Map<String, TokenNode> children;

  /// `$schema`, permis sur le groupe racine seulement.
  final String? schema;

  @override
  Map<String, Object?> toJson() => _inOrder({
    r'$schema': ?schema,
    r'$type': ?type?.name,
    r'$description': ?description,
    r'$deprecated': ?deprecation?.toJson(),
    r'$extends': ?extends_?.text,
    if (extensions.isNotEmpty) r'$extensions': extensions,
    r'$root': ?root?.toJson(),
    for (final MapEntry(:key, :value) in children.entries) key: value.toJson(),
  });
}

/// Un fichier `*.tokens.json`, décodé en arbre. [toJson] rend exactement ce
/// que [TokenDocument.fromJson] a lu, clés dans l'ordre du fichier.
final class TokenDocument {
  const TokenDocument(this.root);

  /// Lève une [TokenError] située à la première violation de structure :
  /// nom interdit, propriété `$` inconnue, type inconnu, `$value` nul,
  /// objet à la fois jeton et groupe, référence mal formée.
  factory TokenDocument.fromJson(Object? json) =>
      TokenDocument(_group(_object(json, r'$'), r'$', isRoot: true));

  final TokenGroup root;

  Map<String, Object?> toJson() => root.toJson();

  static const _tokenProperties = {
    r'$value',
    r'$type',
    r'$ref',
    r'$description',
    r'$extensions',
    r'$deprecated',
  };

  static const _groupProperties = {
    r'$type',
    r'$description',
    r'$extensions',
    r'$extends',
    r'$deprecated',
    r'$root',
  };

  static TokenNode _node(Map<String, Object?> json, String at) =>
      json.containsKey(r'$value') || json.containsKey(r'$ref')
      ? _token(json, at)
      : _group(json, at, isRoot: false);

  static Token _token(Map<String, Object?> json, String at) {
    for (final key in json.keys) {
      if (!_tokenProperties.contains(key)) {
        throw key.startsWith(r'$')
            ? UnknownTokenProperty(at, key)
            : AmbiguousNode(at, 'a token (\$value) has no child $key');
      }
    }
    if (json.containsKey(r'$value') && json.containsKey(r'$ref')) {
      throw AmbiguousNode(at, r'$value and $ref together');
    }
    if (json.containsKey(r'$value') && json[r'$value'] == null) {
      throw InvalidTokenValue(at, r'$value is null');
    }
    return Token(
      type: _type(json, at),
      value: json[r'$value'],
      ref: switch (json[r'$ref']) {
        null => null,
        final String text => JsonPointer.parse(text, at),
        _ => throw InvalidTokenValue(at, r'$ref: expected a string'),
      },
      description: _description(json, at),
      deprecation: _deprecated(json, at),
      extensions: _extensions(json, at),
      order: [...json.keys],
    );
  }

  static TokenGroup _group(
    Map<String, Object?> json,
    String at, {
    required bool isRoot,
  }) {
    final children = <String, TokenNode>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key.startsWith(r'$')) {
        if (!_groupProperties.contains(key) && !(isRoot && key == r'$schema')) {
          throw UnknownTokenProperty(at, key);
        }
        continue;
      }
      if (key.contains('{') || key.contains('}') || key.contains('.')) {
        throw InvalidTokenName(at, key);
      }
      final path = at == r'$' ? key : '$at.$key';
      children[key] = _node(_object(value, path), path);
    }
    return TokenGroup(
      type: _type(json, at),
      extends_: switch (json[r'$extends']) {
        null => null,
        final String text => Reference.parse(text, at),
        _ => throw InvalidTokenValue(at, r'$extends: expected a string'),
      },
      root: switch (json[r'$root']) {
        null => null,
        final value => _token(_object(value, '$at.\$root'), '$at.\$root'),
      },
      children: children,
      schema: switch (json[r'$schema']) {
        null => null,
        final String text => text,
        _ => throw InvalidTokenValue(at, r'$schema: expected a string'),
      },
      description: _description(json, at),
      deprecation: _deprecated(json, at),
      extensions: _extensions(json, at),
      order: [...json.keys],
    );
  }

  static TokenType? _type(Map<String, Object?> json, String at) =>
      switch (json[r'$type']) {
        null => null,
        final String text =>
          TokenType.parse(text) ?? (throw UnknownTokenType(at, text)),
        _ => throw InvalidTokenValue(at, r'$type: expected a string'),
      };

  static String? _description(Map<String, Object?> json, String at) =>
      switch (json[r'$description']) {
        null => null,
        final String text => text,
        _ => throw InvalidTokenValue(at, r'$description: expected a string'),
      };

  static Deprecation? _deprecated(Map<String, Object?> json, String at) =>
      switch (json[r'$deprecated']) {
        null => null,
        final bool flag => Deprecation.flag(flag),
        final String message => Deprecation.message(message),
        _ => throw InvalidTokenValue(
          at,
          r'$deprecated: expected a boolean or a string',
        ),
      };

  static Map<String, Object?> _extensions(
    Map<String, Object?> json,
    String at,
  ) => switch (json[r'$extensions']) {
    null => const {},
    final value => _object(value, '$at.\$extensions'),
  };

  static Map<String, Object?> _object(Object? json, String at) =>
      switch (json) {
        final Map<Object?, Object?> map
            when map.keys.every((key) => key is String) =>
          map.cast<String, Object?>(),
        _ => throw InvalidTokenValue(at, 'expected an object'),
      };
}

/// Un fichier de jetons DTCG viole le format, ou une référence ne se résout
/// pas. [path] est le chemin pointé du jeton ou du groupe fautif, en
/// notation alias : `color.light.surface`, et `$` pour la racine.
sealed class TokenError implements Exception {
  const TokenError(this.path);

  final String path;

  String get reason;

  @override
  String toString() => '$path: $reason';
}

/// Un nom de jeton ou de groupe commence par `$` ou contient `{`, `}`, `.`.
final class InvalidTokenName extends TokenError {
  const InvalidTokenName(super.path, this.name);

  final String name;

  @override
  String get reason =>
      '$name: a name does not start with \$ and does not contain {, } '
      'or .';
}

/// Une propriété `$…` que le format ne définit pas pour ce nœud.
final class UnknownTokenProperty extends TokenError {
  const UnknownTokenProperty(super.path, this.property);

  final String property;

  @override
  String get reason => '$property: unknown property in the format';
}

/// Un objet qui porte à la fois `$value` et des enfants, ou `$value` et
/// `$ref`.
final class AmbiguousNode extends TokenError {
  const AmbiguousNode(super.path, this.reason);

  @override
  final String reason;
}

final class UnknownTokenType extends TokenError {
  const UnknownTokenType(super.path, this.type);

  final String type;

  @override
  String get reason => '$type: not one of the 13 DTCG types';
}

/// Ni `$type` sur le jeton, ni sur un groupe parent, ni sur la cible de son
/// alias (Format §5.2.2).
final class UndeterminedTokenType extends TokenError {
  const UndeterminedTokenType(super.path);

  @override
  String get reason =>
      'type cannot be determined: no \$type on the token, its groups or '
      'the target of its alias';
}

/// La valeur ne respecte pas la syntaxe de son type.
final class InvalidTokenValue extends TokenError {
  const InvalidTokenValue(super.path, this.reason);

  @override
  final String reason;
}

/// Une chaîne `{…}` ou un `$ref` mal formé.
final class MalformedTokenReference extends TokenError {
  const MalformedTokenReference(super.path, this.text, this.reason);

  final String text;

  @override
  final String reason;

  @override
  String toString() => '$path: $text: $reason';
}

/// Une référence bien formée qui ne désigne rien d'utilisable.
final class UnresolvedReference extends TokenError {
  const UnresolvedReference(super.path, this.text, this.reason);

  final String text;

  @override
  final String reason;

  @override
  String toString() => '$path: $text: $reason';
}

/// Une chaîne de références, d'alias ou de `$extends` qui revient sur
/// elle-même. [chain] la donne dans l'ordre, le premier maillon répété en
/// dernier.
final class ReferenceCycle extends TokenError {
  const ReferenceCycle(super.path, this.chain);

  final List<String> chain;

  @override
  String get reason => 'cycle: ${chain.join(' → ')}';
}

/// Une référence vers un jeton d'un autre type que celui attendu.
final class ReferenceTypeMismatch extends TokenError {
  const ReferenceTypeMismatch(super.path, this.expected, this.found);

  final String expected;
  final String found;

  @override
  String get reason => 'expected $expected, the target has type $found';
}

/// Une couleur que la cible ne sait pas représenter : Flutter ne connaît que
/// le sRGB.
final class UnsupportedColorSpace extends TokenError {
  const UnsupportedColorSpace(super.path, this.colorSpace);

  final String colorSpace;

  @override
  String get reason =>
      'color space $colorSpace: only srgb converts to a Flutter Color';
}

/// Le profil Fliin attend un jeton, une extension ou une forme que le
/// fichier n'a pas.
final class MissingFliinToken extends TokenError {
  const MissingFliinToken(super.path, this.reason);

  @override
  final String reason;
}

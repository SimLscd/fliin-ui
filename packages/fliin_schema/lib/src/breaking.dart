import 'json_node.dart';

/// Une cassure qu'une version apporte par rapport à la précédente publiée
/// (DESIGN.md §4.4). Les trois premières sont calculées par
/// `fliin registry build` sur l'API Dart publique ; [SemanticBreak] est la
/// seule qu'un auteur écrit à la main.
sealed class BreakingChange {
  const BreakingChange();

  factory BreakingChange.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return switch (node['kind'].oneOf(BreakingKind.values)) {
      BreakingKind.removed => RemovedDeclaration(node['symbol'].string),
      BreakingKind.signatureChanged => ChangedSignature(
        node['symbol'].string,
        before: node['before'].string,
        after: node['after'].string,
      ),
      BreakingKind.requiredParameterAdded => RequiredParameterAdded(
        node['symbol'].string,
        parameter: node['parameter'].string,
      ),
      BreakingKind.semantic => SemanticBreak(node['description'].string),
    };
  }

  BreakingKind get kind;

  Map<String, Object?> toJson();

  /// La forme JSON sert d'identité : deux cassures égales s'écrivent pareil.
  @override
  bool operator ==(Object other) =>
      other is BreakingChange && '${other.toJson()}' == '${toJson()}';

  @override
  int get hashCode => '${toJson()}'.hashCode;

  @override
  String toString() => '${toJson()}';
}

enum BreakingKind {
  removed,
  signatureChanged,
  requiredParameterAdded,
  semantic,
}

/// Une déclaration publique de la version précédente qui n'existe plus :
/// `FlButton`, `FlButton.loading`, `FlButton.new`.
final class RemovedDeclaration extends BreakingChange {
  const RemovedDeclaration(this.symbol);

  final String symbol;

  @override
  BreakingKind get kind => BreakingKind.removed;

  @override
  Map<String, Object?> toJson() => {'kind': kind.name, 'symbol': symbol};
}

/// Un type, un paramètre retiré ou une forme de déclaration qui change.
final class ChangedSignature extends BreakingChange {
  const ChangedSignature(
    this.symbol, {
    required this.before,
    required this.after,
  });

  final String symbol;
  final String before;
  final String after;

  @override
  BreakingKind get kind => BreakingKind.signatureChanged;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'symbol': symbol,
    'before': before,
    'after': after,
  };
}

/// Un paramètre nouveau et requis, ou un paramètre facultatif devenu requis :
/// chaque appel existant cesse de compiler.
final class RequiredParameterAdded extends BreakingChange {
  const RequiredParameterAdded(this.symbol, {required this.parameter});

  final String symbol;
  final String parameter;

  @override
  BreakingKind get kind => BreakingKind.requiredParameterAdded;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'symbol': symbol,
    'parameter': parameter,
  };
}

/// Une cassure que l'API ne montre pas (un comportement, un rendu), déclarée
/// par l'auteur dans le manifeste source.
final class SemanticBreak extends BreakingChange {
  const SemanticBreak(this.description);

  final String description;

  @override
  BreakingKind get kind => BreakingKind.semantic;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'description': description,
  };
}

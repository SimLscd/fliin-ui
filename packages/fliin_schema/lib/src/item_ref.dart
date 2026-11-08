import 'package:pub_semver/pub_semver.dart';

/// Espace de noms d'un registre : `@fliin` (gratuit), `@pro`, `@acme`.
extension type const Namespace._(String value) {
  factory Namespace.parse(String text) => _pattern.hasMatch(text)
      ? Namespace._(text)
      : throw FormatException('expected a namespace @<lowercase>', text);

  static const fliin = Namespace._('@fliin');

  /// Le nom sans `@`, tel qu'il apparaît dans les chemins du registre.
  String get bare => value.substring(1);

  static final _pattern = RegExp(r'^@[a-z0-9][a-z0-9-]*$');
}

/// Un élément du catalogue, éventuellement à une version exacte.
final class ItemRef {
  /// Lève une [FormatException] si [name] n'est pas en kebab-case.
  ItemRef(this.name, {this.namespace = Namespace.fliin, this.version}) {
    if (!_name.hasMatch(name)) {
      throw FormatException('expected a kebab-case name', name);
    }
  }

  /// `@ns/name@1.2.0`, `@ns/name`, `name@1.2.0` ou `name`.
  factory ItemRef.parse(String text) {
    final (namespace, name, version) = _split(text);
    return ItemRef(
      name,
      namespace: namespace,
      version: version == null ? null : Version.parse(version),
    );
  }

  /// [ItemRef.parse], en exigeant une version exacte.
  static ItemRef parseVersioned(String text) {
    final ref = ItemRef.parse(text);
    if (ref.version == null) {
      throw FormatException('expected an exact version', text);
    }
    return ref;
  }

  /// [ItemRef.parse], en refusant toute version.
  static ItemRef parseUnversioned(String text) {
    final ref = ItemRef.parse(text);
    if (ref.version != null) {
      throw FormatException('expected a reference without a version', text);
    }
    return ref;
  }

  final Namespace namespace;
  final String name;
  final Version? version;

  ItemRef at(Version version) =>
      ItemRef(name, namespace: namespace, version: version);

  @override
  bool operator ==(Object other) =>
      other is ItemRef &&
      other.namespace == namespace &&
      other.name == name &&
      other.version == version;

  @override
  int get hashCode => Object.hash(namespace, name, version);

  /// Forme canonique : l'espace de noms `@fliin` est omis.
  @override
  String toString() =>
      '${_prefix(namespace)}$name${version == null ? '' : '@$version'}';
}

/// Une dépendance de registre : un élément sans version et la contrainte que
/// sa version doit satisfaire.
final class ItemDependency {
  ItemDependency(this.ref, this.constraint)
    : assert(ref.version == null, 'the version goes through the constraint');

  /// `name@^1.0.0`, `@pro/name@>=1.0.0 <2.0.0`, ou `name` pour toute version.
  factory ItemDependency.parse(String text) {
    final (namespace, name, constraint) = _split(text);
    return ItemDependency(
      ItemRef(name, namespace: namespace),
      constraint == null
          ? VersionConstraint.any
          : VersionConstraint.parse(constraint),
    );
  }

  final ItemRef ref;
  final VersionConstraint constraint;

  @override
  String toString() => constraint.isAny ? '$ref' : '$ref@$constraint';
}

final _name = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');
final _ref = RegExp(r'^(?:(@[a-z0-9][a-z0-9-]*)/)?([^@/]+)(?:@(.+))?$');

(Namespace, String, String?) _split(String text) {
  final match = _ref.firstMatch(text);
  if (match == null) {
    throw FormatException('expected an @ns/name@version reference', text);
  }
  final namespace = match[1];
  return (
    namespace == null ? Namespace.fliin : Namespace._(namespace),
    match[2]!,
    match[3],
  );
}

String _prefix(Namespace namespace) =>
    namespace == Namespace.fliin ? '' : '${namespace.value}/';

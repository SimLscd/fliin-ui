/// Un document du format (manifeste, index, pointeur, lockfile, `fliin.yaml`)
/// viole son schéma. [path] situe le champ fautif : `$.files[0].sha256`.
sealed class ManifestError implements Exception {
  const ManifestError(this.path);

  final String path;

  String get reason;

  @override
  String toString() => '$path: $reason';
}

final class MissingField extends ManifestError {
  const MissingField(super.path);

  @override
  String get reason => 'missing field';
}

final class WrongJsonType extends ManifestError {
  const WrongJsonType(super.path, this.expected);

  final String expected;

  @override
  String get reason => 'expected $expected';
}

final class UnknownValue extends ManifestError {
  const UnknownValue(super.path, this.value, this.allowed);

  final String value;
  final List<String> allowed;

  @override
  String get reason =>
      'unknown value $value. Allowed values: ${allowed.join(', ')}';
}

final class InvalidVersion extends ManifestError {
  const InvalidVersion(super.path, this.value);

  final String value;

  @override
  String get reason => '$value: invalid semver version or constraint';
}

final class InvalidSha256 extends ManifestError {
  const InvalidSha256(super.path, this.value);

  final String value;

  @override
  String get reason => '$value: expected sha256:<64 lowercase hex>';
}

final class MalformedReference extends ManifestError {
  const MalformedReference(super.path, this.value);

  final String value;

  @override
  String get reason => '$value: invalid @ns/name@version reference';
}

final class InvalidValue extends ManifestError {
  const InvalidValue(super.path, this.reason);

  @override
  final String reason;
}

/// Un fichier du projet que le CLI lit et ne comprend pas : `fliin.yaml`,
/// `fliin.lock.json`, `pubspec.yaml`, une config d'agent. Sortie 1, le chemin
/// dans le message, jamais une trace Dart.
final class InvalidProjectFile implements Exception {
  const InvalidProjectFile(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}

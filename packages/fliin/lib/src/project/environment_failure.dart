/// Ce qui empêche le CLI de travailler sur ce projet : SDK absent, pas de
/// `pubspec.yaml`, outil du SDK en échec. Sortie 3.
final class EnvironmentFailure implements Exception {
  const EnvironmentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

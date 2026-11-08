import 'trusted_keys.dart';

/// Le registre officiel (ADR 0020 §3 et §5) : le même `dist/` signé par la
/// même clé, lu sur [publicUrl] sans clé de licence et sur [proUrl] avec,
/// Pro compris. Les tests en injectent un autre, jamais le CLI livré.
final class OfficialRegistry {
  OfficialRegistry({
    required this.publicUrl,
    required this.proUrl,
    required this.keys,
  });

  static final fliin = OfficialRegistry(
    publicUrl: Uri.parse('https://registry.fliin.dev/'),
    proUrl: Uri.parse('https://pro.fliin.dev/'),
    keys: officialKeys,
  );

  /// La page où l'on obtient une licence Pro.
  static const proPage = 'https://fliin.dev/pro';

  final Uri publicUrl;

  /// Le seul hôte qui reçoit la clé de licence.
  final Uri proUrl;

  /// Les clés publiques qui signent le registre officiel.
  final List<String> keys;
}

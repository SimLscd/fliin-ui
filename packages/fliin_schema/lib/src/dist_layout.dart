import 'package:pub_semver/pub_semver.dart';

import 'item_ref.dart';
import 'sha256.dart';

/// Les chemins du registre statique, relatifs à son URL de base.
abstract final class DistLayout {
  static const pointerPath = 'latest.json';

  static String blobPath(Sha256 sha256) =>
      'blobs/${sha256.hex.substring(0, 2)}/${sha256.hex}';

  static String manifestPath(ItemRef ref, Version version) =>
      'items/${ref.namespace.bare}/${ref.name}/$version.json';

  /// Adressé par son contenu, comme un blob : une publication n'écrase jamais
  /// le fragment que le pointeur précédent désigne.
  static String fragmentPath(Sha256 sha256) => 'index/${sha256.hex}.json';
}

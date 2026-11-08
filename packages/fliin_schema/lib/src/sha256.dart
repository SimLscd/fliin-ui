import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// Empreinte SHA-256 écrite `sha256:<64 hex minuscules>`. Deux empreintes ne se
/// comparent que sous cette forme unique, d'où le refus des majuscules.
extension type Sha256._(String value) {
  /// Lève une [FormatException] pour toute autre forme.
  factory Sha256.parse(String text) => _pattern.hasMatch(text)
      ? Sha256._(text)
      : throw FormatException('expected sha256:<64 lowercase hex>', text);

  Sha256.ofBytes(List<int> bytes)
    : value = 'sha256:${crypto.sha256.convert(bytes)}';

  Sha256.ofString(String text) : this.ofBytes(utf8.encode(text));

  /// Les 64 caractères hexadécimaux, sans le préfixe.
  String get hex => value.substring('sha256:'.length);

  static final _pattern = RegExp(r'^sha256:[0-9a-f]{64}$');
}

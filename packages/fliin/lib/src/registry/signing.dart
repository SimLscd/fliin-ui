import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;

/// La clé privée qui signe `latest.json`, hors CI, sur la machine de celui qui
/// publie. Le fichier contient la graine Ed25519 de 32 octets en base64.
final class SigningKey {
  SigningKey._(this._seed, this._keyPair, this.publicKey);

  static Future<SigningKey> fromSeed(List<int> seed) async {
    final keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return SigningKey._(
      List.unmodifiable(seed),
      keyPair,
      base64Encode(publicKey.bytes),
    );
  }

  static Future<SigningKey> generate() {
    final random = Random.secure();
    return fromSeed([for (var i = 0; i < 32; i++) random.nextInt(256)]);
  }

  /// Lève une [SigningKeyError] si le fichier est absent, mal formé, ou lisible
  /// par d'autres que son propriétaire.
  static Future<SigningKey> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) throw SigningKeyError(path, 'file not found');
    if (!Platform.isWindows && file.statSync().mode & 0x3f != 0) {
      throw SigningKeyError(path, 'readable by others. Run chmod 600');
    }
    final lines = [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final seed = switch (lines) {
      [_begin, final body, _end] => _tryBase64(body),
      _ => null,
    };
    if (seed == null || seed.length != 32) {
      throw SigningKeyError(path, 'expected a 32-byte Ed25519 seed in base64');
    }
    return fromSeed(seed);
  }

  final List<int> _seed;
  final SimpleKeyPair _keyPair;

  /// Base64 ; sert aussi d'identifiant de clé dans `latest.json`.
  final String publicKey;

  /// Crée le fichier en 0600 avant d'y écrire, et refuse d'écraser une clé.
  void write(String path) {
    final file = File(path);
    if (file.existsSync()) {
      throw SigningKeyError(
        path,
        'already exists. fliin does not overwrite it',
      );
    }
    file.createSync(recursive: true, exclusive: true);
    if (!Platform.isWindows) {
      final chmod = Process.runSync('chmod', ['600', path]);
      if (chmod.exitCode != 0) {
        file.deleteSync();
        throw SigningKeyError(path, 'chmod 600 failed: ${chmod.stderr}');
      }
    }
    file.writeAsStringSync('$_begin\n${base64Encode(_seed)}\n$_end\n');
  }

  Future<SignedPointer> sign(IndexPointer pointer) async {
    final payload = canonicalJson(pointer.toJson());
    final signature = await _ed25519.sign(
      utf8.encode(payload),
      keyPair: _keyPair,
    );
    return SignedPointer(
      payload: payload,
      signature: Uint8List.fromList(signature.bytes),
      keyId: publicKey,
    );
  }

  static const _begin = '-----BEGIN FLIIN SIGNING KEY-----';
  static const _end = '-----END FLIIN SIGNING KEY-----';
}

final class SigningKeyError implements Exception {
  const SigningKeyError(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}

/// Vérifie `latest.json` contre des clés publiques Ed25519 en base64, qui
/// servent aussi d'identifiants de clé.
final class Ed25519PointerVerifier implements PointerVerifier {
  /// Lève une [FormatException] si une clé n'est pas une clé publique de 32
  /// octets en base64.
  Ed25519PointerVerifier(Iterable<String> trustedKeys)
    : _trusted = {
        for (final key in trustedKeys)
          base64.decoder.convert(key).length == 32
              ? key
              : throw FormatException(
                  'expected a 32-byte Ed25519 public key',
                  key,
                ),
      };

  final Set<String> _trusted;

  @override
  bool trusts(String keyId) => _trusted.contains(keyId);

  @override
  Future<bool> verify(
    List<int> payload,
    List<int> signature,
    String keyId,
  ) async =>
      signature.length == 64 &&
      await _ed25519.verify(
        payload,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            base64Decode(keyId),
            type: KeyPairType.ed25519,
          ),
        ),
      );
}

final _ed25519 = Ed25519();

List<int>? _tryBase64(String text) {
  try {
    return base64Decode(text);
  } on FormatException {
    return null;
  }
}

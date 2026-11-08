import 'dart:io';

import 'package:fliin/src/registry/signing.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support.dart';

final _pointer = IndexPointer(
  version: 3,
  publishedAt: DateTime.utc(2026, 10, 18),
  expires: DateTime.utc(2026, 11, 1),
  minCli: Version(0, 1, 0),
  fragments: [(path: 'index/fliin.json', sha256: Sha256.ofString('x'))],
  yanked: const [],
);

Future<PointerDecision> _open(SignedPointer signed, List<String> trusted) =>
    signed.open(
      Ed25519PointerVerifier(trusted),
      cachedVersion: null,
      now: DateTime.utc(2026, 10, 20),
    );

void main() {
  group('SigningKey', () {
    test(
      'devrait relire la même clé quand elle vient d\'être écrite en 0600',
      () async {
        final path = p.join(tempDir().path, 'fliin-signing.key');
        final key = await SigningKey.generate();
        key.write(path);
        expect(File(path).statSync().mode & 0x1ff, 0x180);
        expect((await SigningKey.read(path)).publicKey, key.publicKey);
      },
      testOn: '!windows',
    );

    test(
      'devrait refuser d\'écraser une clé quand le fichier existe',
      () async {
        final path = p.join(tempDir().path, 'fliin-signing.key');
        (await testKey()).write(path);
        expect(
          () async => (await testKey(8)).write(path),
          throwsA(isA<SigningKeyError>()),
        );
        expect(
          (await SigningKey.read(path)).publicKey,
          (await testKey()).publicKey,
        );
      },
    );

    test('devrait refuser la clé quand d\'autres que son propriétaire peuvent la lire', () async {
      final path = p.join(tempDir().path, 'fliin-signing.key');
      (await testKey()).write(path);
      await Process.run('chmod', ['644', path]);
      expect(SigningKey.read(path), throwsA(isA<SigningKeyError>()));
    }, testOn: '!windows');

    test(
      'devrait refuser la clé quand le fichier n\'a pas le format attendu',
      () async {
        final path = p.join(tempDir().path, 'fliin-signing.key');
        (await testKey()).write(path);
        File(path).writeAsStringSync('pas une clé\n');
        expect(SigningKey.read(path), throwsA(isA<SigningKeyError>()));
      },
    );
  });

  group('Ed25519PointerVerifier', () {
    test('devrait accepter le pointeur quand il est signé par une clé de confiance', () async {
      final key = await testKey();
      final decision = await _open(await key.sign(_pointer), [key.publicKey]);
      expect(
        decision,
        isA<PointerAccepted>().having((a) => a.pointer.version, 'version', 3),
      );
    });

    test(
      'devrait refuser le pointeur quand un octet du contenu change',
      () async {
        final key = await testKey();
        final signed = await key.sign(_pointer);
        final forged = SignedPointer(
          payload: signed.payload.replaceFirst('"version":3', '"version":4'),
          signature: signed.signature,
          keyId: signed.keyId,
        );
        expect(
          await _open(forged, [key.publicKey]),
          isA<PointerRejected>().having(
            (r) => r.reason,
            'reason',
            PointerRejection.badSignature,
          ),
        );
      },
    );

    test(
      'devrait refuser le pointeur quand une autre clé l\'a signé sous ce nom',
      () async {
        final trusted = await testKey();
        final other = await (await testKey(8)).sign(_pointer);
        final mislabelled = SignedPointer(
          payload: other.payload,
          signature: other.signature,
          keyId: trusted.publicKey,
        );
        expect(
          await _open(mislabelled, [trusted.publicKey]),
          isA<PointerRejected>().having(
            (r) => r.reason,
            'reason',
            PointerRejection.badSignature,
          ),
        );
      },
    );

    test(
      'devrait refuser le pointeur quand sa clé n\'est pas de confiance',
      () async {
        final signed = await (await testKey()).sign(_pointer);
        expect(
          await _open(signed, [(await testKey(8)).publicKey]),
          isA<PointerRejected>().having(
            (r) => r.reason,
            'reason',
            PointerRejection.unknownKey,
          ),
        );
      },
    );
  });
}

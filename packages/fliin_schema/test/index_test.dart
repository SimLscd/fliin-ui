import 'dart:convert';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// Signe en hachant la clé et le contenu : changer un octet du contenu, ou la
/// clé, invalide la signature.
final class FakeVerifier implements PointerVerifier {
  static Uint8List sign(String keyId, List<int> payload) =>
      utf8.encode(Sha256.ofBytes([...utf8.encode(keyId), ...payload]).value);

  @override
  bool trusts(String keyId) => keyId == 'k1' || keyId == 'k2';

  @override
  Future<bool> verify(
    List<int> payload,
    List<int> signature,
    String keyId,
  ) async => base64Encode(signature) == base64Encode(sign(keyId, payload));
}

final publishedAt = DateTime.utc(2026, 10, 18, 15);
final expires = publishedAt.add(const Duration(days: 14));

IndexPointer pointer({int version = 42}) => IndexPointer(
  version: version,
  publishedAt: publishedAt,
  expires: expires,
  minCli: Version(0, 1, 0),
  fragments: [
    (
      path: DistLayout.fragmentPath(Sha256.ofString('fragment')),
      sha256: Sha256.ofString('fragment'),
    ),
  ],
  yanked: [ItemRef.parse('button@0.0.9')],
);

SignedPointer signed(IndexPointer pointer, {String keyId = 'k1'}) {
  final payload = canonicalJson(pointer.toJson());
  return SignedPointer(
    payload: payload,
    signature: FakeVerifier.sign(keyId, utf8.encode(payload)),
    keyId: keyId,
  );
}

Future<PointerDecision> open(
  SignedPointer pointer, {
  int? cachedVersion,
  DateTime? now,
}) => pointer.open(
  FakeVerifier(),
  cachedVersion: cachedVersion,
  now: now ?? publishedAt.add(const Duration(days: 1)),
);

Matcher rejectedFor(PointerRejection reason) =>
    isA<PointerRejected>().having((r) => r.reason, 'reason', reason);

Map<String, Object?> entryJson() => {
  'ref': 'button',
  'type': 'registry:component',
  'title': 'Bouton',
  'description': "Bouton d'action.",
  'categories': ['action'],
  'meta': {
    'tier': 'free',
    'platforms': ['ios', 'android'],
    'states': <String>[],
    'semanticsRoles': ['button'],
    'intents': {
      'fr': ["bouton d'action principal"],
      'en': ['primary action button'],
    },
    'notFor': <String>[],
  },
  'versions': [
    {
      'version': '0.1.0',
      'manifestSha256': Sha256.ofString('button@0.1.0').value,
      'flutter': '>=3.47.0 <4.0.0',
      'registryDependencies': ['core@^0.1.0'],
      'status': {'yanked': 'régression RTL'},
    },
    {
      'version': '0.1.1',
      'manifestSha256': Sha256.ofString('button@0.1.1').value,
      'flutter': '>=3.47.0 <4.0.0',
      'registryDependencies': ['core@^0.1.0'],
    },
  ],
};

void main() {
  group('IndexFragment', () {
    test('devrait réécrire exactement le JSON lu quand il est canonique', () {
      final json = {
        'schema': 1,
        'entries': [entryJson()],
      };
      expect(IndexFragment.fromJson(json).toJson(), json);
    });

    test('devrait lire les dépendances et le retrait de chaque version', () {
      final [yanked, current] = IndexEntry.fromJson(entryJson()).versions;
      expect(yanked.status, isA<Yanked>());
      expect(current.status, isA<Published>());
      expect('${current.registryDependencies.single}', 'core@^0.1.0');
    });

    test('devrait refuser un fragment quand son schéma est inconnu', () {
      expect(
        () => IndexFragment.fromJson({'schema': 2, 'entries': <Object>[]}),
        throwsA(isA<InvalidValue>().having((e) => e.path, 'path', r'$.schema')),
      );
    });

    test('devrait refuser une entrée quand sa référence porte une version', () {
      expect(
        () => IndexEntry.fromJson(entryJson()..['ref'] = 'button@0.1.0'),
        throwsA(
          isA<MalformedReference>().having((e) => e.path, 'path', r'$.ref'),
        ),
      );
    });
  });

  group('IndexPointer', () {
    test('devrait réécrire exactement le JSON lu quand il est canonique', () {
      final json = pointer().toJson();
      expect(
        IndexPointer.fromJson(jsonDecode(jsonEncode(json))).toJson(),
        json,
      );
      expect(json['publishedAt'], '2026-10-18T15:00:00.000Z');
    });

    test('devrait lire et réécrire un pointeur sans date d’expiration, et l’accepter des années plus tard (ADR 0020 §11)', () async {
      final json = pointer().toJson()..remove('expires');
      final read = IndexPointer.fromJson(jsonDecode(jsonEncode(json)));
      expect(read.expires, isNull);
      expect(read.toJson(), json);
      expect(
        await open(
          signed(read),
          now: publishedAt.add(const Duration(days: 3 * 365)),
        ),
        isA<PointerAccepted>(),
      );
    });

    test("devrait refuser une date quand elle n'est pas en UTC", () {
      final json = pointer().toJson()..['expires'] = '2026-11-01T15:00:00';
      expect(
        () => IndexPointer.fromJson(json),
        throwsA(
          isA<InvalidValue>().having((e) => e.path, 'path', r'$.expires'),
        ),
      );
    });

    test('devrait refuser un fragment quand son chemin sort du registre', () {
      final json = pointer().toJson()
        ..['fragments'] = [
          {'path': '../index/fliin.json', 'sha256': Sha256.ofString('x').value},
        ];
      expect(
        () => IndexPointer.fromJson(json),
        throwsA(
          isA<InvalidValue>().having(
            (e) => e.path,
            'path',
            r'$.fragments[0].path',
          ),
        ),
      );
    });
  });

  group('SignedPointer.open', () {
    test('devrait accepter le pointeur quand la signature, la date et la version tiennent', () async {
      final decision = await open(signed(pointer()), cachedVersion: 41);
      expect(
        decision,
        isA<PointerAccepted>().having((a) => a.pointer.version, 'version', 42),
      );
    });

    test('devrait accepter le pointeur quand aucun cache ne le précède ou quand il égale le cache', () async {
      expect(await open(signed(pointer())), isA<PointerAccepted>());
      expect(
        await open(signed(pointer()), cachedVersion: 42),
        isA<PointerAccepted>(),
      );
    });

    test('devrait accepter le pointeur quand il est relu depuis le JSON de latest.json', () async {
      final reread = SignedPointer.fromJson(
        jsonDecode(jsonEncode(signed(pointer()).toJson())),
      );
      expect(await open(reread), isA<PointerAccepted>());
    });

    test(
      'devrait refuser le pointeur quand un octet du contenu change',
      () async {
        final original = signed(pointer());
        final forged = SignedPointer(
          payload: original.payload.replaceFirst(
            '"version":42',
            '"version":43',
          ),
          signature: original.signature,
          keyId: original.keyId,
        );
        expect(await open(forged), rejectedFor(PointerRejection.badSignature));
      },
    );

    test(
      "devrait refuser le pointeur quand la signature vient d'une autre clé",
      () async {
        final other = signed(pointer(), keyId: 'k2');
        final mislabelled = SignedPointer(
          payload: other.payload,
          signature: other.signature,
          keyId: 'k1',
        );
        expect(
          await open(mislabelled),
          rejectedFor(PointerRejection.badSignature),
        );
      },
    );

    test(
      "devrait refuser le pointeur quand la clé n'est pas de confiance",
      () async {
        expect(
          await open(signed(pointer(), keyId: 'inconnue')),
          rejectedFor(PointerRejection.unknownKey),
        );
      },
    );

    test(
      'devrait refuser le pointeur quand il est expiré (règle 12)',
      () async {
        expect(
          await open(signed(pointer()), now: expires),
          rejectedFor(PointerRejection.expired),
        );
        expect(
          await open(
            signed(pointer()),
            now: expires.add(const Duration(seconds: 1)),
          ),
          rejectedFor(PointerRejection.expired),
        );
      },
    );

    test('devrait refuser le pointeur quand il est plus ancien que le cache (règle 12)', () async {
      expect(
        await open(signed(pointer(version: 41)), cachedVersion: 42),
        rejectedFor(PointerRejection.olderThanCache),
      );
    });
  });

  group('DistLayout', () {
    test('devrait ranger un blob sous les deux premiers caractères de son empreinte', () {
      final sha = Sha256.ofString('abc');
      expect(DistLayout.blobPath(sha), 'blobs/ba/${sha.hex}');
    });

    test('devrait ranger un manifeste par espace de noms, nom et version', () {
      expect(
        DistLayout.manifestPath(
          ItemRef.parse('@pro/confirm-sheet'),
          Version(1, 0, 0),
        ),
        'items/pro/confirm-sheet/1.0.0.json',
      );
      expect(
        DistLayout.manifestPath(ItemRef.parse('button'), Version(0, 1, 0)),
        'items/fliin/button/0.1.0.json',
      );
    });

    test('devrait nommer le fragment par son empreinte et le pointeur en dernier quand on les publie', () {
      final sha256 = Sha256.ofString('fragment');
      expect(DistLayout.fragmentPath(sha256), 'index/${sha256.hex}.json');
      expect(DistLayout.pointerPath, 'latest.json');
    });
  });
}

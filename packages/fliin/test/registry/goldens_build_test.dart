import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'support.dart';

const _rendering = {
  'abi': 'macos-arm64',
  'flutter': '3.47.7',
  'fonts': {'SFNS.ttf': '2f7e3871468bf56b'},
};

/// Une source copiée dont [item] n'a que les goldens de référence que le
/// test écrit : un PNG factice par variante de [ids].
String _sourceWithGoldens(String item, Iterable<String> ids) {
  final source = copiedSource();
  final dir = Directory(p.join(source, SourceRegistry.referenceGoldens));
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  File(p.join(dir.path, SourceRegistry.renderingFile))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(_rendering));
  for (final id in ids) {
    File(p.join(dir.path, item, '$id.png'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, ...utf8.encode(id)]);
  }
  return source;
}

Future<String> _build(String source) async {
  final dist = tempDir().path;
  await DistWriter(dist).write(
    SourceRegistry.read(source),
    stamp: BuildStamp(version: 1, publishedAt: DateTime.utc(2026, 10, 19)),
    key: await testKey(),
  );
  return dist;
}

/// Le manifeste publié de [name] dans [dist], à la version que son
/// manifeste source porte dans [source] : un test qui vise un élément suit
/// sa version au lieu de l'écrire en dur.
ItemManifest _published(String dist, String source, String name) =>
    ItemManifest.fromJson(
      jsonDecode(File(_manifestPath(dist, source, name)).readAsStringSync()),
    );

String _manifestPath(String dist, String source, String name) => p.join(
  dist,
  DistLayout.manifestPath(
    ItemRef(name),
    Version.parse(sourceVersion(name, root: source)),
  ),
);

Matcher _refused(String reason) => throwsA(
  isA<InvalidSourceManifest>().having(
    (e) => e.reason,
    'reason',
    contains(reason),
  ),
);

void main() {
  test('devrait publier chaque golden de référence comme blob et le désigner par sa variante dans le manifeste signé', () async {
    final source = _sourceWithGoldens('switch', variantIds);
    final dist = await _build(source);
    final goldens = _published(dist, source, 'switch').verify!.goldens!;
    expect(goldens.host, GoldenHost.macos);
    expect(goldens.rendering.toJson(), _rendering);
    expect(goldens.variants.keys, variantIds);
    for (final MapEntry(key: id, value: sha256) in goldens.variants.entries) {
      final png = File(
        p.join(source, SourceRegistry.referenceGoldens, 'switch', '$id.png'),
      ).readAsBytesSync();
      expect(sha256, Sha256.ofBytes(png), reason: id);
      expect(
        File(p.join(dist, DistLayout.blobPath(sha256))).readAsBytesSync(),
        png,
        reason: id,
      );
    }
    expect(_published(dist, source, 'radio').verify!.goldens, isNull);
  });

  test('devrait refuser un élément dont un golden de référence manque, en nommant la variante', () {
    final source = _sourceWithGoldens('switch', variantIds.skip(1));
    expect(
      () => SourceRegistry.read(source),
      _refused('Missing: ${variantIds.first}'),
    );
  });

  test(
    'devrait refuser un golden de référence qui ne nomme aucune variante',
    () {
      final source = _sourceWithGoldens('switch', [
        ...variantIds,
        'web.light.1.0.ltr',
      ]);
      expect(
        () => SourceRegistry.read(source),
        _refused('Unknown: web.light.1.0.ltr.png'),
      );
    },
  );

  test(
    'devrait refuser des goldens de référence pour un élément sans verify',
    () {
      final source = _sourceWithGoldens('switch', variantIds);
      final manifest = File(p.join(source, 'items', 'switch.json'));
      final json =
          jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>
            ..remove('verify');
      manifest.writeAsStringSync(jsonEncode(json));
      expect(() => SourceRegistry.read(source), _refused('without verify'));
    },
  );

  test(
    'devrait refuser des goldens déclarés à la main dans le manifeste source',
    () {
      final source = _sourceWithGoldens('switch', const []);
      final manifest = File(p.join(source, 'items', 'switch.json'));
      final json =
          jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
      (json['verify']! as Map<String, Object?>)['goldens'] = {
        'host': 'macos',
        'rendering': _rendering,
        'variants': {
          for (final id in variantIds) id: Sha256.ofString(id).value,
        },
      };
      manifest.writeAsStringSync(jsonEncode(json));
      expect(
        () => SourceRegistry.read(source),
        _refused('computed at publish time'),
      );
    },
  );

  test('devrait reconstruire une version publiée sans changer son manifeste quand ses goldens de référence ont été régénérés', () async {
    final source = _sourceWithGoldens('switch', variantIds);
    final dist = tempDir().path;
    Future<void> build(int version) async => DistWriter(dist).write(
      SourceRegistry.read(source),
      stamp: BuildStamp(
        version: version,
        publishedAt: DateTime.utc(2026, 10, 19),
      ),
      key: await testKey(),
    );
    await build(1);
    final path = _manifestPath(dist, source, 'switch');
    final published = File(path).readAsBytesSync();
    final first = _published(dist, source, 'switch').verify!.goldens!;
    File(
      p.join(
        source,
        SourceRegistry.referenceGoldens,
        'switch',
        '${variantIds.first}.png',
      ),
    ).writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, 0, 1, 2]);
    await build(2);
    expect(File(path).readAsBytesSync(), published);
    expect(
      File(p.join(dist, DistLayout.blobPath(first.variants[variantIds.first]!)))
          .existsSync(),
      isTrue,
    );
  });

  test('devrait refuser des goldens de référence sans rendering.json qui dise ce qui les a rendus', () {
    final source = _sourceWithGoldens('switch', variantIds);
    File(
      p.join(
        source,
        SourceRegistry.referenceGoldens,
        SourceRegistry.renderingFile,
      ),
    ).deleteSync();
    expect(
      () => SourceRegistry.read(source),
      _refused('Regenerate the reference goldens'),
    );
  });
}

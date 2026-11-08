import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin/fliin.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Le registre source du dépôt (`flutter/registry/`) servi en mémoire, les
/// empreintes calculées à la volée. [missing] simule des blobs que le registre
/// ne sert pas ; [extraDependencies] ajoute des dépendances pub à un élément ;
/// [broken] remplace des fichiers (relatifs à `lib/`) par du Dart qui se
/// parse mais ne passe pas l'analyse ; [versions] publie des éléments sous une autre version, avec
/// un contenu différent ; [tampered] sert, pour ces fichiers, des octets dont l'empreinte n'est pas
/// celle annoncée, ce qu'un vrai client refuserait avant l'installeur ;
/// [servesPro] faux est le registre officiel lu sans clé de licence.
final class FakeRegistry implements Registry {
  FakeRegistry({
    this.servesPro = true,
    this.missing = const {},
    this.extraDependencies = const {},
    this.broken = const {},
    this.versions = const {},
    this.tampered = const {},
  }) {
    final items = Directory(p.join(source.path, 'items'));
    for (final file in items.listSync().whereType<File>()) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final name = json['name']! as String;
      for (final entry
          in (json['files']! as List<Object?>).cast<Map<String, Object?>>()) {
        final path = entry['path']! as String;
        final bytes = broken.contains(path)
            ? utf8.encode('final Object broken = Undefined();\n')
            : Uint8List.fromList([
                ...File(p.join(source.path, 'lib', path)).readAsBytesSync(),
                if (versions[name] case final version?)
                  ...utf8.encode('\n// $version\n'),
              ]);
        final sha256 = Sha256.ofBytes(bytes);
        entry['sha256'] = sha256.value;
        blobs[sha256] = tampered.contains(path)
            ? Uint8List.fromList([...bytes, ...utf8.encode('// altéré\n')])
            : bytes;
        for (final variant
            in (entry['variants'] as Map<String, Object?>? ?? const {}).values
                .cast<Map<String, Object?>>()) {
          final raw = File(
            p.join(source.path, 'lib', variant['path']! as String),
          ).readAsBytesSync();
          variant['sha256'] = Sha256.ofBytes(raw).value;
          blobs[Sha256.ofBytes(raw)] = raw;
        }
      }
      json['dependencies'] = {
        ...(json['dependencies']! as Map<String, Object?>),
        ...?extraDependencies[name],
      };
      if (versions[name] case final version?) json['version'] = version;
      final manifest = ItemManifest.fromJson(json);
      manifests[ItemRef(manifest.name)] = manifest;
    }
  }

  static final source = Directory(
    p.normalize(
      p.join(Directory.current.path, '..', '..', 'flutter', 'registry'),
    ),
  );

  @override
  final bool servesPro;
  final Set<Sha256> missing;
  final Map<String, Map<String, String>> extraDependencies;
  final Set<String> broken;
  final Map<String, String> versions;
  final Set<String> tampered;
  final manifests = <ItemRef, ItemManifest>{};
  final blobs = <Sha256, Uint8List>{};

  /// L'empreinte du fichier source [path] (relatif à `lib/`), pour [missing].
  static Sha256 shaOf(String path) =>
      Sha256.ofBytes(File(p.join(source.path, 'lib', path)).readAsBytesSync());

  @override
  Future<IndexPointer> fetchPointer() async {
    final now = DateTime.now().toUtc();
    return IndexPointer(
      version: 1,
      publishedAt: now,
      expires: now.add(const Duration(days: 1)),
      minCli: Version(0, 1, 0),
      fragments: [(path: 'index/fliin.json', sha256: Sha256.ofString('fliin'))],
      yanked: const [],
    );
  }

  @override
  Future<IndexFragment> fetchFragment(FragmentRef fragment) async =>
      IndexFragment([
        for (final MapEntry(key: ref, value: manifest) in manifests.entries)
          IndexEntry(
            ref: ref,
            type: manifest.type,
            title: manifest.title,
            description: manifest.description,
            categories: manifest.categories,
            meta: manifest.meta,
            versions: [
              IndexVersion(
                version: manifest.version,
                manifestSha256: Sha256.ofString(
                  canonicalJson(manifest.toJson()),
                ),
                flutter: manifest.flutter,
                registryDependencies: manifest.registryDependencies,
              ),
            ],
          ),
      ]);

  @override
  Future<ItemManifest> fetchManifest(ItemRef ref, Version version) async {
    final manifest = manifests[ItemRef(ref.name, namespace: ref.namespace)];
    if (manifest == null || manifest.version != version) {
      throw MissingArtifact(DistLayout.manifestPath(ref, version));
    }
    return manifest;
  }

  @override
  Future<Uint8List> fetchBlob(Sha256 sha256) async {
    final bytes = blobs[sha256];
    if (bytes == null || missing.contains(sha256)) {
      throw MissingArtifact(DistLayout.blobPath(sha256));
    }
    return bytes;
  }
}

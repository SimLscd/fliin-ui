import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../cli_version.dart';
import 'public_api.dart';
import 'signing.dart';

/// La source du registre (`flutter/registry`) : les manifestes de
/// `items/*.json`, les fichiers de `lib/` qu'ils listent, et les goldens de
/// référence de [referenceGoldens].
final class SourceRegistry {
  SourceRegistry._(
    this.manifests,
    this.blobs, {
    this.keepsProCode = true,
    Map<Sha256, Uint8List>? sources,
  }) : _sources = sources ?? blobs;

  /// `<élément>/<variante>.png` : le rendu de `verify.entry` par le harnais,
  /// jetons par défaut, que `flutter test --update-goldens` n'écrit que sous
  /// macOS (ADR 0005), d'où [GoldenHost.macos] (ADR 0011).
  static const referenceGoldens = 'test/goldens/reference';

  /// Calcule `files[].sha256` sur le brut aux fins de ligne LF. Lève une
  /// [BuildError] si un manifeste est invalide ou si un fichier manque.
  static SourceRegistry read(String root) {
    final items = Directory(p.join(root, 'items'));
    if (!items.existsSync()) {
      throw InvalidSourceManifest(items.path, 'folder not found');
    }
    final files =
        items
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final manifests = <ItemManifest>[];
    final blobs = <Sha256, Uint8List>{};
    for (final file in files) {
      final ItemManifest manifest;
      try {
        final json = jsonDecode(file.readAsStringSync());
        final draft = ItemManifest.fromJson(
          _withSha256(json, (_, _) => _draft),
        );
        final hashes = [
          for (final entry in draft.files)
            (
              file: _blob(root, file.path, entry.path, blobs),
              variants: {
                for (final MapEntry(:key, :value) in entry.variants.entries)
                  key: _blob(root, file.path, value.path, blobs),
              },
            ),
        ];
        for (final (i, entry) in draft.files.indexed) {
          for (final MapEntry(key: name, value: variant)
              in entry.variants.entries) {
            _sameApi(
              file.path,
              entry.path,
              variant.path,
              blobs[hashes[i].file]!,
              blobs[hashes[i].variants[name]!]!,
            );
          }
        }
        manifest = _withGoldens(
          root,
          file.path,
          ItemManifest.fromJson(
            _withSha256(
              json,
              (i, variant) => variant == null
                  ? hashes[i].file
                  : hashes[i].variants[variant]!,
            ),
          ),
          blobs,
        );
      } on FormatException catch (e) {
        throw InvalidSourceManifest(file.path, e.message);
      } on ManifestError catch (e) {
        throw InvalidSourceManifest(file.path, '$e');
      }
      if ('${manifest.name}.json' != p.basename(file.path)) {
        throw InvalidSourceManifest(
          file.path,
          'the name ${manifest.name} must match the file name',
        );
      }
      if (manifest.changelog?.trim().isEmpty ?? false) {
        throw InvalidSourceManifest(
          file.path,
          r'$.changelog: empty. Remove the field or write what changes',
        );
      }
      for (final (i, change) in manifest.breaking.indexed) {
        if (change is! SemanticBreak) {
          throw InvalidSourceManifest(
            file.path,
            '\$.breaking[$i]: only "semantic" is declared by hand. The '
            'rest is computed at publish time',
          );
        }
      }
      manifests.add(manifest);
    }
    return SourceRegistry._(manifests, blobs);
  }

  /// Triés par nom.
  final List<ItemManifest> manifests;

  /// Chaque fichier brut servi, adressé par son empreinte.
  final Map<Sha256, Uint8List> blobs;

  /// Chaque fichier brut de la source, code Pro compris : de quoi calculer
  /// les cassures d'une version Pro que le registre public ne sert pas.
  final Map<Sha256, Uint8List> _sources;

  /// Faux après [withoutProCode] : le registre écrit depuis cette source ne
  /// sert le code d'aucun élément Pro, pas même d'une version déjà dans
  /// `out/`.
  final bool keepsProCode;

  /// Tous les manifestes, sans le code des éléments `tier: pro` : le
  /// registre public les fait connaître (recherche, MCP, `add` qui dit quoi
  /// faire) sans les servir, et garde leurs goldens de référence, que le site
  /// montre déjà (ADR 0020 §4). Un blob qu'un élément gratuit désigne aussi
  /// reste. Lève [ProDependency] quand un élément gratuit exige un élément
  /// Pro : il ne s'installerait plus.
  SourceRegistry withoutProCode() {
    final pro = {
      for (final manifest in manifests)
        if (manifest.meta.tier == Tier.pro) manifest.name,
    };
    for (final manifest in manifests) {
      if (pro.contains(manifest.name)) continue;
      for (final dependency in manifest.registryDependencies) {
        if (dependency.ref.namespace == Namespace.fliin &&
            pro.contains(dependency.ref.name)) {
          throw ProDependency(manifest.name, dependency.ref.name);
        }
      }
    }
    final code = proCode(manifests);
    return SourceRegistry._(
      manifests,
      {
        for (final MapEntry(:key, :value) in blobs.entries)
          if (!code.contains(key)) key: value,
      },
      keepsProCode: false,
      sources: blobs,
    );
  }

  /// Les blobs de code des éléments Pro de [manifests] (fichiers et
  /// variantes, pas les goldens) qu'aucun élément gratuit ne désigne.
  static Set<Sha256> proCode(Iterable<ItemManifest> manifests) {
    Iterable<Sha256> codeOf(ItemManifest manifest) => [
      for (final file in manifest.files) ...[
        file.sha256,
        for (final variant in file.variants.values) variant.sha256,
      ],
    ];
    final free = {
      for (final manifest in manifests)
        if (manifest.meta.tier != Tier.pro) ...codeOf(manifest),
    };
    return {
      for (final manifest in manifests)
        if (manifest.meta.tier == Tier.pro) ...codeOf(manifest),
    }.difference(free);
  }

  /// Une variante remplace son fichier chez l'app qui la choisit : elle en
  /// garde l'API publique, symbole pour symbole, sinon le code qui l'appelle
  /// (les composants qui lisent `FlIcons.chevronRight`) ne compilerait plus.
  static void _sameApi(
    String manifest,
    String path,
    String variant,
    Uint8List file,
    Uint8List other,
  ) {
    if (!path.endsWith('.dart')) return;
    final base = publicApi([utf8.decode(file)]);
    final chosen = publicApi([utf8.decode(other)]);
    final changes = [...apiBreaks(base, chosen), ...apiBreaks(chosen, base)];
    if (changes.isNotEmpty) {
      throw InvalidSourceManifest(
        manifest,
        '$variant, a variant of $path, does not have the same public API: '
        '${changes.map((change) => change.toJson()).join('; ')}',
      );
    }
  }

  /// Une première lecture valide les chemins avant qu'on lise les fichiers.
  static final _draft = Sha256.ofBytes(const []);

  /// [json] avec `sha256` ajouté à chaque fichier et à chacune de ses
  /// variantes. Une forme inattendue passe telle quelle :
  /// `ItemManifest.fromJson` la refuse avec son chemin.
  static Object? _withSha256(
    Object? json,
    Sha256 Function(int i, String? variant) hash,
  ) => switch (json) {
    final Map<Object?, Object?> map && {'files': final List<Object?> files} => {
      ...map,
      'files': [
        for (final (i, entry) in files.indexed)
          switch (entry) {
            final Map<Object?, Object?> entry => {
              ...entry,
              'sha256': hash(i, null).value,
              if (entry['variants'] case final Map<Object?, Object?> variants)
                'variants': {
                  for (final MapEntry(:key, :value) in variants.entries)
                    key: value is Map<Object?, Object?> && key is String
                        ? {...value, 'sha256': hash(i, key).value}
                        : value,
                },
            },
            _ => entry,
          },
      ],
    },
    _ => json,
  };

  static Sha256 _blob(
    String root,
    String manifest,
    String path,
    Map<Sha256, Uint8List> blobs,
  ) {
    final file = File(p.join(root, 'lib', path));
    if (!file.existsSync()) throw MissingSourceFile(manifest, path);
    final raw = _lineFeeds(file.readAsBytesSync());
    final sha256 = Sha256.ofBytes(raw);
    blobs[sha256] = raw;
    return sha256;
  }

  /// [manifest] avec `verify.goldens` lu de [referenceGoldens] : les seize
  /// variantes ou aucune, et jamais déclaré à la main.
  static ItemManifest _withGoldens(
    String root,
    String path,
    ItemManifest manifest,
    Map<Sha256, Uint8List> blobs,
  ) {
    if (manifest.verify?.goldens != null) {
      throw InvalidSourceManifest(
        path,
        '\$.verify.goldens: computed at publish time from '
        '$referenceGoldens/${manifest.name}/. Do not declare it',
      );
    }
    final dir = Directory(p.join(root, referenceGoldens, manifest.name));
    if (!dir.existsSync()) return manifest;
    final verify = manifest.verify;
    if (verify == null) {
      throw InvalidSourceManifest(
        path,
        '${dir.path} exists, but without verify nothing says what these '
        'goldens render',
      );
    }
    final pngs = {
      for (final file in dir.listSync().whereType<File>())
        if (file.path.endsWith('.png'))
          p.basenameWithoutExtension(file.path): file,
    };
    final missing = [
      for (final id in variantIds)
        if (!pngs.containsKey(id)) id,
    ];
    final unknown = [
      for (final id in pngs.keys)
        if (!variantIds.contains(id)) '$id.png',
    ]..sort();
    if (missing.isNotEmpty || unknown.isNotEmpty) {
      throw InvalidSourceManifest(
        dir.path,
        'expected all 16 reference goldens or none'
        '${missing.isEmpty ? '' : '. Missing: ${missing.join(', ')}'}'
        '${unknown.isEmpty ? '' : '. Unknown: ${unknown.join(', ')}'}',
      );
    }
    final variants = <String, Sha256>{};
    for (final id in variantIds) {
      final bytes = pngs[id]!.readAsBytesSync();
      final sha256 = Sha256.ofBytes(bytes);
      blobs[sha256] = bytes;
      variants[id] = sha256;
    }
    return ItemManifest.fromJson({
      ...manifest.toJson(),
      'verify': {
        ...verify.toJson(),
        'goldens': ItemGoldens(
          host: GoldenHost.macos,
          rendering: _rendering(root),
          variants: variants,
        ).toJson(),
      },
    });
  }

  /// `rendering.json` à côté des goldens de référence : l'architecture, la
  /// version de Flutter et les polices du rendu qui les a produits, que
  /// `test/reference_goldens_test.dart` écrit avec eux.
  static Rendering _rendering(String root) {
    final file = File(p.join(root, referenceGoldens, renderingFile));
    if (!file.existsSync()) {
      throw InvalidSourceManifest(
        file.path,
        'not found. Regenerate the reference goldens, which write it',
      );
    }
    try {
      return Rendering.fromJson(jsonDecode(file.readAsStringSync()));
    } on FormatException catch (e) {
      throw InvalidSourceManifest(file.path, e.message);
    } on ManifestError catch (e) {
      throw InvalidSourceManifest(file.path, '$e');
    }
  }

  static const renderingFile = 'rendering.json';

  /// Un fichier binaire reste tel quel.
  static Uint8List _lineFeeds(Uint8List bytes) {
    try {
      return utf8.encode(utf8.decode(bytes).replaceAll('\r\n', '\n'));
    } on FormatException {
      return bytes;
    }
  }
}

/// La version, la date et les retraits d'une publication. La version suit
/// celle du `latest.json` déjà dans `out/`, jamais un compte de commits qui
/// recule après un rebase ou dans un clone superficiel ; la date est celle
/// de la signature ; les retraits s'ajoutent à ceux du `latest.json`
/// précédent, puisque le pointeur est la seule source du retrait (règle 12).
final class BuildStamp {
  BuildStamp({
    required this.version,
    required DateTime publishedAt,
    this.yanked = const [],
    this.previous,
    this.lifetime,
  }) : publishedAt = publishedAt.toUtc();

  /// Le pointeur de [out] plus un (1 s'il n'y en a pas), ou [version] s'il
  /// est donné ; lève [PointerVersionNotIncreasing] si ce n'est pas plus
  /// grand que la version déjà publiée (règle 12). [yank] s'ajoute aux
  /// retraits déjà publiés.
  static BuildStamp following(
    String out, {
    int? version,
    DateTime? now,
    List<ItemRef> yank = const [],
  }) {
    final published = _published(out);
    final previous = published?.version;
    final next = version ?? (previous ?? 0) + 1;
    if (previous != null && next <= previous) {
      throw PointerVersionNotIncreasing(next, previous);
    }
    final yanked = {
      for (final ref in [...?published?.yanked, ...yank]) '$ref': ref,
    };
    return BuildStamp(
      version: next,
      publishedAt: now ?? DateTime.now(),
      yanked: [for (final key in yanked.keys.toList()..sort()) yanked[key]!],
      previous: previous,
    );
  }

  final int version;
  final DateTime publishedAt;

  /// Chaque référence porte sa version.
  final List<ItemRef> yanked;

  /// La version du `latest.json` que ce build remplace, null s'il n'y en
  /// avait pas : le pointeur repart alors de 1, et un client qui a vu plus
  /// haut le refusera.
  final int? previous;

  /// Null pour une publication : le pointeur n'expire pas (ADR 0020 §11).
  /// Les tests de la règle 12 en donnent une.
  final Duration? lifetime;

  DateTime? get expires => lifetime == null ? null : publishedAt.add(lifetime!);

  static IndexPointer? _published(String out) {
    final file = File(p.join(out, DistLayout.pointerPath));
    if (!file.existsSync()) return null;
    try {
      final signed = SignedPointer.fromJson(
        jsonDecode(file.readAsStringSync()),
      );
      return IndexPointer.fromJson(jsonDecode(signed.payload));
    } on FormatException catch (e) {
      throw UnreadablePublished(file.path, e.message, _pointerRemedy);
    } on ManifestError catch (e) {
      throw UnreadablePublished(file.path, '$e', _pointerRemedy);
    }
  }

  static const _pointerRemedy =
      'delete it, then run the build again with a --version higher than the '
      'last published one and a --yank for each yanked version to keep';
}

typedef DistSummary = ({int items, int blobs, int pointerVersion});

typedef _Release = ({ItemManifest manifest, Sha256 sha256});

/// Écrit `dist/` selon [DistLayout] : blobs, manifestes, fragment, puis
/// `latest.json` en dernier. Le fragment reprend toutes les versions déjà
/// publiées dans `out/` : une version ne sort de l'index que par `yanked` du
/// pointeur (règle 12).
final class DistWriter {
  DistWriter(this.out, {this.blobsFrom});

  final String out;

  /// Un autre `dist/` où lire le blob d'une version déjà publiée qui manque
  /// à [out] : le registre Pro, pour que le registre public, qui n'a pas le
  /// code Pro, calcule les cassures d'une nouvelle version Pro comme lui.
  final String? blobsFrom;

  /// Lève [PublishedVersionChanged], avant toute écriture, si un manifeste
  /// déjà publié dans [out] diffère de celui qu'on écrirait (règle 2), et
  /// [UnknownYank] si un retrait vise une version qui n'est pas publiée.
  Future<DistSummary> write(
    SourceRegistry source, {
    required BuildStamp stamp,
    required SigningKey key,
    Namespace namespace = Namespace.fliin,
  }) async {
    String pathOf(ItemManifest manifest) => DistLayout.manifestPath(
      ItemRef(manifest.name, namespace: namespace),
      manifest.version,
    );
    final releases = _publishedReleases(namespace);
    if (!source.keepsProCode) {
      final code = SourceRegistry.proCode([
        ...source.manifests,
        for (final versions in releases.values)
          for (final (:manifest, sha256: _) in versions.values) manifest,
      ]);
      for (final sha256 in code) {
        final blob = p.join(out, DistLayout.blobPath(sha256));
        if (File(blob).existsSync()) throw ProAlreadyInOut(blob);
      }
    }
    final drafts = [
      for (final draft in source.manifests)
        _withBreaking(draft, releases[draft.name], source._sources),
    ];
    final manifests = {
      for (final manifest in drafts)
        manifest: utf8.encode(canonicalJson(manifest.toJson())),
    };
    for (final MapEntry(key: manifest, value: bytes) in manifests.entries) {
      final sha256 = Sha256.ofBytes(bytes);
      final published = releases[manifest.name]?[manifest.version];
      if (published != null && published.sha256 != sha256) {
        throw PublishedVersionChanged(p.join(out, pathOf(manifest)));
      }
      releases.putIfAbsent(manifest.name, () => {})[manifest.version] = (
        manifest: manifest,
        sha256: sha256,
      );
    }
    for (final ref in stamp.yanked) {
      if (ref.namespace != namespace ||
          releases[ref.name]?[ref.version!] == null) {
        throw UnknownYank(ref);
      }
    }

    for (final MapEntry(key: sha256, value: bytes) in source.blobs.entries) {
      _writeBlob(sha256, bytes);
    }
    for (final MapEntry(key: manifest, value: bytes) in manifests.entries) {
      _write(pathOf(manifest), bytes);
    }
    final fragment = IndexFragment([
      for (final name in releases.keys.toList()..sort())
        _entry(ItemRef(name, namespace: namespace), releases[name]!),
    ]);
    final fragmentBytes = utf8.encode(canonicalJson(fragment.toJson()));
    final fragmentPath = DistLayout.fragmentPath(Sha256.ofBytes(fragmentBytes));
    _write(fragmentPath, fragmentBytes);

    final pointer = await key.sign(
      IndexPointer(
        version: stamp.version,
        publishedAt: stamp.publishedAt,
        expires: stamp.expires,
        minCli: Version.parse(cliVersion),
        fragments: [
          (path: fragmentPath, sha256: Sha256.ofBytes(fragmentBytes)),
        ],
        yanked: stamp.yanked,
      ),
    );
    _write(
      DistLayout.pointerPath,
      utf8.encode(canonicalJson(pointer.toJson())),
    );
    return (
      items: releases.length,
      blobs: source.blobs.length,
      pointerVersion: stamp.version,
    );
  }

  /// [draft] avec ses cassures : celles que le diff de l'API publique trouve
  /// depuis la plus haute version publiée avant elle, puis celles que
  /// l'auteur déclare. Une publication ne peut donc pas en déclarer moins
  /// que le diff n'en trouve.
  ///
  /// Une version déjà publiée garde les cassures et le changelog de son
  /// manifeste : une version intercalée depuis changerait sa « précédente »
  /// et donc ses cassures, et la règle 2 refuserait la reconstruction. Elle
  /// garde aussi ses goldens de référence : des références régénérées
  /// (nouvel hôte, nouveau SDK) ne valent que pour les versions suivantes,
  /// et les blobs déjà publiés restent servis.
  ItemManifest _withBreaking(
    ItemManifest draft,
    Map<Version, _Release>? published,
    Map<Sha256, Uint8List> blobs,
  ) {
    if (published?[draft.version]?.manifest case final existing?) {
      final verify = draft.verify?.toJson()?..remove('goldens');
      return ItemManifest.fromJson({
        ...draft.toJson()
          ..remove('changelog')
          ..remove('breaking')
          ..remove('verify'),
        if (verify != null)
          'verify': {...verify, 'goldens': ?existing.verify?.goldens?.toJson()},
        'changelog': ?existing.changelog,
        if (existing.breaking.isNotEmpty)
          'breaking': [for (final change in existing.breaking) change.toJson()],
      });
    }
    final previous = (published?.keys ?? const <Version>[])
        .where((v) => v < draft.version)
        .fold<Version?>(null, (best, v) => best == null || v > best ? v : best);
    if (previous == null) return draft;
    final before = published![previous]!.manifest;
    final computed = [
      ...fileBreaks(
        [for (final file in before.files) '${file.target}'],
        [for (final file in draft.files) '${file.target}'],
      ),
      ...apiBreaks(
        publicApi(_dartSources(before, _publishedBlob)),
        publicApi(_dartSources(draft, (sha256) => blobs[sha256]!)),
      ),
    ];
    final breaking = {...computed, ...draft.breaking}.toList();
    if (breaking.isEmpty) return draft;
    return ItemManifest.fromJson({
      ...draft.toJson(),
      'breaking': [for (final change in breaking) change.toJson()],
    });
  }

  Iterable<String> _dartSources(
    ItemManifest manifest,
    Uint8List Function(Sha256 sha256) bytes,
  ) => [
    for (final file in manifest.files)
      if (file.path.endsWith('.dart')) utf8.decode(bytes(file.sha256)),
  ];

  Uint8List _publishedBlob(Sha256 sha256) {
    final file = File(p.join(out, DistLayout.blobPath(sha256)));
    if (file.existsSync()) return file.readAsBytesSync();
    if (blobsFrom case final other?) {
      final elsewhere = File(p.join(other, DistLayout.blobPath(sha256)));
      if (elsewhere.existsSync()) return elsewhere.readAsBytesSync();
    }
    throw UnreadablePublished(
      file.path,
      'blob not found',
      'restore it from the published registry. For the code of a Pro item, '
          'pass --blobs-from with the Pro dist/',
    );
  }

  /// Les manifestes déjà sous `items/<ns>/` de [out], par nom puis version.
  Map<String, Map<Version, _Release>> _publishedReleases(Namespace namespace) {
    final items = Directory(p.join(out, 'items', namespace.bare));
    if (!items.existsSync()) return {};
    final releases = <String, Map<Version, _Release>>{};
    for (final file in items.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final bytes = file.readAsBytesSync();
      final ItemManifest manifest;
      try {
        manifest = ItemManifest.fromJson(jsonDecode(utf8.decode(bytes)));
      } on FormatException catch (e) {
        throw UnreadablePublished(file.path, e.message, _manifestRemedy);
      } on ManifestError catch (e) {
        throw UnreadablePublished(file.path, '$e', _manifestRemedy);
      }
      releases.putIfAbsent(manifest.name, () => {})[manifest.version] = (
        manifest: manifest,
        sha256: Sha256.ofBytes(bytes),
      );
    }
    return releases;
  }

  /// Le résumé vient de la plus haute version ; chaque version garde sa
  /// propre contrainte Flutter et ses dépendances.
  IndexEntry _entry(ItemRef ref, Map<Version, _Release> releases) {
    final versions = releases.keys.toList()..sort();
    final latest = releases[versions.last]!.manifest;
    return IndexEntry(
      ref: ref,
      type: latest.type,
      title: latest.title,
      description: latest.description,
      categories: latest.categories,
      meta: latest.meta,
      versions: [
        for (final version in versions)
          IndexVersion(
            version: version,
            manifestSha256: releases[version]!.sha256,
            flutter: releases[version]!.manifest.flutter,
            registryDependencies:
                releases[version]!.manifest.registryDependencies,
          ),
      ],
    );
  }

  static const _manifestRemedy =
      'restore it from the published registry, or delete it if this version '
      'was never served';

  /// Écrit à côté puis renomme : une coupure ne laisse pas un fichier à
  /// moitié écrit que le build suivant ne saurait relire.
  /// Un blob est rangé sous son empreinte : déjà présent avec ce contenu,
  /// il n'est pas réécrit. Un `out/` reconstruit ne réécrit ainsi que ce qui
  /// change ; un blob abîmé sur le disque, lui, est remplacé.
  void _writeBlob(Sha256 sha256, Uint8List bytes) {
    final path = DistLayout.blobPath(sha256);
    final existing = File(p.join(out, path));
    if (existing.existsSync() &&
        existing.lengthSync() == bytes.length &&
        Sha256.ofBytes(existing.readAsBytesSync()) == sha256) {
      return;
    }
    _write(path, bytes);
  }

  void _write(String path, List<int> bytes) {
    final target = p.join(out, path);
    File('$target.tmp')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes)
      ..renameSync(target);
  }
}

sealed class BuildError implements Exception {
  const BuildError();

  String get message;

  @override
  String toString() => message;
}

final class MissingSourceFile extends BuildError {
  const MissingSourceFile(this.manifest, this.path);

  final String manifest;

  /// Relatif à `lib/` de la source.
  final String path;

  @override
  String get message => '$manifest: lib/$path not found';
}

final class InvalidSourceManifest extends BuildError {
  const InvalidSourceManifest(this.manifest, this.reason);

  final String manifest;
  final String reason;

  @override
  String get message => '$manifest: $reason';
}

/// Une version publiée ne change jamais : corriger, c'est publier une version.
final class PublishedVersionChanged extends BuildError {
  const PublishedVersionChanged(this.path);

  final String path;

  @override
  String get message =>
      '$path: already published with different content. Change the version';
}

/// Un fichier déjà dans `out/` que le build relit et ne comprend pas.
final class UnreadablePublished extends BuildError {
  const UnreadablePublished(this.path, this.reason, this.remedy);

  final String path;
  final String reason;
  final String remedy;

  @override
  String get message =>
      '$path: already published but unreadable ($reason). To fix it, $remedy';
}

/// Un élément gratuit qui exige un élément Pro : sans le Pro dans le
/// registre publié, il ne s'installerait plus.
final class ProDependency extends BuildError {
  const ProDependency(this.item, this.dependency);

  final String item;
  final String dependency;

  @override
  String get message =>
      '$item is free and requires $dependency, a Pro item the published '
      'registry does not serve. Make $item pro or $dependency free';
}

/// `out/` contient déjà le code d'un élément Pro, d'une construction avec
/// `--include-pro` : le registre public le servirait.
final class ProAlreadyInOut extends BuildError {
  const ProAlreadyInOut(this.path);

  /// Le blob de code Pro trouvé.
  final String path;

  @override
  String get message =>
      '$path: the code of a Pro item, in a folder built with --include-pro. '
      'The public registry serves no Pro code. Start from the published '
      'public dist/ or an empty folder. Nothing was written';
}

/// Un retrait ne peut viser qu'une version publiée dans `out/` ou la source.
final class UnknownYank extends BuildError {
  const UnknownYank(this.ref);

  final ItemRef ref;

  @override
  String get message =>
      '--yank $ref: this version is not published. Nothing was written';
}

final class PointerVersionNotIncreasing extends BuildError {
  const PointerVersionNotIncreasing(this.version, this.published);

  final int version;
  final int published;

  @override
  String get message =>
      'pointer version $version: $published is already published. Use a '
      'higher version';
}

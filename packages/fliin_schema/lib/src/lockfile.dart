import 'package:pub_semver/pub_semver.dart';

import 'config.dart';
import 'item_ref.dart';
import 'json_node.dart';
import 'manifest_error.dart';
import 'sha256.dart';

/// Un `.fliin-new` attend sa résolution ; `base` n'avance qu'à ce moment-là,
/// sinon les changements amont deviendraient des modifications locales. Le
/// marqueur porte les empreintes de la version visée, pour que la
/// résolution fasse avancer `raw` et `base` sans relire le registre.
final class ConflictMarker {
  ConflictMarker({
    required this.targetVersion,
    required String sidecarPath,
    required this.raw,
    required this.base,
  }) : sidecarPath = checkRelativePath(sidecarPath);

  factory ConflictMarker.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return ConflictMarker(
      targetVersion: node['targetVersion'].parse(
        Version.parse,
        InvalidVersion.new,
      ),
      sidecarPath: node['sidecarPath'].relativePath,
      raw: node['raw'].parse(Sha256.parse, InvalidSha256.new),
      base: node['base'].parse(Sha256.parse, InvalidSha256.new),
    );
  }

  final Version targetVersion;
  final String sidecarPath;

  /// Le brut de la version visée.
  final Sha256 raw;

  /// Ce brut rendu avec la config : le contenu du `.fliin-new`.
  final Sha256 base;

  Map<String, Object?> toJson() => {
    'targetVersion': '$targetVersion',
    'sidecarPath': sidecarPath,
    'raw': raw.value,
    'base': base.value,
  };
}

/// Les empreintes d'un fichier installé (DESIGN.md §4.3). `base` nul n'existe
/// qu'en attente : les deux constructeurs ne laissent pas d'autre état.
final class LockedFile {
  /// Installé par le CLI.
  const LockedFile({
    required this.raw,
    required Sha256 this.base,
    required Sha256 this.installed,
    this.conflicted,
  });

  /// Installé sans le CLI : `base` et `installed` seront calculés par le
  /// prochain `fliin status`.
  const LockedFile.pending(this.raw)
    : base = null,
      installed = null,
      conflicted = null;

  factory LockedFile.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    final raw = node['raw'].parse(Sha256.parse, InvalidSha256.new);
    if (node['pending'].orElse(false).boolean) {
      for (final field in ['base', 'installed', 'conflicted']) {
        if (!node[field].isAbsent) {
          throw InvalidValue(node[field].path, 'expected null while pending');
        }
      }
      return LockedFile.pending(raw);
    }
    return LockedFile(
      raw: raw,
      base: node['base'].parse(Sha256.parse, InvalidSha256.new),
      installed: node['installed'].parse(Sha256.parse, InvalidSha256.new),
      conflicted: node['conflicted'].readOptional(ConflictMarker.fromJson),
    );
  }

  /// Le fichier publié, avant réécriture ; égal à l'index (règle 1).
  final Sha256 raw;

  /// Le brut réécrit et normalisé avec la config (règle 3).
  final Sha256? base;

  /// Ce qui a été écrit à la dernière installation ou mise à jour.
  final Sha256? installed;
  final ConflictMarker? conflicted;

  bool get pending => base == null;

  Map<String, Object?> toJson() => {
    'raw': raw.value,
    'base': base?.value,
    'installed': installed?.value,
    if (pending) 'pending': true,
    'conflicted': ?conflicted?.toJson(),
  };
}

final class LockedItem {
  const LockedItem({
    required this.version,
    required this.registryDependencies,
    required this.files,
  });

  factory LockedItem.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return LockedItem(
      version: node['version'].parse(Version.parse, InvalidVersion.new),
      registryDependencies: [
        for (final ref in node['registryDependencies'].orElse(const []).items)
          ref.parse(ItemRef.parseVersioned, MalformedReference.new),
      ],
      files: {
        for (final MapEntry(:key, :value) in node['files'].fields.entries)
          JsonNode(key, value.path).relativePath: value.read(
            LockedFile.fromJson,
          ),
      },
    );
  }

  final Version version;

  /// Les dépendances résolues, chacune à sa version installée.
  final List<ItemRef> registryDependencies;

  /// Par chemin relatif au projet : `lib/ui/fliin/components/…`.
  final Map<String, LockedFile> files;

  Map<String, Object?> toJson() => {
    'version': '$version',
    'registryDependencies': [for (final ref in registryDependencies) '$ref'],
    'files': {
      for (final MapEntry(:key, :value) in files.entries) key: value.toJson(),
    },
  };
}

/// `fliin.lock.json`, écrit en dernier par chaque installation (règle 4).
final class Lockfile {
  const Lockfile({
    required this.registries,
    required this.config,
    required this.dartStyle,
    required this.items,
  });

  /// Lève une [InvalidValue] si `configHash` ne correspond pas à la config
  /// enregistrée à côté de lui.
  factory Lockfile.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    node['lockfileVersion'].expectFormat(lockfileVersion);
    final config = node['config'].read(RenderConfig.fromJson);
    final hash = node['config']['configHash'];
    if (hash.parse(Sha256.parse, InvalidSha256.new) != config.configHash) {
      throw InvalidValue(hash.path, 'does not match root, prefix, package');
    }
    return Lockfile(
      registries: {
        for (final MapEntry(:key, :value)
            in node['registries'].orElse(const {}).fields.entries)
          JsonNode(key, value.path).parse(Namespace.parse): value.parse(
            RegistrySource.parseUrl,
          ),
      },
      config: config,
      dartStyle: node['normalizer']['dartStyle'].parse(
        Version.parse,
        InvalidVersion.new,
      ),
      items: {
        for (final MapEntry(:key, :value)
            in node['items'].orElse(const {}).fields.entries)
          JsonNode(
            key,
            value.path,
          ).parse(ItemRef.parseUnversioned, MalformedReference.new): value.read(
            LockedItem.fromJson,
          ),
      },
    );
  }

  static const lockfileVersion = 1;

  final Map<Namespace, Uri> registries;
  final RenderConfig config;

  /// La version de `dart_style` qui a produit chaque `base`.
  final Version dartStyle;

  /// Par référence sans version.
  final Map<ItemRef, LockedItem> items;

  Map<String, Object?> toJson() => {
    'lockfileVersion': lockfileVersion,
    'registries': {
      for (final MapEntry(:key, :value) in registries.entries)
        key.value: '$value',
    },
    'config': {...config.toJson(), 'configHash': config.configHash.value},
    'normalizer': {'dartStyle': '$dartStyle'},
    'items': {
      for (final MapEntry(:key, :value) in items.entries)
        '$key': value.toJson(),
    },
  };
}

enum InstalledState { intact, modified, deleted, orphan, pending, conflicted }

/// L'état d'un fichier du lockfile d'après l'empreinte de sa copie sur le
/// disque, nulle s'il est absent. [InstalledState.orphan] n'en sort jamais :
/// un fichier sans entrée se constate chez l'appelant.
InstalledState classify(LockedFile file, Sha256? onDisk) => switch (onDisk) {
  null => InstalledState.deleted,
  _ when file.pending => InstalledState.pending,
  _ when file.conflicted != null => InstalledState.conflicted,
  _ when onDisk == file.installed => InstalledState.intact,
  _ => InstalledState.modified,
};

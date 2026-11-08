import 'dart:io';
import 'dart:typed_data';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../project/environment_failure.dart';
import '../project/project.dart';
import '../project/pubspec.dart';
import 'analyze.dart';
import 'kept_raws.dart';
import 'lockfile_io.dart';
import 'normalizer.dart';
import 'registry_port.dart';
import 'staging.dart';
import 'status.dart';
import 'targets.dart';

/// Un paquet pub qu'un manifeste exige et que `pubspec.lock` n'a pas.
typedef PubDependency = ({
  String package,
  VersionConstraint constraint,
  ItemRef requiredBy,
});

final class InstalledItem {
  const InstalledItem({
    required this.ref,
    required this.manifest,
    required this.files,
  });

  /// Avec sa version.
  final ItemRef ref;
  final ItemManifest manifest;

  /// Relatifs au projet.
  final List<String> files;
}

sealed class InstallOutcome {
  const InstallOutcome();
}

/// `pubspec.yaml`, `pubspec.lock` et `.dart_tool/package_config.json` tels
/// qu'avant `flutter pub add`, absents compris, remis en place si
/// l'installation échoue ensuite : tout ou rien vaut aussi pour le pubspec
/// (règle 4), et l'analyseur ne doit plus résoudre le paquet retiré.
final class _PubspecBackup {
  _PubspecBackup._(this._files);

  static _PubspecBackup take(Directory dir) => _PubspecBackup._({
    for (final name in const [
      'pubspec.yaml',
      'pubspec.lock',
      '.dart_tool/package_config.json',
    ])
      if (File(p.join(dir.path, name)) case final file)
        file: file.existsSync() ? file.readAsBytesSync() : null,
  });

  final Map<File, Uint8List?> _files;

  void restore() {
    for (final MapEntry(key: file, value: bytes) in _files.entries) {
      if (bytes == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        file.writeAsBytesSync(bytes);
      }
    }
  }
}

final class Installed extends InstallOutcome {
  const Installed(this.items, {this.kept = const []});

  /// Installés, ou, avec `restore`, ceux dont des fichiers supprimés ont été
  /// réécrits : [InstalledItem.files] n'a alors que ceux-là.
  final List<InstalledItem> items;

  /// Avec `restore` : les fichiers modifiés localement, laissés tels quels.
  final List<FileStatus> kept;
}

/// Sortie 4 : rien n'est écrit tant que l'utilisateur n'a pas accepté.
final class NeedsConfirmation extends InstallOutcome {
  const NeedsConfirmation(this.dependencies);

  final List<PubDependency> dependencies;
}

/// Les fichiers rendus ne passent pas `dart analyze` : rien n'est écrit.
final class AnalysisRegressed extends InstallOutcome {
  const AnalysisRegressed(this.errors);

  final List<Diagnostic> errors;
}

/// Des fichiers de l'utilisateur sont là où l'installation écrirait : un
/// fichier que le lockfile ne connaît pas, ou qu'il connaît et qui diffère
/// de sa `base`, ou, sans lockfile, n'importe quel fichier sous `root`. Une
/// cible dont le contenu est exactement celui qu'on écrirait n'est jamais
/// occupée : c'est ce qui permet de relancer une installation interrompue
/// pendant le déplacement. Rien n'est écrit : `add` n'écrase jamais, c'est
/// `fliin update` qui fusionne (règle 5).
final class TargetsInTheWay extends InstallOutcome {
  const TargetsInTheWay(this.files);

  final List<({String path, InstalledState state})> files;
}

typedef _Rendered = ({
  ItemRef item,
  String path,
  Sha256 raw,
  Uint8List bytes,
  String text,
});

/// Résout puis installe, tout ou rien (règle 4) : les blobs sont tous lus,
/// réécrits et normalisés avant la première écriture, qui va dans un dossier
/// de transit analysé avant le déplacement ; le lockfile vient en dernier.
final class Installer {
  Installer({
    required this.project,
    required this.config,
    required this.registry,
    required this.lockfile,
  });

  final Project project;
  final FliinConfig config;
  final Registry registry;
  final Lockfile? lockfile;

  Map<ItemRef, Version> get _installed => {
    for (final MapEntry(:key, :value) in (lockfile?.items ?? const {}).entries)
      key: value.version,
  };

  /// Lève une [EnvironmentFailure] si `fliin.yaml` ne porte plus la config
  /// du lockfile ([requireSameConfig]).
  Future<Resolution> plan(List<ItemDependency> roots) async {
    if (lockfile case final locked?) requireSameConfig(locked, config.render);
    final entries = {
      for (final entry in await fetchEntries(registry)) entry.ref: entry,
    };
    return resolve(
      roots: roots,
      lookup: (ref) => entries[ref],
      flutter: project.flutter,
      installed: _installed,
    );
  }

  /// Avec [restore], un élément déjà installé à la version du plan récupère
  /// ses fichiers supprimés ; ses fichiers modifiés localement restent tels
  /// quels et reviennent dans [Installed.kept] : `add` n'écrase jamais.
  Future<InstallOutcome> apply(
    InstallPlan plan, {
    required bool acceptDeps,
    bool restore = false,
  }) async {
    if (_transit.existsSync()) _transit.deleteSync(recursive: true);
    final installed = _installed;
    final deleted = <ItemRef, Set<String>>{};
    final kept = <FileStatus>[];
    if (restore) {
      for (final item in plan.items) {
        if (installed[item.ref] != item.version) continue;
        for (final MapEntry(key: path, value: file)
            in lockfile!.items[item.ref]!.files.entries) {
          switch (localState(file, onDisk(project.dir, path))) {
            case InstalledState.intact:
              break;
            case InstalledState.deleted:
              (deleted[item.ref] ??= {}).add(path);
            case final state:
              kept.add((path: path, item: item.ref, state: state));
          }
        }
      }
    }
    final pending = [
      for (final item in plan.items)
        if (installed[item.ref] != item.version ||
            deleted.containsKey(item.ref))
          item,
    ];
    if (pending.isEmpty) return Installed(const [], kept: kept);
    final manifests = {
      for (final item in pending)
        item.ref: await registry.fetchManifest(item.ref, item.version),
    };
    requireProAccess(registry, manifests.values);

    final locked = lockedPackages(project.dir);
    final missing = [
      for (final MapEntry(key: ref, value: manifest) in manifests.entries)
        for (final MapEntry(key: package, value: constraint)
            in manifest.dependencies.entries)
          if (!locked.contains(package))
            (package: package, constraint: constraint, requiredBy: ref),
    ];
    if (missing.isNotEmpty && !acceptDeps) return NeedsConfirmation(missing);

    final rendered = <_Rendered>[];
    for (final item in pending) {
      for (final file in manifests[item.ref]!.files) {
        final bytes = await registry.fetchBlob(file.sha256);
        if (Sha256.ofBytes(bytes) case final actual
            when actual != file.sha256) {
          throw IntegrityFailure(file.sha256, actual);
        }
        final path = projectPath(config.render, file.target);
        if (deleted[item.ref] case final only? when !only.contains(path)) {
          continue;
        }
        rendered.add((
          item: item.ref,
          path: path,
          raw: file.sha256,
          bytes: bytes,
          text: renderRaw(bytes, path, config.render),
        ));
      }
    }
    if (_inTheWay([
          for (final item in pending)
            if (!deleted.containsKey(item.ref)) item,
        ], rendered)
        case final files when files.isNotEmpty) {
      return TargetsInTheWay(files);
    }

    final pubspec = missing.isEmpty ? null : _PubspecBackup.take(project.dir);
    try {
      if (missing.isNotEmpty) await _pubAdd(missing);
      if (rendered.isNotEmpty) {
        if (await _stage(rendered) case final errors when errors.isNotEmpty) {
          pubspec?.restore();
          return AnalysisRegressed(errors);
        }
      }
    } catch (_) {
      pubspec?.restore();
      rethrow;
    }
    for (final r in rendered) {
      if (manifests[r.item]!.meta.tier == Tier.pro) {
        keepRaw(project.dir, r.raw, r.bytes);
      }
    }
    writeLockfile(project.dir, _lockfileWith(pending, rendered, deleted));
    return Installed(kept: kept, [
      for (final item in pending)
        InstalledItem(
          ref: item.ref.at(item.version),
          manifest: manifests[item.ref]!,
          files: [
            for (final r in rendered)
              if (r.item == item.ref) r.path,
          ],
        ),
    ]);
  }

  /// Les cibles qu'on ne peut pas écrire sans perdre le travail de
  /// l'utilisateur : une cible qui existe et diffère de sa `base` d'après le
  /// lockfile, tout fichier de la version déjà installée d'un élément qui
  /// diffère de sa `base`, et, sans lockfile, tout fichier sous `root`.
  /// `base` et non `installed` : un fichier que `update` a fusionné est
  /// `intact` et porte pourtant des modifications locales. Un
  /// fichier déjà égal à ce qu'on écrirait au même chemin n'est jamais
  /// occupé : c'est la reprise d'un déplacement interrompu, première
  /// installation ou montée de version.
  List<({String path, InstalledState state})> _inTheWay(
    List<PlannedItem> upgraded,
    List<_Rendered> rendered,
  ) {
    final locked = {
      for (final item in lockfile?.items.values ?? const <LockedItem>[])
        ...item.files,
    };
    final expected = {
      for (final r in rendered) r.path: Sha256.ofString(r.text),
    };
    final states = <String, InstalledState>{};
    void occupied(String path, InstalledState Function(Sha256? found) state) {
      final found = onDisk(project.dir, path);
      if (found != null && found == expected[path]) return;
      if (state(found) case final s when s != InstalledState.intact) {
        states.putIfAbsent(path, () => s);
      }
    }

    for (final r in rendered) {
      occupied(
        r.path,
        (found) => switch ((found, locked[r.path])) {
          (null, _) => InstalledState.intact,
          (_, null) => InstalledState.orphan,
          (_, final file?) => localState(file, found),
        },
      );
    }
    for (final item in upgraded) {
      for (final MapEntry(key: path, value: file)
          in (lockfile?.items[item.ref]?.files ?? const {}).entries) {
        occupied(path, (found) => localState(file, found));
      }
    }
    if (lockfile == null) {
      final root = Directory(p.join(project.dir.path, config.render.root));
      if (root.existsSync()) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is File && !p.isWithin(_transit.path, entity.path)) {
            occupied(
              p.relative(entity.path, from: project.dir.path),
              (_) => InstalledState.orphan,
            );
          }
        }
      }
    }
    return [
      for (final path in states.keys.toList()..sort())
        (path: path, state: states[path]!),
    ];
  }

  /// Écrit [rendered] dans le transit, l'analyse, puis déplace chaque fichier
  /// à sa place. Rend les erreurs d'analyse, auquel cas rien n'a bougé. Pour
  /// l'analyse, les imports entre fichiers du même plan pointent vers le
  /// transit, afin qu'elle voie le même graphe que l'installation ; le texte
  /// vrai est remis avant le déplacement.
  Future<List<Diagnostic>> _stage(List<_Rendered> rendered) async {
    final transit = _transit;
    String inTransit(String path) => transitPath(config.render, path);
    final redirect = redirectImports(config.render, [
      for (final r in rendered) r.path,
    ]);
    if (transit.existsSync()) transit.deleteSync(recursive: true);
    final created = _wouldCreate();
    try {
      for (final r in rendered) {
        File(p.join(project.dir.path, inTransit(r.path)))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(redirect(r.text));
      }
      final errors = [
        for (final d in await analyze(project.sdk, project.dir, [transit.path]))
          if (d.severity == Severity.error) outOfTransit(d),
      ];
      if (errors.isNotEmpty) return errors;
      for (final r in rendered) {
        final target = File(p.join(project.dir.path, r.path))
          ..parent.createSync(recursive: true);
        File(p.join(project.dir.path, inTransit(r.path)))
          ..writeAsStringSync(r.text)
          ..renameSync(target.path);
      }
      return const [];
    } finally {
      if (transit.existsSync()) transit.deleteSync(recursive: true);
      if (created != null &&
          created.existsSync() &&
          created.listSync(recursive: true).whereType<File>().isEmpty) {
        created.deleteSync(recursive: true);
      }
    }
  }

  /// Le plus haut dossier sous `lib/` que la création de `root` ajouterait,
  /// null si `root` existe déjà : après un échec, on ne supprime que ce qu'on
  /// a créé, jamais un dossier vide de l'utilisateur.
  Directory? _wouldCreate() {
    final lib = p.join(project.dir.path, 'lib');
    Directory? top;
    for (
      var current = Directory(p.join(project.dir.path, config.render.root));
      p.isWithin(lib, current.path) && !current.existsSync();
      current = current.parent
    ) {
      top = current;
    }
    return top;
  }

  Directory get _transit =>
      Directory(p.join(project.dir.path, config.render.root, transitDirName));

  Future<void> _pubAdd(List<PubDependency> dependencies) async {
    final result = await Process.run(project.sdk.flutter, [
      'pub',
      'add',
      for (final d in dependencies) '${d.package}:${d.constraint}',
    ], workingDirectory: project.dir.path);
    if (result.exitCode != 0) {
      throw EnvironmentFailure('flutter pub add failed: ${result.stderr}');
    }
  }

  Lockfile _lockfileWith(
    List<PlannedItem> pending,
    List<_Rendered> rendered,
    Map<ItemRef, Set<String>> restored,
  ) {
    final items = {...?lockfile?.items};
    for (final item in pending) {
      items[item.ref] = LockedItem(
        version: item.version,
        registryDependencies: item.dependencies,
        files: {
          if (restored.containsKey(item.ref)) ...items[item.ref]!.files,
          for (final r in rendered)
            if (r.item == item.ref)
              r.path: LockedFile(
                raw: r.raw,
                base: Sha256.ofString(r.text),
                installed: Sha256.ofString(r.text),
              ),
        },
      );
    }
    return Lockfile(
      registries: {
        for (final MapEntry(:key, :value) in config.registries.entries)
          key: value.url,
      },
      config: config.render,
      dartStyle: dartStyleVersion,
      items: items,
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_style/dart_style.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../install/analyze.dart';
import '../install/installer.dart' show PubDependency;
import '../install/kept_raws.dart';
import '../install/lockfile_io.dart';
import '../install/normalizer.dart';
import '../install/registry_port.dart';
import '../install/staging.dart';
import '../install/targets.dart';
import '../project/invalid_project_file.dart';
import '../project/project.dart';
import '../registry/public_api.dart';
import '../project/pubspec.dart';
import '../tokens/project_tokens.dart';
import 'conflicts.dart';
import 'journal.dart';
import 'report.dart';

/// Un élément dont la version change : [from] est nul pour une dépendance
/// que la nouvelle version ajoute.
typedef ItemChange = ({PlannedItem planned, Version? from, IndexEntry entry});

sealed class UpdatePlanning {
  const UpdatePlanning();
}

/// Un élément qui ne monte pas, et pourquoi : sa version admissible est
/// sous l'installée, il attend un conflit, ou il exige la nouvelle version
/// d'un élément retenu.
typedef HeldItem = ({ItemRef ref, Version? from, Version to, String reason});

/// Une version publiée plus haute que [kept], celle que le plan garde, et
/// que seul le Flutter du projet écarte : elle exige [flutter].
typedef NeedsFlutter = ({
  ItemRef ref,
  Version kept,
  Version to,
  VersionConstraint flutter,
});

/// Un fichier des deux côtés d'une comparaison, nul du côté où il n'existe
/// pas.
typedef FileSides = ({String path, String? before, String? after});

final class UpdatePlan extends UpdatePlanning {
  const UpdatePlan(
    this.changes, {
    required this.resumed,
    this.held = const [],
    this.needsFlutter = const [],
  });

  /// Dépendances d'abord.
  final List<ItemChange> changes;

  final List<HeldItem> held;

  final List<NeedsFlutter> needsFlutter;

  /// Vrai quand le plan reprend les versions d'une mise à jour interrompue.
  final bool resumed;
}

final class PlanFailed extends UpdatePlanning {
  const PlanFailed(this.error);

  final ResolutionError error;
}

/// Une mise à jour interrompue attend : `update` sans argument la termine,
/// `update <autre>` est refusé tant qu'elle n'est pas finie.
final class JournalPending extends UpdatePlanning {
  const JournalPending(this.targets);

  final Map<ItemRef, Version> targets;
}

/// `update` ne fait monter que ce qui est installé : `add` installe.
final class NotInstalled extends UpdatePlanning {
  const NotInstalled(this.ref);

  final ItemRef ref;
}

sealed class UpdateOutcome {
  const UpdateOutcome();
}

/// Écrit, lockfile compris ; ou, avec `--dry-run`, ce qui le serait.
final class Updated extends UpdateOutcome {
  const Updated(this.items, {required this.dryRun, this.held = const []});

  final List<ItemUpdate> items;
  final bool dryRun;

  /// Ce qui ne monte pas, et pourquoi.
  final List<HeldItem> held;

  bool get hasConflicts => items.any((i) => i.files.any((f) => f is Conflict));
}

/// Un `.fliin-new` attend encore : rien n'est écrit.
final class UnresolvedConflicts extends UpdateOutcome {
  const UnresolvedConflicts(this.files);

  final List<({String path, String sidecar})> files;
}

/// Les nouvelles versions exigent des paquets pub absents : rien n'est
/// écrit.
final class MissingPubDependencies extends UpdateOutcome {
  const MissingPubDependencies(this.dependencies);

  final List<PubDependency> dependencies;
}

/// La nouvelle version d'un élément ajoute un fichier qu'un autre élément
/// installé possède : rien n'est écrit.
final class PathOwned extends UpdateOutcome {
  const PathOwned(this.path, {required this.owner, required this.claimedBy});

  final String path;
  final ItemRef owner;
  final ItemRef claimedBy;
}

/// L'analyse des fichiers touchés a plus d'erreurs qu'avant : rien n'est
/// déplacé et le lockfile ne bouge pas (DESIGN.md §4.4, point 5).
final class AnalysisRegressed extends UpdateOutcome {
  const AnalysisRegressed(this.items, this.errors);

  final List<ItemUpdate> items;
  final List<Diagnostic> errors;
}

typedef _Upstream = ({Sha256 raw, Uint8List bytes, String text});

/// Ce qu'on fait d'un fichier : le résultat, l'entrée du lockfile (nulle
/// s'il en sort), le texte à écrire à sa place et celui du `.fliin-new`.
typedef _Planned = ({
  FileUpdate update,
  LockedFile? entry,
  String? write,
  String? sidecar,
});

/// La mise à jour par fusion à trois voies (DESIGN.md §4.4). Pour chaque
/// fichier, `B` est le brut de la version installée rendu avec la config,
/// `O` le fichier local, `T` la version visée rendue ; écriture en transit,
/// analyse, journal, déplacement, lockfile en dernier (règle 4).
final class Updater {
  /// Les conflits déjà résolus (`.fliin-new` supprimé) avancent dès ici,
  /// dans [lockfile] ; [resolved] les nomme.
  factory Updater({
    required Project project,
    required FliinConfig config,
    required Registry registry,
    required Lockfile lockfile,
  }) {
    requireSameConfig(lockfile, config.render);
    final settled = settleConflicts(project.dir, lockfile);
    final journal = UpdateJournal.read(project.dir);
    final stale =
        journal != null &&
        journal.targets.entries.every(
          (t) => settled.lockfile.items[t.key]?.version == t.value,
        );
    return Updater._(
      project,
      config.render,
      registry,
      settled.lockfile,
      settled.resolved,
      stale ? null : journal,
      staleJournal: stale,
      preset: config.preset,
    );
  }

  Updater._(
    this.project,
    this.render,
    this.registry,
    this.lockfile,
    this.resolved,
    this.journal, {
    required this.staleJournal,
    this.preset,
  });

  final Project project;
  final RenderConfig render;
  final Registry registry;
  final Lockfile lockfile;
  final List<String> resolved;
  final UpdateJournal? journal;

  /// Le préréglage de `fliin.yaml` : `fliin.tokens.json` se fusionne entre
  /// la base et l'amont tous deux passés par lui, pour que seules les
  /// retouches de l'app restent à fusionner (ADR 0016 §5.1).
  final Preset? preset;

  /// Les notes de [_presetView] qui n'a pas pu réappliquer le préréglage.
  final List<String> presetNotes = [];

  /// [text], un `fliin.tokens.json` livré, tel que [preset] l'aurait écrit
  /// dans le projet ; tel quel sans préréglage, ou s'il ne s'applique pas,
  /// avec une note qui dit quoi relancer.
  String _presetView(String text) {
    final preset = this.preset;
    if (preset == null) return text;
    try {
      final json = jsonDecode(text);
      switch (applyPreset(json, json, preset)) {
        case ThemeSolved(:final patch):
          return tokensJsonText(applyJsonPatch(json, patch));
        case Unsatisfiable():
          presetNotes.add(
            'preset ${preset.encode()} fails the contrast thresholds',
          );
      }
    } on FormatException catch (e) {
      presetNotes.add('$tokensJsonName is unreadable (${e.message})');
    } on TokenError catch (e) {
      presetNotes.add('$e');
    } on PresetError catch (e) {
      presetNotes.add(e.message);
    } on JsonPatchError catch (e) {
      presetNotes.add('$e');
    }
    return text;
  }

  /// Un journal dont toutes les versions sont déjà au lockfile : le
  /// lockfile a été écrit, seule sa suppression a manqué. Il est ignoré.
  final bool staleJournal;

  Directory get _dir => project.dir;

  /// Supprime un journal périmé ; seulement quand la commande écrit.
  void dropStaleJournal() {
    if (staleJournal) UpdateJournal.delete(_dir);
  }

  /// Résout les versions visées : la plus haute publiée (jamais une retirée,
  /// règle 12) qui satisfait les contraintes des éléments installés et
  /// Flutter ; une dépendance monte avec l'élément si sa contrainte l'exige.
  /// [requested] vide vise tout ce qui est installé ; un journal présent
  /// impose ses versions, sauf pour [check] qui ne fait que regarder. Une
  /// version admissible sous l'installée (les plus hautes retirées, ou
  /// réservées à un autre Flutter) n'est jamais choisie : l'élément garde
  /// la sienne et le plan le dit.
  Future<UpdatePlanning> plan(
    List<ItemDependency> requested, {
    bool check = false,
  }) async {
    final entries = {
      for (final entry in await fetchEntries(registry)) entry.ref: entry,
    };
    final installed = {
      for (final MapEntry(:key, :value) in lockfile.items.entries)
        key: value.version,
    };
    for (final dependency in requested) {
      if (!installed.containsKey(dependency.ref)) {
        return NotInstalled(dependency.ref);
      }
    }
    final journal = check ? null : this.journal;
    if (journal != null &&
        requested.any((r) => !journal.targets.containsKey(r.ref))) {
      return JournalPending(journal.targets);
    }
    final targets = journal != null
        ? [
            for (final MapEntry(:key, :value) in journal.targets.entries)
              ItemDependency(key, value),
          ]
        : requested.isNotEmpty
        ? requested
        : [
            for (final ref in _dependentsFirst())
              ItemDependency(ref, VersionConstraint.any),
          ];
    // Une dépendance installée avec un élément visé, et gardée à sa version
    // quand on ne la nomme pas, peut retenir une dépendance commune que la
    // nouvelle version de l'élément exige plus haut (button qui monte core,
    // spinner qui le retient) : elle monte alors d'office avec lui.
    var resolution = _resolve(targets, entries, installed);
    if (resolution is ResolutionError &&
        requested.isNotEmpty &&
        journal == null) {
      final closure = _dependenciesOf({for (final t in targets) t.ref});
      final widened = [
        ...targets,
        for (final ref in closure)
          if (!targets.any((t) => t.ref == ref))
            ItemDependency(ref, VersionConstraint.any),
      ];
      if (widened.length > targets.length) {
        final retry = _resolve(widened, entries, installed);
        if (retry is! ResolutionError) resolution = retry;
      }
    }
    return switch (resolution) {
      final ResolutionError error => PlanFailed(error),
      InstallPlan(:final items) => _held(
        [
          for (final planned in items)
            if (installed[planned.ref] != planned.version)
              (
                planned: planned,
                from: installed[planned.ref],
                entry: entries[planned.ref]!,
              ),
        ],
        {
          for (final planned in items)
            if (installed[planned.ref] case final from?
                when planned.version < from)
              planned.ref:
                  'no eligible version above $from (the highest is '
                  '${planned.version}). The newer ones are yanked or require '
                  'another Flutter, so $from is kept',
        },
        resumed: journal != null,
        needsFlutter: _needsFlutter(targets, items, entries, installed),
      ),
    };
  }

  /// Pour chaque élément de [targets], la plus haute version publiée
  /// au-dessus de celle que le plan garde, que sa contrainte et celles des
  /// éléments installés qui restent admettent, et que seul le Flutter du
  /// projet écarte.
  List<NeedsFlutter> _needsFlutter(
    List<ItemDependency> targets,
    List<PlannedItem> items,
    Map<ItemRef, IndexEntry> entries,
    Map<ItemRef, Version> installed,
  ) {
    final planned = {for (final item in items) item.ref: item.version};
    // Les contraintes des autres éléments, à la version que le plan leur
    // donne : celles d'un dépendant qui ne monte pas retiennent la cible
    // quel que soit Flutter.
    final constraints = [
      for (final ref in {...installed.keys, ...planned.keys})
        if (planned[ref] ?? installed[ref] case final version?)
          for (final d
              in entries[ref]?.versions
                      .where((v) => v.version == version)
                      .firstOrNull
                      ?.registryDependencies ??
                  const <ItemDependency>[])
            (from: ref, dependency: d),
    ];
    bool admitted(ItemRef ref, Version version) => constraints.every(
      (c) =>
          c.from == ref ||
          c.dependency.ref != ref ||
          c.dependency.constraint.allows(version),
    );
    return [
      for (final target in targets)
        if (planned[target.ref] ?? installed[target.ref] case final kept?)
          if (entries[target.ref]?.versions
                  .where(
                    (v) =>
                        v.status is Published &&
                        v.version > kept &&
                        target.constraint.allows(v.version) &&
                        admitted(target.ref, v.version) &&
                        !v.flutter.allows(project.flutter),
                  )
                  .fold<IndexVersion?>(
                    null,
                    (best, v) =>
                        best == null || v.version > best.version ? v : best,
                  )
              case final newer?)
            (
              ref: target.ref,
              kept: kept,
              to: newer.version,
              flutter: newer.flutter,
            ),
    ];
  }

  /// La résolution de [targets], les autres éléments installés gardant leur
  /// version et leurs contraintes.
  Resolution _resolve(
    List<ItemDependency> targets,
    Map<ItemRef, IndexEntry> entries,
    Map<ItemRef, Version> installed,
  ) {
    final updating = {for (final t in targets) t.ref};
    final kept = {
      for (final MapEntry(:key, :value) in installed.entries)
        if (!updating.contains(key)) key: value,
    };
    return resolve(
      roots: [
        ...targets,
        for (final MapEntry(key: ref, value: version) in kept.entries)
          ...?entries[ref]?.versions
              .where((v) => v.version == version)
              .firstOrNull
              ?.registryDependencies,
      ],
      lookup: (ref) => entries[ref],
      flutter: project.flutter,
      installed: kept,
    );
  }

  /// Les dépendances installées de [refs], de proche en proche, selon le
  /// lockfile.
  Set<ItemRef> _dependenciesOf(Set<ItemRef> refs) {
    final found = <ItemRef>{};
    void visit(ItemRef ref) {
      for (final dependency
          in lockfile.items[ref]?.registryDependencies ?? const <ItemRef>[]) {
        final bare = ItemRef(dependency.name, namespace: dependency.namespace);
        if (lockfile.items.containsKey(bare) && found.add(bare)) visit(bare);
      }
    }

    refs.forEach(visit);
    return found;
  }

  /// Retire de [changes] les éléments de [reasons], puis, jusqu'à ce que
  /// rien ne bouge, ceux qui exigent d'un élément retenu une autre version
  /// que l'installée.
  UpdatePlan _held(
    List<ItemChange> changes,
    Map<ItemRef, String> reasons, {
    required bool resumed,
    List<NeedsFlutter> needsFlutter = const [],
  }) {
    final held = {...reasons};
    var moving = changes;
    while (true) {
      final next = [
        for (final change in moving)
          if (!held.containsKey(change.planned.ref)) change,
      ];
      for (final change in next) {
        for (final dependency in change.planned.dependencies) {
          final bare = ItemRef(
            dependency.name,
            namespace: dependency.namespace,
          );
          if (held.containsKey(bare) &&
              dependency.version != lockfile.items[bare]?.version) {
            held[change.planned.ref] =
                'requires $dependency, which is not updated';
          }
        }
      }
      if (next.length == moving.length &&
          next.every((c) => !held.containsKey(c.planned.ref))) {
        return UpdatePlan(
          next,
          resumed: resumed,
          needsFlutter: needsFlutter,
          held: [
            for (final change in changes)
              if (held[change.planned.ref] case final reason?)
                (
                  ref: change.planned.ref,
                  from: change.from,
                  to: change.planned.version,
                  reason: reason,
                ),
          ],
        );
      }
      moving = next;
    }
  }

  /// Les éléments installés, ceux dont personne ne dépend d'abord : la
  /// résolution, sans retour arrière, voit ainsi la contrainte d'un élément
  /// sur sa dépendance avant de choisir la version de celle-ci.
  List<ItemRef> _dependentsFirst() {
    final order = <ItemRef>[];
    void visit(ItemRef ref) {
      if (order.contains(ref)) return;
      for (final dependency
          in lockfile.items[ref]?.registryDependencies ?? const <ItemRef>[]) {
        final bare = ItemRef(dependency.name, namespace: dependency.namespace);
        if (lockfile.items.containsKey(bare)) visit(bare);
      }
      order.add(ref);
    }

    lockfile.items.keys.forEach(visit);
    return order.reversed.toList();
  }

  /// Ce que `--check` montre : les versions visées, leur changelog et leurs
  /// cassures, sans fichier.
  Future<List<ItemUpdate>> available(UpdatePlan plan) async {
    final items = <ItemUpdate>[];
    for (final change in plan.changes) {
      final manifest = await registry.fetchManifest(
        change.planned.ref,
        change.planned.version,
      );
      items.add(
        await _itemUpdate(
          change,
          manifest,
          await _upstream(manifest),
          const [],
        ),
      );
    }
    return items;
  }

  /// B ↔ T de chaque élément de [plan] : son rapport, comme `--check`, et
  /// chaque fichier de la base installée et de la version visée, rendus
  /// comme la fusion les voit ; `tokens.g.dart` généré des deux côtés depuis
  /// leur `fliin.tokens.json`, comme `update` le régénère.
  Future<List<(ItemUpdate, List<FileSides>)>> upstreamSides(
    UpdatePlan plan,
  ) async {
    final sides = <(ItemUpdate, List<FileSides>)>[];
    for (final change in plan.changes) {
      final manifest = await registry.fetchManifest(
        change.planned.ref,
        change.planned.version,
      );
      final upstream = await _upstream(manifest);
      final old =
          lockfile.items[change.planned.ref]?.files ??
          const <String, LockedFile>{};
      final files = [
        for (final path in {...old.keys, ...upstream.keys}.toList()..sort())
          (
            path: path,
            before: old[path] == null ? null : await _base(path, old[path]!),
            after: switch (upstream[path]) {
              null => null,
              final t => _view(path)(t.text),
            },
          ),
      ];
      final json = _sidesOf(files, _tokensJsonPath);
      sides.add((
        await _itemUpdate(change, manifest, upstream, const []),
        [
          for (final file in files)
            if (file.path == _tokensDartPath && json != null)
              (
                path: file.path,
                before: file.before == null
                    ? null
                    : _generate(json.before).$1 ?? file.before,
                after: file.after == null
                    ? null
                    : _generate(json.after).$1 ?? file.after,
              )
            else
              file,
        ],
      ));
    }
    return sides;
  }

  /// B ↔ O de [ref] : la base installée et le fichier local. Un fichier
  /// resté la base ne lit aucun brut, et les autres viennent du projet ou du
  /// cache avant le registre : sans réseau, la comparaison se fait. Pour
  /// `tokens.g.dart`, B est ce que `fliin tokens` génère du
  /// `fliin.tokens.json` local : seule une retouche à la main y reste.
  Future<List<FileSides>> localSides(ItemRef ref) async {
    final sides = <FileSides>[];
    for (final MapEntry(key: path, value: file)
        in lockfile.items[ref]!.files.entries) {
      final local = _read(path);
      final unchanged =
          local != null &&
          _view(path) == _same &&
          Sha256.ofString(local.replaceAll('\r\n', '\n')) == file.base;
      final generated = path == _tokensDartPath
          ? _generate(_read(_tokensJsonPath)).$1
          : null;
      sides.add((
        path: path,
        before: unchanged ? local : generated ?? await _base(path, file),
        after: local,
      ));
    }
    return sides;
  }

  static FileSides? _sidesOf(List<FileSides> files, String path) {
    for (final file in files) {
      if (file.path == path) return file;
    }
    return null;
  }

  /// B : le brut installé de [file], rendu, vu comme la fusion le voit.
  Future<String> _base(String path, LockedFile file) async =>
      _view(path)(renderRaw(await _raw(file.raw), path, render));

  String get _tokensJsonPath => projectPath(
    render,
    ItemTarget(TargetAlias.core, 'tokens/$tokensJsonName'),
  );

  String get _tokensDartPath => projectPath(
    render,
    ItemTarget(TargetAlias.core, 'tokens/$tokensDartName'),
  );

  /// Le préréglage pour `fliin.tokens.json`, rien pour les autres.
  String Function(String text) _view(String path) =>
      path == _tokensJsonPath ? _presetView : _same;

  static String _same(String text) => text;

  Future<UpdateOutcome> apply(
    UpdatePlan plan, {
    required ConflictStrategy strategy,
    required bool dryRun,
  }) async {
    final changing = {for (final change in plan.changes) change.planned.ref};
    final blocked = pendingConflicts(changing);
    if (blocked.isNotEmpty) return UnresolvedConflicts(blocked);

    final manifests = {
      for (final change in plan.changes)
        change.planned.ref: await registry.fetchManifest(
          change.planned.ref,
          change.planned.version,
        ),
    };
    requireProAccess(registry, manifests.values);
    final locked = lockedPackages(_dir);
    final missing = [
      for (final MapEntry(key: ref, value: manifest) in manifests.entries)
        for (final MapEntry(key: package, value: constraint)
            in manifest.dependencies.entries)
          if (!locked.contains(package))
            (package: package, constraint: constraint, requiredBy: ref),
    ];
    if (missing.isNotEmpty) return MissingPubDependencies(missing);

    final planned = <ItemRef, Map<String, _Planned>>{};
    final upstream = <ItemRef, Map<String, _Upstream>>{};
    for (final change in plan.changes) {
      upstream[change.planned.ref] = await _upstream(
        manifests[change.planned.ref]!,
      );
    }
    final owners = {
      for (final MapEntry(key: ref, value: item) in lockfile.items.entries)
        for (final path in item.files.keys) path: ref,
    };
    for (final MapEntry(key: ref, value: files) in upstream.entries) {
      for (final path in files.keys) {
        if (owners[path] case final owner? when owner != ref) {
          return PathOwned(path, owner: owner, claimedBy: ref);
        }
      }
    }
    for (final change in plan.changes) {
      final ref = change.planned.ref;
      planned[ref] = await _item(change, upstream[ref]!, strategy);
    }

    // En sidecar, un élément en conflit ne monte pas du tout : seuls ses
    // .fliin-new sont écrits, et ce qui exige sa nouvelle version attend
    // aussi. Le projet compile donc toujours (DESIGN.md §4.4).
    final conflicted = {
      if (strategy == ConflictStrategy.sidecar)
        for (final MapEntry(key: ref, value: files) in planned.entries)
          if (files.values.any(
            (f) => switch (f.update) {
              Conflict(strategy: ConflictStrategy.sidecar) => true,
              _ => false,
            },
          ))
            ref:
                'in conflict. In each file, copy what you keep from the '
                '.fliin-new file, delete it, then run fliin update again',
    };
    final settled = _held(plan.changes, conflicted, resumed: plan.resumed);
    final moving = {for (final c in settled.changes) c.planned.ref};
    final held = [...plan.held, ...settled.held];
    for (final ref in planned.keys.toList()) {
      if (moving.contains(ref)) continue;
      planned[ref] = conflicted.containsKey(ref)
          ? {
              for (final MapEntry(key: path, value: file)
                  in planned[ref]!.entries)
                if (file.update is Conflict) path: file,
            }
          : {};
    }
    final items = [
      for (final change in plan.changes)
        if (planned[change.planned.ref]!.isNotEmpty)
          await _itemUpdate(
            change,
            manifests[change.planned.ref]!,
            upstream[change.planned.ref]!,
            [
              for (final file in planned[change.planned.ref]!.values)
                file.update,
            ],
          ),
    ];
    if (dryRun) return Updated(items, dryRun: true, held: held);

    final writes = <String, String>{
      for (final files in planned.values)
        for (final MapEntry(key: path, value: file) in files.entries) ...{
          path: ?file.write,
          sidecarOf(path): ?file.sidecar,
        },
    };
    final marked = {
      for (final files in planned.values)
        for (final file in files.values)
          if (file.update case Conflict(
            strategy: ConflictStrategy.markers,
            :final path,
          ))
            path,
    };
    final transit = Directory(p.join(_dir.path, render.root, transitDirName));
    if (transit.existsSync()) transit.deleteSync(recursive: true);
    try {
      final errors = await _stage(transit, writes, marked);
      if (errors.isNotEmpty) return AnalysisRegressed(items, errors);
      UpdateJournal(
        targets: {
          for (final change in settled.changes)
            change.planned.ref: change.planned.version,
        },
        written: {
          for (final ref in moving)
            for (final MapEntry(key: path, value: file)
                in planned[ref]!.entries)
              if ((file.write, file.entry) case (final text?, final entry?))
                path: (
                  sha256: Sha256.ofString(text),
                  update: file.update,
                  entry: entry,
                ),
        },
      ).write(_dir);
      for (final MapEntry(key: path, value: text) in writes.entries) {
        final target = File(p.join(_dir.path, path))
          ..parent.createSync(recursive: true);
        File(p.join(_dir.path, transitPath(render, path)))
          ..writeAsStringSync(text)
          ..renameSync(target.path);
      }
    } finally {
      if (transit.existsSync()) transit.deleteSync(recursive: true);
    }

    for (final change in plan.changes) {
      final ref = change.planned.ref;
      if (manifests[ref]!.meta.tier == Tier.pro) {
        for (final MapEntry(key: path, value: file) in upstream[ref]!.entries) {
          if (moving.contains(ref) || planned[ref]!.containsKey(path)) {
            keepRaw(_dir, file.raw, file.bytes);
          }
        }
      }
    }
    final next = _lockfileWith(settled.changes, planned);
    writeLockfile(_dir, next);
    UpdateJournal.delete(_dir);
    pruneKeptRaws(_dir, next);
    return Updated(items, dryRun: false, held: held);
  }

  /// Les fichiers dont le `.fliin-new` attend encore, pour les éléments
  /// [items] (tous par défaut). Un élément qui en a ne monte pas : la montée
  /// suivante écraserait la version amont que l'utilisateur n'a pas encore
  /// lue.
  List<({String path, String sidecar})> pendingConflicts([
    Set<ItemRef>? items,
  ]) => [
    for (final MapEntry(key: ref, value: item) in lockfile.items.entries)
      if (items == null || items.contains(ref))
        for (final MapEntry(key: path, value: file) in item.files.entries)
          if (file.conflicted case final marker?)
            (path: path, sidecar: marker.sidecarPath),
  ];

  /// Écrit le lockfile tel que les résolutions l'ont laissé, quand il n'y a
  /// rien d'autre à faire.
  void writeSettled() => writeLockfile(_dir, lockfile);

  Future<Map<String, _Upstream>> _upstream(ItemManifest manifest) async {
    requireProAccess(registry, [manifest]);
    final files = <String, _Upstream>{};
    for (final file in manifest.files) {
      final bytes = await registry.fetchBlob(file.sha256);
      if (Sha256.ofBytes(bytes) case final actual when actual != file.sha256) {
        throw IntegrityFailure(file.sha256, actual);
      }
      final path = projectPath(render, file.target);
      files[path] = (
        raw: file.sha256,
        bytes: bytes,
        text: renderRaw(bytes, path, render),
      );
    }
    return files;
  }

  Future<Map<String, _Planned>> _item(
    ItemChange change,
    Map<String, _Upstream> upstream,
    ConflictStrategy strategy,
  ) async {
    final ref = change.planned.ref;
    final target = change.planned.version;
    final old = lockfile.items[ref]?.files ?? const <String, LockedFile>{};
    final generated = projectPath(
      render,
      ItemTarget(TargetAlias.core, 'tokens/$tokensDartName'),
    );
    final json = projectPath(
      render,
      ItemTarget(TargetAlias.core, 'tokens/$tokensJsonName'),
    );
    final planned = <String, _Planned>{};
    for (final MapEntry(key: path, value: t) in upstream.entries) {
      if (path == generated && upstream.containsKey(json)) continue;
      planned[path] =
          _resumed(path, ref, target) ??
          await _file(
            path,
            old[path],
            t,
            strategy,
            ref.at(target),
            view: path == json ? _presetView : null,
          );
    }
    if (upstream[generated] case final t? when upstream.containsKey(json)) {
      planned[generated] =
          _resumed(generated, ref, target) ??
          await _regenerate(
            generated,
            old[generated],
            t,
            planned[json]!,
            json,
            ref.at(target),
          );
    }
    for (final MapEntry(key: path, value: file) in old.entries) {
      if (!upstream.containsKey(path)) {
        final disk = _read(path);
        planned[path] = (
          update: RemovedUpstream(
            path,
            locallyModified:
                disk != null && Sha256.ofString(disk) != file.installed,
          ),
          entry: null,
          write: null,
          sidecar: null,
        );
      }
    }
    return planned;
  }

  /// Le résultat journalisé, si le disque porte déjà le texte que la mise à
  /// jour interrompue y a écrit.
  _Planned? _resumed(String path, ItemRef ref, Version target) {
    final journal = this.journal;
    final file = journal?.written[path];
    if (journal == null || file == null || journal.targets[ref] != target) {
      return null;
    }
    final disk = File(p.join(_dir.path, path));
    if (!disk.existsSync() ||
        Sha256.ofBytes(disk.readAsBytesSync()) != file.sha256) {
      return null;
    }
    return (update: file.update, entry: file.entry, write: null, sidecar: null);
  }

  /// [view] change la base et l'amont avant de les comparer et de les
  /// fusionner (le préréglage pour `fliin.tokens.json`) ; `base` reste
  /// l'empreinte du brut rendu (règle 3).
  Future<_Planned> _file(
    String path,
    LockedFile? old,
    _Upstream t,
    ConflictStrategy strategy,
    ItemRef label, {
    String Function(String text)? view,
  }) async {
    final disk = _read(path);
    final o = disk?.replaceAll('\r\n', '\n');
    final tHash = Sha256.ofString(t.text);
    final tText = view == null ? t.text : view(t.text);
    final adopted = LockedFile(
      raw: t.raw,
      base: tHash,
      installed: Sha256.ofString(tText),
    );
    _Planned sidecar(LockedFile entry) =>
        _sidecar(path, entry, t, tText, label);

    if (old == null) {
      if (disk != null && o != tText) {
        return sidecar(
          LockedFile(raw: t.raw, base: tHash, installed: Sha256.ofString(disk)),
        );
      }
      return (
        update: AddedUpstream(path),
        entry: adopted,
        write: o == null ? tText : null,
        sidecar: null,
      );
    }
    final bRaw = renderRaw(await _raw(old.raw), path, render);
    final bHash = Sha256.ofString(bRaw);
    final b = view == null ? bRaw : view(bRaw);
    final kept = LockedFile(
      raw: old.raw,
      base: bHash,
      installed: old.installed ?? bHash,
    );
    final localOnly = LockedFile(
      raw: t.raw,
      base: tHash,
      installed: old.installed ?? bHash,
    );
    if (o == null) {
      return tText == b
          ? (
              update: LocalOnly(
                path,
                note: 'deleted locally, unchanged upstream: left deleted',
              ),
              entry: localOnly,
              write: null,
              sidecar: null,
            )
          : sidecar(kept);
    }
    if (o == tText || o == b) {
      return (
        update: FastForward(path),
        entry: adopted,
        write: disk == tText ? null : tText,
        sidecar: null,
      );
    }
    if (tText == b) {
      return (
        update: LocalOnly(path),
        entry: localOnly,
        write: null,
        sidecar: null,
      );
    }
    final merge = diff3(
      local: o,
      base: b,
      upstream: tText,
      upstreamLabel: '$label',
    );
    if (merge.clean) {
      final text = merge.text;
      return (
        update: Merged(path),
        entry: LockedFile(
          raw: t.raw,
          base: tHash,
          installed: Sha256.ofString(text),
        ),
        write: text,
        sidecar: null,
      );
    }
    return switch (strategy) {
      ConflictStrategy.sidecar => sidecar(kept),
      ConflictStrategy.markers => (
        update: Conflict(path, ConflictStrategy.markers),
        entry: LockedFile(
          raw: t.raw,
          base: tHash,
          installed: Sha256.ofString(merge.text),
        ),
        write: merge.text,
        sidecar: null,
      ),
    };
  }

  /// `tokens.g.dart` n'est jamais fusionné : il est régénéré depuis le
  /// `fliin.tokens.json` tel que la mise à jour le laisse, avec le préfixe
  /// du projet (ADR 0003 §7). Un JSON en conflit ou invalide le laisse tel
  /// quel, et la note dit de lancer `fliin tokens` une fois réglé.
  Future<_Planned> _regenerate(
    String path,
    LockedFile? old,
    _Upstream t,
    _Planned json,
    String jsonPath,
    ItemRef label,
  ) async {
    final tHash = Sha256.ofString(t.text);
    final (generated, failure) = _generate(json.write ?? _read(jsonPath));
    if (generated == null) {
      return (
        update: LocalOnly(
          path,
          note:
              'not regenerated, $failure. Run fliin tokens once '
              '$tokensJsonName is fixed',
        ),
        entry: LockedFile(
          raw: t.raw,
          base: tHash,
          installed: old?.installed ?? tHash,
        ),
        write: null,
        sidecar: null,
      );
    }
    final o = _read(path)?.replaceAll('\r\n', '\n');
    final entry = LockedFile(
      raw: t.raw,
      base: tHash,
      installed: Sha256.ofString(generated),
    );
    if (o == generated) {
      return (
        update: generated == t.text ? FastForward(path) : LocalOnly(path),
        entry: entry,
        write: null,
        sidecar: null,
      );
    }
    final handEdited =
        o != null &&
        Sha256.ofString(o) != old?.installed &&
        o != _generate(_read(jsonPath)).$1;
    if (handEdited) {
      final b = old == null
          ? t.text
          : renderRaw(await _raw(old.raw), path, render);
      final bHash = Sha256.ofString(b);
      return _sidecar(
        path,
        LockedFile(
          raw: old?.raw ?? t.raw,
          base: bHash,
          installed: old?.installed ?? Sha256.ofString(o),
        ),
        t,
        generated,
        label,
      );
    }
    return (
      update:
          generated == t.text && o != null && Sha256.ofString(o) == old?.base
          ? FastForward(path)
          : Regenerated(path),
      entry: entry,
      write: generated,
      sidecar: null,
    );
  }

  /// `tokens.g.dart` pour le texte de [json], ou la raison de l'échec.
  (String?, String?) _generate(String? json) {
    if (json == null) return (null, '$tokensJsonName not found');
    try {
      return (renderTokensDart(jsonDecode(json), prefix: render.prefix), null);
    } on FormatException catch (e) {
      return (null, '$tokensJsonName is unreadable (${e.message})');
    } on TokenError catch (e) {
      return (null, '$tokensJsonName: $e');
    } on FormatterException catch (e) {
      return (null, 'the generated Dart cannot be formatted (${e.message()})');
    }
  }

  /// Le local reste ; [text] attend dans le `.fliin-new`, et le marqueur
  /// porte les empreintes visées pour la résolution.
  _Planned _sidecar(
    String path,
    LockedFile entry,
    _Upstream t,
    String text,
    ItemRef label,
  ) => (
    update: Conflict(path, ConflictStrategy.sidecar, sidecar: sidecarOf(path)),
    entry: LockedFile(
      raw: entry.raw,
      base: entry.base!,
      installed: entry.installed!,
      conflicted: ConflictMarker(
        targetVersion: label.version!,
        sidecarPath: sidecarOf(path),
        raw: t.raw,
        base: Sha256.ofString(t.text),
      ),
    ),
    write: null,
    sidecar: text,
  );

  /// Le brut de la version installée : gardé dans le projet pour un fichier
  /// Pro (règle 3), sinon le cache de l'utilisateur, sinon le registre, qui
  /// sert encore une version retirée (règle 12).
  Future<Uint8List> _raw(Sha256 sha256) async {
    if (keptRaw(_dir, sha256) case final bytes?) return bytes;
    final bytes = await registry.fetchBlob(sha256);
    if (Sha256.ofBytes(bytes) case final actual when actual != sha256) {
      throw IntegrityFailure(sha256, actual);
    }
    return bytes;
  }

  /// Lève une [InvalidProjectFile] si le fichier n'est pas du texte UTF-8 :
  /// rien n'est encore écrit à ce moment-là.
  String? _read(String path) {
    final file = File(p.join(_dir.path, path));
    if (!file.existsSync()) return null;
    try {
      return utf8.decode(file.readAsBytesSync());
    } on FormatException {
      throw InvalidProjectFile(
        path,
        'not UTF-8 text, so fliin cannot merge it. Nothing was written',
      );
    }
  }

  /// Écrit [writes] dans le transit et l'analyse avec les fichiers qu'ils
  /// remplacent : rend les erreurs que le transit a en plus, par fichier et
  /// par code, hors des fichiers où l'utilisateur a demandé des marqueurs.
  Future<List<Diagnostic>> _stage(
    Directory transit,
    Map<String, String> writes,
    Set<String> marked,
  ) async {
    final dart = [
      for (final path in writes.keys)
        if (path.endsWith('.dart')) path,
    ];
    // Tout `root` passe dans le transit, dans l'état où la mise à jour le
    // laisse : un fichier inchangé qui réexporte un fichier écrit doit
    // pointer vers sa nouvelle version, sinon l'analyse voit l'ancienne.
    final staged = {..._rootSources(), ...writes};
    final redirect = redirectImports(render, [
      for (final path in staged.keys)
        if (path.endsWith('.dart')) path,
    ]);
    for (final MapEntry(key: path, value: text) in staged.entries) {
      File(p.join(_dir.path, transitPath(render, path)))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(path.endsWith('.dart') ? redirect(text) : text);
    }
    final excluded = _importers(marked, writes);
    final checked = dart.where((path) => !excluded.contains(path)).toSet();
    if (checked.isEmpty) return const [];
    final originals = [
      for (final path in checked)
        if (File(p.join(_dir.path, path)).existsSync()) path,
    ];
    final diagnostics = await analyze(project.sdk, _dir, [
      transit.path,
      ...originals,
    ]);
    final before = <String, int>{};
    final after = <Diagnostic>[];
    for (final d in diagnostics) {
      if (d.severity != Severity.error) continue;
      if (d.file.contains('/$transitDirName/')) {
        final moved = outOfTransit(d);
        if (checked.contains(moved.file)) after.add(moved);
      } else {
        before.update('${d.file}\n${d.code}', (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return [
      for (final d in after)
        if (before.update(
              '${d.file}\n${d.code}',
              (n) => n - 1,
              ifAbsent: () => -1,
            ) <
            0)
          d,
    ];
  }

  /// Les éléments de [moving] à leur nouvelle version ; un élément retenu
  /// pour conflit garde la sienne et ses entrées, sauf celles de ses
  /// fichiers en conflit, qui portent leur marqueur.
  /// Les fichiers Dart sous `root`, transit exclu, par chemin relatif.
  Map<String, String> _rootSources() {
    final root = Directory(p.join(_dir.path, render.root));
    if (!root.existsSync()) return {};
    return {
      for (final file in root.listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            !p.isWithin(p.join(root.path, transitDirName), file.path))
          p.relative(file.path, from: _dir.path): file.readAsStringSync(),
    };
  }

  /// [marked] et tout fichier Dart du projet qui les importe ou les exporte,
  /// directement ou non, dans l'état où la mise à jour les laisse : leurs
  /// erreurs viennent des marqueurs que l'utilisateur a demandés.
  Set<String> _importers(Set<String> marked, Map<String, String> writes) {
    if (marked.isEmpty) return marked;
    final texts = <String, String>{};
    final lib = Directory(p.join(_dir.path, 'lib'));
    if (lib.existsSync()) {
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        final path = p.relative(file.path, from: _dir.path);
        if (path.endsWith('.dart') && !path.contains('/$transitDirName/')) {
          texts[path] = file.readAsStringSync();
        }
      }
    }
    for (final MapEntry(key: path, value: text) in writes.entries) {
      if (path.endsWith('.dart')) texts[path] = text;
    }
    final directive = RegExp(
      r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    final package = 'package:${render.package}/';
    final importedBy = <String, Set<String>>{};
    for (final MapEntry(key: path, value: text) in texts.entries) {
      for (final match in directive.allMatches(text)) {
        final uri = match[1]!;
        final target = uri.startsWith(package)
            ? 'lib/${uri.substring(package.length)}'
            : uri.contains(':')
            ? null
            : p.normalize(p.join(p.dirname(path), uri));
        if (target != null) importedBy.putIfAbsent(target, () => {}).add(path);
      }
    }
    final reached = {...marked};
    final queue = [...marked];
    while (queue.isNotEmpty) {
      for (final importer
          in importedBy[queue.removeLast()] ?? const <String>{}) {
        if (reached.add(importer)) queue.add(importer);
      }
    }
    return reached;
  }

  Lockfile _lockfileWith(
    List<ItemChange> moving,
    Map<ItemRef, Map<String, _Planned>> planned,
  ) {
    final items = {...lockfile.items};
    for (final change in moving) {
      items[change.planned.ref] = LockedItem(
        version: change.planned.version,
        registryDependencies: change.planned.dependencies,
        files: {
          for (final MapEntry(key: path, value: file)
              in planned[change.planned.ref]!.entries)
            path: ?file.entry,
        },
      );
    }
    final movingRefs = {for (final c in moving) c.planned.ref};
    for (final MapEntry(key: ref, value: files) in planned.entries) {
      final old = items[ref];
      if (movingRefs.contains(ref) || files.isEmpty || old == null) continue;
      items[ref] = LockedItem(
        version: old.version,
        registryDependencies: old.registryDependencies,
        files: {
          ...old.files,
          for (final MapEntry(key: path, value: file) in files.entries)
            path: ?file.entry,
        },
      );
    }
    return Lockfile(
      registries: lockfile.registries,
      config: lockfile.config,
      dartStyle: dartStyleVersion,
      items: items,
    );
  }

  /// Le changelog de chaque version franchie, de `from` exclue à la version
  /// visée incluse, et les cassures : celles que le diff de l'API entre le
  /// brut installé et le brut visé trouve ici, au préfixe du projet, plus
  /// les `semantic` publiées des versions franchies. Les cassures calculées
  /// publiées ne servent pas : un correctif publié après une version plus
  /// haute fausse leur point de départ.
  Future<ItemUpdate> _itemUpdate(
    ItemChange change,
    ItemManifest target,
    Map<String, _Upstream> upstream,
    List<FileUpdate> files,
  ) async {
    final ref = change.planned.ref;
    final to = change.planned.version;
    final from = change.from;
    final crossed = [
      for (final release in change.entry.versions)
        if (release.version <= to &&
            (from == null ? release.version == to : release.version > from))
          release.version,
    ]..sort();
    final changelog = <VersionNote<String>>[];
    final breaking = <BreakingNote>[];
    if (from != null) {
      final installed = lockfile.items[ref]!.files;
      final before = [
        for (final MapEntry(key: path, value: file) in installed.entries)
          if (path.endsWith('.dart')) utf8.decode(await _raw(file.raw)),
      ];
      final after = [
        for (final MapEntry(key: path, value: file) in upstream.entries)
          if (path.endsWith('.dart')) utf8.decode(file.bytes),
      ];
      for (final found in [
        ...fileBreaks(installed.keys, upstream.keys),
        ...apiBreaks(publicApi(before), publicApi(after)),
      ]) {
        breaking.add((
          version: to,
          value: _prefixed(found),
          origin: BreakingOrigin.computed,
        ));
      }
    }
    for (final version in crossed) {
      final manifest = version == to
          ? target
          : await registry.fetchManifest(ref, version);
      if (manifest.changelog case final text?) {
        changelog.add((version: version, value: text));
      }
      if (from != null) {
        for (final declared in manifest.breaking.whereType<SemanticBreak>()) {
          breaking.add((
            version: version,
            value: declared,
            origin: BreakingOrigin.published,
          ));
        }
      }
    }
    return ItemUpdate(
      ref: ref,
      from: from,
      to: to,
      files: files,
      changelog: changelog,
      breaking: breaking,
    );
  }

  BreakingChange _prefixed(BreakingChange change) => BreakingChange.fromJson({
    for (final MapEntry(:key, :value) in change.toJson().entries)
      key: key != 'kind' && value is String
          ? applyRewrites(value, render)
          : value,
  });
}

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:pub_semver/pub_semver.dart';

enum ConflictStrategy { sidecar, markers }

/// Ce que `fliin update` a fait d'un fichier (ADR 0001 §2, plus
/// [Regenerated], ADR 0010).
sealed class FileUpdate {
  const FileUpdate(this.path);

  factory FileUpdate.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    final path = node['path'].string;
    return switch (node['status'].string) {
      'fastForward' => FastForward(path),
      'localOnly' => LocalOnly(path, note: node['note'].optionalString),
      'merged' => Merged(path),
      'conflict' => Conflict(
        path,
        node['strategy'].oneOf(ConflictStrategy.values),
        sidecar: node['sidecar'].optionalString,
      ),
      'addedUpstream' => AddedUpstream(path),
      'removedUpstream' => RemovedUpstream(
        path,
        locallyModified: node['locallyModified'].orElse(false).boolean,
      ),
      'regenerated' => Regenerated(path),
      final other => throw UnknownValue(node['status'].path, other, const []),
    };
  }

  /// Relatif au projet.
  final String path;

  String get status;

  Map<String, Object?> toJson() => {'path': path, 'status': status};
}

/// Le local était la base : la version amont le remplace.
final class FastForward extends FileUpdate {
  const FastForward(super.path);

  @override
  String get status => 'fastForward';
}

/// L'amont n'a pas changé ce fichier : seul le local compte, rien n'est
/// écrit.
final class LocalOnly extends FileUpdate {
  const LocalOnly(super.path, {this.note});

  final String? note;

  @override
  String get status => 'localOnly';

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'note': ?note};
}

/// Les deux côtés ont changé sans se chevaucher : la fusion est écrite.
final class Merged extends FileUpdate {
  const Merged(super.path);

  @override
  String get status => 'merged';
}

/// Les deux côtés se chevauchent. En [ConflictStrategy.sidecar], le local
/// reste et la version amont attend dans [sidecar] ; en
/// [ConflictStrategy.markers], les marqueurs sont dans le fichier.
final class Conflict extends FileUpdate {
  const Conflict(super.path, this.strategy, {this.sidecar});

  final ConflictStrategy strategy;
  final String? sidecar;

  @override
  String get status => 'conflict';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'strategy': strategy.name,
    'sidecar': ?sidecar,
  };
}

final class AddedUpstream extends FileUpdate {
  const AddedUpstream(super.path);

  @override
  String get status => 'addedUpstream';
}

/// Retiré de la version amont : gardé sur le disque, il sort du lockfile
/// (règle 5) et `status` le dira orphelin.
final class RemovedUpstream extends FileUpdate {
  const RemovedUpstream(super.path, {this.locallyModified = false});

  /// Le disque diffère de ce que fliin a écrit : le fichier porte des
  /// modifications locales, raison de plus de ne pas l'effacer.
  final bool locallyModified;

  @override
  String get status => 'removedUpstream';

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    if (locallyModified) 'locallyModified': true,
  };
}

/// `tokens.g.dart`, régénéré depuis le `fliin.tokens.json` fusionné au lieu
/// d'être fusionné lui-même (ADR 0003 §7).
final class Regenerated extends FileUpdate {
  const Regenerated(super.path);

  @override
  String get status => 'regenerated';
}

typedef VersionNote<T> = ({Version version, T value});

/// D'où vient une cassure du rapport : calculée ici sur les deux bruts, ou
/// déclarée par l'auteur (`semantic`) dans un manifeste publié et signé.
enum BreakingOrigin { computed, published }

typedef BreakingNote = ({
  Version version,
  BreakingChange value,
  BreakingOrigin origin,
});

/// Un élément qui change de version : ses fichiers, puis le changelog et les
/// cassures de chaque version franchie.
final class ItemUpdate {
  const ItemUpdate({
    required this.ref,
    required this.from,
    required this.to,
    required this.files,
    required this.changelog,
    required this.breaking,
  });

  /// Sans version.
  final ItemRef ref;

  /// Null pour une dépendance nouvelle, installée par la montée.
  final Version? from;
  final Version to;
  final List<FileUpdate> files;
  final List<VersionNote<String>> changelog;

  /// Les symboles portent déjà le préfixe du projet.
  final List<BreakingNote> breaking;

  Map<String, Object?> toJson() => {
    'ref': '$ref',
    'from': from == null ? null : '$from',
    'to': '$to',
    'files': [for (final file in files) file.toJson()],
    'changelog': [
      for (final note in changelog)
        {'version': '${note.version}', 'text': note.value},
    ],
    'breaking': [
      for (final note in breaking)
        {
          'version': '${note.version}',
          'origin': note.origin.name,
          ...note.value.toJson(),
        },
    ],
  };
}

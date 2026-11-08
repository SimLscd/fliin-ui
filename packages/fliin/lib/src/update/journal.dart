import 'dart:convert';
import 'dart:io';

import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../project/invalid_project_file.dart';
import 'report.dart';

/// Ce qu'une mise à jour va écrire, posé avant le premier déplacement et
/// retiré après le lockfile. Si elle est interrompue entre les deux, la
/// suivante reprend les mêmes versions, et un fichier dont le disque porte
/// déjà le texte journalisé garde son résultat au lieu d'être fusionné une
/// seconde fois : refusionner un fichier déjà fusionné ou déjà marqué
/// donnerait des conflits sans objet.
final class UpdateJournal {
  const UpdateJournal({required this.targets, required this.written});

  factory UpdateJournal.fromJson(Object? json, [String at = r'$']) {
    final node = JsonNode(json, at);
    return UpdateJournal(
      targets: {
        for (final MapEntry(:key, :value) in node['targets'].fields.entries)
          JsonNode(
            key,
            value.path,
          ).parse(ItemRef.parseUnversioned, MalformedReference.new): value
              .parse(Version.parse, InvalidVersion.new),
      },
      written: {
        for (final MapEntry(:key, :value) in node['written'].fields.entries)
          key: (
            sha256: value['sha256'].parse(Sha256.parse, InvalidSha256.new),
            update: value['update'].read(FileUpdate.fromJson),
            entry: value['entry'].read(LockedFile.fromJson),
          ),
      },
    );
  }

  static const path = '.fliin/update.journal.json';

  /// Chaque élément qui change, à sa version visée.
  final Map<ItemRef, Version> targets;

  /// Par fichier que la mise à jour réécrit : l'empreinte écrite, le
  /// résultat et l'entrée de lockfile qui vont avec.
  final Map<String, JournaledFile> written;

  static UpdateJournal? read(Directory dir) {
    final file = File(p.join(dir.path, path));
    if (!file.existsSync()) return null;
    try {
      return UpdateJournal.fromJson(jsonDecode(file.readAsStringSync()));
    } on FormatException catch (e) {
      throw InvalidProjectFile(file.path, e.message);
    } on ManifestError catch (e) {
      throw InvalidProjectFile(file.path, '$e');
    }
  }

  void write(Directory dir) {
    final target = p.join(dir.path, path);
    File('$target.tmp')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(toJson()))
      ..renameSync(target);
  }

  static void delete(Directory dir) {
    final file = File(p.join(dir.path, path));
    if (file.existsSync()) file.deleteSync();
  }

  Map<String, Object?> toJson() => {
    'targets': {
      for (final MapEntry(:key, :value) in targets.entries) '$key': '$value',
    },
    'written': {
      for (final MapEntry(:key, :value) in written.entries)
        key: {
          'sha256': value.sha256.value,
          'update': value.update.toJson(),
          'entry': value.entry.toJson(),
        },
    },
  };
}

typedef JournaledFile = ({Sha256 sha256, FileUpdate update, LockedFile entry});

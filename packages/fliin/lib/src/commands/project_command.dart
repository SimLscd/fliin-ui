import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:args/command_runner.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../install/registry_port.dart';
import '../install/selected_registry.dart';
import '../project/environment_failure.dart';
import '../project/invalid_project_file.dart';
import '../project/project_lock.dart';
import 'exit_code.dart';

/// Où une commande écrit : stdout et stderr, ou des tampons sous test.
typedef CliIo = ({StringSink out, StringSink err});

/// Une commande qui travaille sur le projet désigné par `-C` (défaut : le
/// dossier courant) et traduit chaque échec typé en code de sortie.
abstract class ProjectCommand extends Command<int> {
  ProjectCommand(this.openRegistry, this.io) {
    argParser.addFlag('json', negatable: false, help: 'Writes JSON to stdout.');
  }

  final OpenRegistry openRegistry;
  final CliIo io;

  Directory get projectDir => Directory(
    p.normalize(p.absolute(globalResults?.option('directory') ?? '.')),
  );

  bool get jsonOutput => argResults!.flag('json');

  /// Le registre `@fliin` de [config], vu avec le jeu d'icônes de son
  /// préréglage : ce qu'une commande qui installe, met à jour ou montre un
  /// élément du projet doit lire.
  Future<Registry> openProjectRegistry(FliinConfig config) async =>
      SelectedRegistry(
        await openRegistry(config.registries[Namespace.fliin]),
        config.preset?.icons.variant,
      );

  /// Vrai pour une commande qui écrit dans le projet : elle tient le
  /// [ProjectLock] pendant toute son exécution.
  bool get writesProject => false;

  Future<int> execute();

  @override
  Future<int> run() async {
    ProjectLock? lock;
    try {
      if (writesProject &&
          File(p.join(projectDir.path, 'pubspec.yaml')).existsSync()) {
        lock = ProjectLock.acquire(projectDir);
      }
      return await execute();
    } on ProjectBusy catch (e) {
      return fail(ExitCode.failure, '$e');
    } on EnvironmentFailure catch (e) {
      return fail(ExitCode.environment, e.message);
    } on RegistryFailure catch (e) {
      return fail(registryExitCode(e), e.message);
    } on ManifestError catch (e) {
      return fail(ExitCode.failure, 'Invalid document: $e');
    } on MissingVariant catch (e) {
      return fail(ExitCode.failure, '$e');
    } on InvalidProjectFile catch (e) {
      return fail(ExitCode.failure, '$e');
    } finally {
      lock?.release();
    }
  }

  int succeed(Map<String, Object?> json, Iterable<String> lines) {
    if (jsonOutput) {
      io.out.writeln(jsonEncode(json));
    } else {
      lines.forEach(io.out.writeln);
    }
    return ExitCode.ok.code;
  }

  /// Un rapport qui est le résultat, sur stdout, même avec un code non nul.
  int emit(ExitCode code, Map<String, Object?> json, List<String> lines) {
    if (jsonOutput) {
      io.out.writeln(jsonEncode(json));
    } else {
      lines.forEach(io.out.writeln);
    }
    return code.code;
  }

  /// [json] s'ajoute à la sortie `--json` ; sa clé `error`, si elle est un
  /// objet, complète `{code, message}`.
  int fail(
    ExitCode code,
    String message, [
    Map<String, Object?> json = const {},
  ]) {
    io.err.writeln(message);
    if (jsonOutput) {
      io.out.writeln(
        jsonEncode({
          ...json,
          'error': {
            'code': code.code,
            'message': message,
            if (json['error'] case final Map<String, Object?> detail) ...detail,
          },
        }),
      );
    }
    return code.code;
  }

  /// `button`, `button@0.1.0` ou `@acme/button@^1.0.0`, sinon erreur d'usage.
  List<ItemDependency> parseRefs(List<String> rest) {
    if (rest.isEmpty) usageException('Expected at least one item.');
    try {
      return [for (final text in rest) ItemDependency.parse(text)];
    } on FormatException catch (e) {
      usageException('${e.message}: ${e.source}');
    }
  }
}

ExitCode registryExitCode(RegistryFailure failure) => switch (failure) {
  IntegrityFailure() ||
  PointerRejectedFailure() ||
  CacheUnreadableFailure() => ExitCode.integrity,
  MissingArtifact() => ExitCode.failure,
  RegistryUnreachable() ||
  CliTooOldFailure() ||
  NoOfficialKey() => ExitCode.environment,
  ProLicenseRequired() || ProLicenseRefused() => ExitCode.license,
};

/// [known] : les éléments parmi lesquels suggérer un nom proche de celui
/// d'un [ItemNotFound].
String describeResolution(
  ResolutionError error, [
  Iterable<ItemRef> known = const [],
]) => switch (error) {
  ItemNotFound(:final ref) =>
    '$ref is not in the registry.${didYouMean(ref, known)}',
  NoVersionMatches(:final ref, :final constraint, :final available) =>
    '$ref: no version matches $constraint'
        ' (published: ${available.isEmpty ? 'none' : available.join(', ')}).',
  DependencyCycle(:final path) => 'Dependency cycle: ${path.join(' → ')}.',
  FlutterTooOld(:final ref, :final required, :final actual) =>
    '$ref requires Flutter $required. The project has $actual.',
};

/// « n’est pas installé », avec l'élément installé le plus proche de [ref]
/// s'il y en a un, sinon la commande qui l'installe.
String describeNotInstalled(ItemRef ref, Iterable<ItemRef> installed) =>
    switch (didYouMean(ref, installed)) {
      '' => '$ref is not installed. Run fliin add $ref.',
      final near => '$ref is not installed.$near',
    };

/// « : vouliez-vous dire button ? » quand un élément de [known], dans le même
/// espace de noms, est à une faute de frappe de [ref] (deux pour un nom de
/// plus de quatre lettres), sinon une chaîne vide.
String didYouMean(ItemRef ref, Iterable<ItemRef> known) {
  final limit = ref.name.length > 4 ? 2 : 1;
  final near =
      [
        for (final candidate in known.toSet())
          if (candidate.namespace == ref.namespace &&
              candidate.name != ref.name)
            if (_distance(ref.name, candidate.name) case final d
                when d <= limit)
              (ref: candidate, distance: d),
      ]..sort(
        (a, b) => a.distance != b.distance
            ? a.distance - b.distance
            : a.ref.name.compareTo(b.ref.name),
      );
  if (near.isEmpty) return '';
  return ' Did you mean ${near.take(3).map((n) => n.ref).join(', ')}?';
}

/// Distance d'édition, une transposition de deux lettres voisines comptant
/// pour une faute (`buttno`).
int _distance(String a, String b) {
  final d = [
    for (var i = 0; i <= a.length; i++)
      [for (var j = 0; j <= b.length; j++) i == 0 ? j : (j == 0 ? i : 0)],
  ];
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      d[i][j] = min(
        min(d[i - 1][j], d[i][j - 1]) + 1,
        d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[a.length][b.length];
}

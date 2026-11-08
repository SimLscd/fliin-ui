import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'environment_failure.dart';
import 'flutter_sdk.dart';
import 'pubspec.dart';

/// En deçà, `init` refuse (DESIGN.md §3).
final minimumFlutter = Version(3, 47, 0);

/// Ce que dit une commande dont le Flutter ne convient pas : lequel est en
/// cause, et comment en désigner un autre.
String flutterRemedy(FlutterSdk sdk) => sdk.pinned
    ? 'FLIIN_FLUTTER_ROOT points to ${sdk.root.path}. Point it to a '
          'compatible Flutter, or unset it to use the one on the PATH.'
    : 'Put a compatible Flutter first on the PATH, or point '
          'FLIIN_FLUTTER_ROOT to it (current Flutter: ${sdk.root.path}).';

/// Lève une [EnvironmentFailure] quand le Flutter de [project] est sous
/// [minimumFlutter] ou hors de la contrainte `flutter` d'un élément de
/// [required] (une référence versionnée par contrainte) : avant `pub get`,
/// dont l'erreur ne dirait pas quel Flutter est en cause.
void requireFlutter(
  Project project, [
  Map<String, VersionConstraint> required = const {},
]) {
  if (project.flutter < minimumFlutter) {
    throw EnvironmentFailure(
      'Flutter ${project.flutter}: fliin requires $minimumFlutter or later. '
      '${flutterRemedy(project.sdk)}',
    );
  }
  for (final MapEntry(key: item, value: constraint) in required.entries) {
    if (!constraint.allows(project.flutter)) {
      throw EnvironmentFailure(
        'Flutter ${project.flutter}: $item requires Flutter $constraint. '
        '${flutterRemedy(project.sdk)}',
      );
    }
  }
}

/// Les clés de `snippets.route` d'un manifeste.
enum Router {
  goRouter('go_router'),
  autoRoute('auto_route'),
  navigator('navigator');

  const Router(this.wire);

  final String wire;
}

/// Les clés de `snippets.state` d'un manifeste.
enum StateManagement { provider, riverpod, bloc, none }

enum GitTree { clean, dirty, absent }

/// L'app de l'utilisateur, détectée une fois à l'entrée de chaque commande.
final class Project {
  const Project({
    required this.dir,
    required this.sdk,
    required this.package,
    required this.flutter,
    required this.hasLib,
    required this.router,
    required this.state,
    required this.l10n,
    required this.git,
  });

  final Directory dir;
  final FlutterSdk sdk;
  final String package;
  final Version flutter;
  final bool hasLib;
  final Router router;
  final StateManagement state;
  final bool l10n;
  final GitTree git;

  Map<String, Object?> toJson() => {
    'package': package,
    'flutter': '$flutter',
    'router': router.wire,
    'state': state.name,
    'l10n': l10n,
    'git': git.name,
  };
}

/// Le premier paquet présent dans `dependencies` décide.
const _routers = {'go_router': Router.goRouter, 'auto_route': Router.autoRoute};

const _states = {
  'provider': StateManagement.provider,
  'flutter_riverpod': StateManagement.riverpod,
  'hooks_riverpod': StateManagement.riverpod,
  'riverpod': StateManagement.riverpod,
  'flutter_bloc': StateManagement.bloc,
  'bloc': StateManagement.bloc,
};

Future<Project> probe(Directory dir, {Map<String, String>? environment}) async {
  final pubspec = readPubspec(dir);
  final sdk = await FlutterSdk.locate(environment ?? Platform.environment);
  return Project(
    dir: dir,
    sdk: sdk,
    package: pubspec.name,
    flutter: await sdk.version(),
    hasLib: Directory(p.join(dir.path, 'lib')).existsSync(),
    router: _detect(pubspec.dependencies, _routers) ?? Router.navigator,
    state: _detect(pubspec.dependencies, _states) ?? StateManagement.none,
    l10n: pubspec.dependencies.contains('flutter_localizations'),
    git: await _gitTree(dir),
  );
}

T? _detect<T>(Set<String> dependencies, Map<String, T> table) =>
    table.entries.where((e) => dependencies.contains(e.key)).firstOrNull?.value;

Future<GitTree> _gitTree(Directory dir) async {
  final result = await Process.run('git', [
    'status',
    '--porcelain',
  ], workingDirectory: dir.path);
  if (result.exitCode != 0) return GitTree.absent;
  return (result.stdout as String).trim().isEmpty
      ? GitTree.clean
      : GitTree.dirty;
}

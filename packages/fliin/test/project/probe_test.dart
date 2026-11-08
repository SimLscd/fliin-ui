@Tags(['slow'])
library;

import 'dart:io';

import 'package:fliin/src/project/project.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

void main() {
  late Directory dir;

  setUpAll(() async => dir = await createFlutterProject('probe_app'));
  tearDownAll(deleteCreatedProjects);

  test('devrait détecter le paquet, Flutter 3.47.7, lib/ et l’absence de git quand le projet vient de flutter create', () async {
    final project = await probe(dir);
    expect(project.package, 'probe_app');
    expect(project.flutter, Version(3, 47, 7));
    expect(project.hasLib, isTrue);
    expect(project.router, Router.navigator);
    expect(project.state, StateManagement.none);
    expect(project.l10n, isFalse);
    expect(project.git, GitTree.absent);
  });

  test('devrait détecter go_router, riverpod et la l10n quand le pubspec les déclare', () async {
    final pubspec = File('${dir.path}/pubspec.yaml');
    pubspec.writeAsStringSync(
      pubspec.readAsStringSync().replaceFirst(
        'dependencies:\n',
        'dependencies:\n  go_router: ^14.0.0\n  hooks_riverpod: ^2.0.0\n  flutter_localizations:\n    sdk: flutter\n',
      ),
    );
    final project = await probe(dir);
    expect(project.router, Router.goRouter);
    expect(project.state, StateManagement.riverpod);
    expect(project.l10n, isTrue);
  });

  test('devrait dire dirty quand git a des fichiers non commités, puis clean après le commit', () async {
    await git(dir, ['init', '-q']);
    expect((await probe(dir)).git, GitTree.dirty);
    await git(dir, ['add', '-A']);
    await git(dir, ['commit', '-q', '-m', 'initial']);
    expect((await probe(dir)).git, GitTree.clean);
  });
}

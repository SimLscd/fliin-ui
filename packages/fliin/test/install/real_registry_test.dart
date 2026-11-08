@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/project/flutter_sdk.dart';
import 'package:fliin/src/project/project_lock.dart';
import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../registry/support.dart';
import '../support/temp_project.dart';

/// Le vrai CLI contre un vrai `dist/` en `file://`, signé par la clé de test :
/// ce que le faux registre des autres tests ne prouve pas.
late String _source;
late String _dist;
late String _publicKey;

Future<void> _build() async => DistWriter(_dist).write(
  SourceRegistry.read(_source),
  stamp: BuildStamp.following(_dist),
  key: await testKey(),
);

Future<ProcessResult> _init(Directory app, {String? dist}) => fliin([
  '-C',
  app.path,
  'init',
  '--registry',
  '${Directory(dist ?? _dist).uri}',
  '--trusted-key',
  _publicKey,
]);

String _copy(String dist) {
  final copy = tempDir().path;
  for (final MapEntry(key: path, value: bytes) in tree(dist).entries) {
    File(p.join(copy, path))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
  return copy;
}

void main() {
  setUpAll(() async {
    _source = copiedSource();
    _dist = tempDir().path;
    _publicKey = (await testKey()).publicKey;
    await _build();
  });
  tearDownAll(deleteCreatedProjects);

  test('devrait sortir 5 sans rien écrire quand un blob du registre est altéré (synthèse #13, règle 1)', () async {
    final forged = _copy(_dist);
    final scope = SourceRegistry.read(_source).manifests
        .singleWhere((m) => m.name == 'core')
        .files
        .singleWhere((f) => f.path.endsWith('fl_scope.dart'))
        .sha256;
    File(
      p.join(forged, DistLayout.blobPath(scope)),
    ).writeAsStringSync('// altéré\n', mode: FileMode.append);
    final app = await createFlutterProject('forged_app');
    final run = await _init(app, dist: forged);
    expect(run.exitCode, 5, reason: '${run.stderr}');
    expect('${run.stderr}', contains('Integrity check failed'));
    for (final path in ['lib/ui', 'fliin.lock.json', 'fliin.yaml']) {
      expect(
        FileSystemEntity.typeSync(p.join(app.path, path)),
        FileSystemEntityType.notFound,
        reason: path,
      );
    }
  });

  test('devrait sortir 3 quand le pointeur exige un CLI plus récent (synthèse #9)', () async {
    final demanding = _copy(_dist);
    final latest = File(p.join(demanding, DistLayout.pointerPath));
    final signed = SignedPointer.fromJson(jsonDecode(latest.readAsStringSync()));
    final old = IndexPointer.fromJson(jsonDecode(signed.payload));
    final resigned = await (await testKey()).sign(
      IndexPointer(
        version: old.version,
        publishedAt: old.publishedAt,
        expires: old.expires,
        minCli: Version(99, 0, 0),
        fragments: old.fragments,
        yanked: old.yanked,
      ),
    );
    latest.writeAsStringSync(canonicalJson(resigned.toJson()));
    final app = await createFlutterProject('old_cli_app');
    final run = await _init(app, dist: demanding);
    expect(run.exitCode, 3, reason: '${run.stderr}');
    expect('${run.stderr}', contains('requires fliin 99.0.0'));
    expect(File(p.join(app.path, 'fliin.yaml')).existsSync(), isFalse);
  });

  test('devrait garder la version installée de button résolvable et vérifiable quand le registre publie la mineure suivante (synthèse #2)', () async {
    final app = await createFlutterProject('kept_version_app');
    expect((await _init(app)).exitCode, 0);
    final added = await fliin(['-C', app.path, 'add', 'button']);
    expect(added.exitCode, 0, reason: '${added.stderr}');

    bumpSource(_source, 'button', nextMinor(sourceVersion('button')), 'components/button/fl_button.dart');
    await _build();
    final verify = await fliin([
      '-C',
      app.path,
      'verify',
      'button',
      '--variants',
      'ios.light.1.0.ltr',
    ]);
    expect(verify.exitCode, 0, reason: '${verify.stderr}');
    final add = await fliin(['-C', app.path, 'add', 'button', '--json']);
    expect(add.exitCode, 0, reason: '${add.stderr}');
    final json = jsonDecode('${add.stdout}') as Map<String, Object?>;
    expect(json['installed'], isEmpty);
    expect(json['alreadyInstalled'], contains('button@${sourceVersion('button')}'));
  });

  test('devrait installer un écran Pro et sa fermeture sous screens/, afficher les extraits du routeur et de l’état détectés, imports réécrits pour l’app, et ces extraits compilent tels quels (ADR 0015 §1, §35)', skip: withoutPro, () async {
    final app = await createFlutterProject('screen_app');
    final sdk = await FlutterSdk.locate(Platform.environment);
    final pub = await Process.run(sdk.flutter, [
      'pub', 'add', 'go_router', 'provider', '--offline',
    ], workingDirectory: app.path);
    expect(pub.exitCode, 0, reason: '${pub.stderr}');
    expect((await _init(app)).exitCode, 0);

    final added = await fliin(['-C', app.path, 'add', 'account-settings']);
    expect(added.exitCode, 0, reason: '${added.stderr}');
    final manifest = SourceRegistry.read(_source).manifests.singleWhere((m) => m.name == 'account-settings');
    final render = RenderConfig(root: 'lib/ui/fliin', prefix: 'Fl', package: 'screen_app');
    final route = applyRewrites(manifest.snippets.route['go_router']!, render);
    final state = applyRewrites(manifest.snippets.state['provider']!, render);
    final out = '${added.stdout}';
    expect(out, contains('  Route (go_router):\n${_indented(route)}'));
    expect(out, contains('  State (provider):\n${_indented(state)}'));
    expect(route, contains("import 'account_settings_page.dart';"));
    expect(state, contains("import 'package:screen_app/ui/fliin/screens/account_settings/account_settings_screen.dart';"));

    for (final file in manifest.files) {
      expect(File(p.join(app.path, 'lib/ui/fliin', file.path)).existsSync(), isTrue, reason: file.path);
    }
    final lock = jsonDecode(File(p.join(app.path, 'fliin.lock.json')).readAsStringSync()) as Map<String, Object?>;
    final installed = (lock['items']! as Map<String, Object?>).keys.toSet();
    for (final dependency in manifest.registryDependencies) {
      expect(installed, contains(dependency.ref.name));
    }

    File(p.join(app.path, 'lib', 'account_settings_page.dart')).writeAsStringSync(state);
    File(p.join(app.path, 'lib', 'account_settings_route.dart')).writeAsStringSync(route);
    File(p.join(app.path, 'lib', 'router.dart')).writeAsStringSync('''
import 'package:go_router/go_router.dart';

import 'account_settings_route.dart';

final router = GoRouter(routes: [accountSettingsRoute]);
''');
    final analyze = await Process.run(sdk.flutter, [
      'analyze', '--no-pub', '--fatal-infos', 'lib/account_settings_page.dart', 'lib/account_settings_route.dart', 'lib/router.dart',
    ], workingDirectory: app.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}');
  });

  test('devrait jouer les extraits navigator et bloc collés tels quels : le Cubit émet au passage à la semaine suivante, l’accueil vide la pile, la présentation ouvre la connexion (ADR 0015 §35)', skip: withoutPro, () async {
    final app = await createFlutterProject('run_app');
    final sdk = await FlutterSdk.locate(Platform.environment);
    final pub = await Process.run(sdk.flutter, [
      'pub', 'add', 'flutter_bloc', '--offline',
    ], workingDirectory: app.path);
    expect(pub.exitCode, 0, reason: '${pub.stderr}');
    expect((await _init(app)).exitCode, 0);
    final added = await fliin(['-C', app.path, 'add', 'agenda', 'onboarding', 'sign-in', 'sign-up', 'forgot-password', 'verify-code']);
    expect(added.exitCode, 0, reason: '${added.stderr}');
    final render = RenderConfig(root: 'lib/ui/fliin', prefix: 'Fl', package: 'run_app');
    for (final manifest in SourceRegistry.read(_source).manifests) {
      if (!['agenda', 'onboarding', 'sign-in', 'sign-up', 'forgot-password', 'verify-code'].contains(manifest.name)) continue;
      final file = manifest.name.replaceAll('-', '_');
      File(p.join(app.path, 'lib', '${file}_page.dart')).writeAsStringSync(applyRewrites(manifest.snippets.state['bloc']!, render));
      File(p.join(app.path, 'lib', '${file}_route.dart')).writeAsStringSync(applyRewrites(manifest.snippets.route['navigator']!, render));
    }
    File(p.join(app.path, 'test', 'run_test.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:run_app/agenda_page.dart';
import 'package:run_app/agenda_route.dart';
import 'package:run_app/onboarding_route.dart';
import 'package:run_app/ui/fliin/core/fliin.dart';
import 'package:run_app/ui/fliin/screens/agenda/agenda_controller.dart';
import 'package:run_app/ui/fliin/screens/agenda/agenda_screen.dart';
import 'package:run_app/ui/fliin/screens/sign_in/sign_in_screen.dart';

final probe = ValueNotifier<AgendaCubit?>(null);

Widget _app(Route<void> Function() open) => WidgetsApp(
  color: const Color(0xFF000000),
  locale: const Locale('en'),
  supportedLocales: const [Locale('en')],
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
  builder: (context, child) => FlScope(
    brightness: Brightness.light,
    platform: TargetPlatform.iOS,
    child: Column(children: [
      Expanded(child: child!),
      ValueListenableBuilder<AgendaCubit?>(
        valueListenable: probe,
        builder: (context, cubit, _) => cubit == null
            ? const SizedBox()
            : BlocBuilder<AgendaCubit, ({AgendaState state, int version})>(
                bloc: cubit,
                builder: (context, _) => Text('day ${cubit.controller.day.toIso8601String()}'),
              ),
      ),
    ]),
  ),
  home: Builder(builder: (context) => GestureDetector(onTap: () => Navigator.of(context).push(open()), child: const Text('open'))),
);

void main() {
  testWidgets('BlocBuilder voit le passage à la semaine suivante', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(() => agendaRoute(eventPage: (_) => const SizedBox())));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final cubit = probe.value = BlocProvider.of<AgendaCubit>(tester.element(find.byType(AgendaScreen)));
    await tester.pump();
    final day = cubit.controller.day;
    expect(find.text('day ${day.toIso8601String()}'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('day ${DateTime(day.year, day.month, day.day + 7).toIso8601String()}'), findsOneWidget);
    probe.value = null;
    handle.dispose();
  });

  testWidgets('la présentation passée mène à l’accueil seul dans la pile', (tester) async {
    await tester.pumpWidget(_app(() => onboardingRoute(homePage: (_) => const Text('home'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(Navigator.of(tester.element(find.text('home'))).canPop(), isFalse);
  });

  testWidgets('la présentation ouvre la connexion par signInRoute', (tester) async {
    await tester.pumpWidget(_app(() => onboardingRoute(homePage: (_) => const Text('home'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
''');
    final run = await Process.run(sdk.flutter, ['test', '--no-pub', 'test/run_test.dart'], workingDirectory: app.path);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
  });

  test('devrait sortir 1 sans rien écrire quand un autre processus tient le verrou du projet, puis repartir une fois libéré (tour 3, R5)', () async {
    final app = await createFlutterProject('locked_app');
    expect((await _init(app)).exitCode, 0);
    final other = await createFlutterProject('locked_init_app');
    final held = [
      for (final dir in [app, other])
        File(p.join(dir.path, ProjectLock.path))
          ..parent.createSync(recursive: true),
    ].map((f) => f.openSync(mode: FileMode.append)..lockSync()).toList();
    try {
      final add = await fliin(['-C', app.path, 'add', 'button', '--json']);
      expect(add.exitCode, 1, reason: '${add.stderr}');
      expect('${add.stderr}', contains('lock ${p.join(app.path, ProjectLock.path)}'));
      expect('${add.stderr}', isNot(contains('Unhandled')));
      expect(
        (jsonDecode('${add.stdout}') as Map<String, Object?>)['error'],
        isA<Map<String, Object?>>(),
      );
      expect(
        File(p.join(app.path, 'lib/ui/fliin/components/button/fl_button.dart')).existsSync(),
        isFalse,
      );
      final verify = await fliin(['-C', app.path, 'verify', 'core']);
      expect(verify.exitCode, 1, reason: '${verify.stderr}');
      expect('${verify.stderr}', contains('Another fliin is already working'));
      final init = await _init(other);
      expect(init.exitCode, 1, reason: '${init.stderr}');
      expect('${init.stderr}', contains('Another fliin is already working'));
      expect(File(p.join(other.path, 'fliin.yaml')).existsSync(), isFalse);
    } finally {
      for (final handle in held) {
        handle
          ..unlockSync()
          ..closeSync();
      }
    }
    final add = await fliin(['-C', app.path, 'add', 'button']);
    expect(add.exitCode, 0, reason: '${add.stderr}');
    expect((await _init(other)).exitCode, 0);
  });
}

/// [snippet] tel que `fliin add` l'affiche : chaque ligne retirée de quatre.
String _indented(String snippet) => [
  for (final line in snippet.split('\n')) line.isEmpty ? '' : '    $line',
].join('\n');

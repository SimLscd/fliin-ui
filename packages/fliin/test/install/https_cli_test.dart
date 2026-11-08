@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/registry/build.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../registry/support.dart';
import '../support/https_registry.dart';
import '../support/temp_project.dart';

/// Le vrai CLI contre un `dist/` servi en HTTPS local. Le certificat de test
/// n'est approuvé que par `test/support/fliin_https.dart`, qui injecte un
/// `SecurityContext` : le CLI livré n'a aucune option pour l'accepter.
late TestTls _tls;
late String _source;
late String _dist;
late String _publicKey;
late HttpsRegistryServer _server;
late String _cli;

Future<void> _build({DateTime? now}) async => DistWriter(_dist).write(
  SourceRegistry.read(_source),
  stamp: BuildStamp.following(_dist, now: now),
  key: await testKey(),
);

Future<ProcessResult> _fliin(
  List<String> args, {
  required String home,
  Map<String, String> environment = const {},
}) => Process.run(
  Platform.resolvedExecutable,
  [_cli, ...args],
  environment: {
    'HOME': home,
    'FLIIN_TEST_CA': _tls.caPem,
    for (final name in [
      'HTTPS_PROXY',
      'https_proxy',
      'HTTP_PROXY',
      'http_proxy',
      'FLIIN_LICENSE_KEY',
      'XDG_CONFIG_HOME',
    ])
      name: '',
    ...environment,
  },
);

Map<String, Object?> _json(ProcessResult run) =>
    jsonDecode('${run.stdout}') as Map<String, Object?>;

void main() {
  setUpAll(() async {
    _tls = await TestTls.create(tempDir().path);
    _source = copiedSource();
    _dist = tempDir().path;
    _publicKey = (await testKey()).publicKey;
    await _build();
    _server = await HttpsRegistryServer.start(_dist, tls: _tls);
    final dill = p.join(tempDir().path, 'fliin_https.dill');
    final compile = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      p.absolute('test/support/fliin_https.dart'),
      '-o',
      dill,
    ]);
    if (compile.exitCode != 0) throw StateError('${compile.stderr}');
    _cli = dill;
  });
  tearDownAll(() async {
    await _server.close();
    deleteCreatedProjects();
  });

  test('devrait faire init, search, add, verify contre sa référence, theme, puis update, en https, sans rien envoyer du projet', () async {
    final home = tempDir().path;
    final app = await createFlutterProject('https_app');
    Future<ProcessResult> run(List<String> args) =>
        _fliin(['-C', app.path, ...args], home: home);

    final init = await run([
      'init',
      '--registry',
      '${_server.uri}',
      '--trusted-key',
      _publicKey,
    ]);
    expect(init.exitCode, 0, reason: '${init.stderr}');

    final search = await _fliin([
      'search',
      "bouton d'action principal",
      '--registry',
      '${_server.uri}',
      '--key',
      _publicKey,
      '--json',
    ], home: home);
    expect(search.exitCode, 0, reason: '${search.stderr}');
    expect(
      ((_json(search)['results']! as List<Object?>).first! as Map)['id'],
      'button',
    );

    final add = await run(['add', 'button', '--json']);
    expect(add.exitCode, 0, reason: '${add.stderr}');

    final foreign = File(
      p.join(app.path, 'build/fliin/verify/button/golden/a-moi.txt'),
    )..createSync(recursive: true);
    final taken = await run(['verify', 'button']);
    expect(taken.exitCode, 1, reason: '${taken.stderr}');
    expect('${taken.stderr}', contains('fliin verify did not create it'));
    expect(foreign.existsSync(), isTrue);
    foreign.parent.deleteSync(recursive: true);

    final verify = await run(['verify', 'button', '--json']);
    expect(verify.exitCode, 0, reason: '${verify.stderr}');
    final report = _json(verify);
    final variants = (report['variants']! as List<Object?>)
        .cast<Map<String, Object?>>();
    if (Platform.isMacOS) {
      expect(report['reference'], containsPair('status', 'compared'));
      expect(
        {for (final v in variants) v['id']: (v['golden']! as Map)['diffPct']},
        {for (final id in variantIds) id: 0.0},
        reason:
            'verify.entry aux jetons de core rend la référence au pixel près',
      );
      expect(
        File(
          p.join(
            app.path,
            'build/fliin/verify/button/golden/ios.light.1.0.ltr.png',
          ),
        ).existsSync(),
        isTrue,
      );
    } else {
      expect(report['reference'], containsPair('gap', 'otherHost'));
    }

    final theme = await run([
      'theme',
      '--primary',
      '#0A6CFF',
      '--button',
      'pill',
    ]);
    expect(theme.exitCode, 0, reason: '${theme.stderr}');
    final themed = await run([
      'verify',
      'button',
      '--variants',
      'ios.light.1.0.ltr',
    ]);
    expect(themed.exitCode, 0, reason: '${themed.stderr}');
    expect(
      '${themed.stdout}',
      contains('reference not compared: fliin.tokens.json differs'),
    );
    final strict = await run([
      'verify',
      'button',
      '--variants',
      'ios.light.1.0.ltr',
      '--strict',
    ]);
    expect(strict.exitCode, 1);
    expect(
      '${strict.stderr}',
      contains('--strict requires a comparable reference'),
    );

    bumpSource(_source, 'button', nextMinor(sourceVersion('button')), 'components/button/fl_button.dart');
    await _build(now: DateTime.now().add(const Duration(minutes: 1)));
    final check = await run(['update', '--check']);
    expect(check.exitCode, 6, reason: '${check.stderr}');
    final update = await run(['update', '--json']);
    expect(update.exitCode, 0, reason: '${update.stderr}');
    expect(
      (_json(update)['items']! as List<Object?>).map((i) => (i! as Map)['to']),
      [nextMinor(sourceVersion('button'))],
    );

    final layout = RegExp(
      r'^(latest\.json|index/[0-9a-f]{64}\.json|items/fliin/[a-z0-9-]+/[0-9.]+\.json|blobs/[0-9a-f]{2}/[0-9a-f]{64})$',
    );
    final appName = p.basename(p.dirname(app.path));
    for (final request in _server.requests) {
      expect(request.path, matches(layout), reason: 'règle 6');
      expect(
        request.headers.keys.toSet(),
        everyElement(
          isIn(['user-agent', 'accept-encoding', 'host', 'content-length']),
        ),
        reason: 'aucun identifiant ni jeton : ${jsonEncode(request.headers)}',
      );
      expect(jsonEncode(request.headers), isNot(contains(appName)));
    }
  });

  test('devrait lire le registre officiel sans --registry, refuser le Pro sans clé (8), puis l’installer après fliin login, la clé n’allant qu’à l’hôte Pro (règle 7, ADR 0020 §5)', skip: withoutPro, () async {
    const license = 'FLIIN-PRO-TEST-0F3A-9C2E-ABCD';
    final source = SourceRegistry.read(sourceRoot);
    final publicDist = tempDir().path;
    final proDist = tempDir().path;
    await DistWriter(publicDist).write(
      source.withoutProCode(),
      stamp: BuildStamp.following(publicDist),
      key: await testKey(),
    );
    await DistWriter(proDist).write(
      source,
      stamp: BuildStamp.following(proDist, version: 5),
      key: await testKey(),
    );
    final public = await HttpsRegistryServer.start(publicDist, tls: _tls);
    final pro = await HttpsRegistryServer.start(proDist, tls: _tls)
      ..license = license;
    addTearDown(public.close);
    addTearDown(pro.close);
    final home = tempDir().path;
    final official = {
      'FLIIN_TEST_REGISTRY': '${public.uri}',
      'FLIIN_TEST_PRO_REGISTRY': '${pro.uri}',
      'FLIIN_TEST_OFFICIAL_KEY': _publicKey,
    };
    final app = await createFlutterProject('pro_app');
    Future<ProcessResult> run(
      List<String> args, {
      Map<String, String> environment = const {},
    }) => _fliin(
      ['-C', app.path, ...args],
      home: home,
      environment: {...official, ...environment},
    );
    final credentials = File(p.join(home, '.config', 'fliin', 'credentials.json'));
    final widget = File(p.join(app.path, 'lib/ui/fliin/components/empty_state/fl_empty_state.dart'));

    final init = await run(['init', '--agent', 'none']);
    expect(init.exitCode, 0, reason: '${init.stderr}');
    expect(File(p.join(app.path, 'fliin.yaml')).readAsStringSync(), contains('registries: {}'));

    final refused = await run(['add', 'empty-state']);
    expect(refused.exitCode, 8, reason: '${refused.stderr}');
    expect(
      '${refused.stderr}',
      'empty-state is a Fliin Pro item. Get a license at https://fliin.dev/pro, then run fliin login.\n',
    );
    expect(widget.existsSync(), isFalse);

    final wrong = await run(['login', 'FLIIN-PRO-WRONG']);
    expect(wrong.exitCode, 8, reason: '${wrong.stderr}');
    expect('${wrong.stderr}', contains('not valid for Fliin Pro'));
    expect(credentials.existsSync(), isFalse);

    final login = await Process.start(
      Platform.resolvedExecutable,
      [_cli, '-C', app.path, 'login'],
      environment: {
        'HOME': home,
        'FLIIN_TEST_CA': _tls.caPem,
        'FLIIN_LICENSE_KEY': '',
        'XDG_CONFIG_HOME': '',
        ...official,
      },
    );
    login.stdin.writeln(license);
    await login.stdin.close();
    final (loginOut, loginErr) = await (
      login.stdout.transform(utf8.decoder).join(),
      login.stderr.transform(utf8.decoder).join(),
    ).wait;
    expect(await login.exitCode, 0, reason: loginErr);
    expect(loginErr, 'License key: ');
    expect(loginOut, contains('License key …ABCD saved to ${credentials.path}.'));
    expect('$loginOut$loginErr', isNot(contains(license)));
    expect(FileStat.statSync(credentials.path).mode & 0x1ff, 0x180, reason: '0600');
    expect(FileStat.statSync(credentials.parent.path).mode & 0x1ff, 0x1c0, reason: '0700');

    final add = await run(['add', 'empty-state', '--accept-deps']);
    expect(add.exitCode, 0, reason: '${add.stderr}');
    expect(widget.readAsStringSync(), startsWith('// Part of Fliin Pro.'));

    final status = await run(['status']);
    expect(status.exitCode, 0, reason: '${status.stderr}');
    expect('${status.stdout}', contains('Fliin Pro: license key …ABCD active (${credentials.path}).'));
    expect('${status.stdout}', isNot(contains(license)));
    final fromEnvironment = await run(['status', '--json'], environment: {'FLIIN_LICENSE_KEY': 'FLIIN-PRO-CI-WXYZ'});
    expect(_json(fromEnvironment)['license'], {'active': true, 'key': '…WXYZ', 'origin': 'environment'});

    final logout = await run(['logout']);
    expect(logout.exitCode, 0, reason: '${logout.stderr}');
    expect(credentials.existsSync(), isFalse);
    expect('${(await run(['status'])).stdout}', contains('Fliin Pro: no license key.'));
    final free = await run(['add', 'separator']);
    expect(free.exitCode, 0, reason: 'le registre public après le Pro, version 1 après 5 : chacun son anti-retour. ${free.stderr}');

    final layout = RegExp(
      r'^(latest\.json|index/[0-9a-f]{64}\.json|items/fliin/[a-z0-9-]+/[0-9.]+\.json|blobs/[0-9a-f]{2}/[0-9a-f]{64})$',
    );
    expect(pro.requests, isNotEmpty);
    for (final (server, bearer) in [(public, false), (pro, true)]) {
      for (final request in server.requests) {
        expect(request.path, matches(layout), reason: 'règle 7');
        expect(
          request.headers.keys.toSet(),
          everyElement(isIn([
            'user-agent', 'accept-encoding', 'host', 'content-length',
            if (bearer) 'authorization',
          ])),
          reason: jsonEncode(request.headers),
        );
      }
    }
    expect(
      pro.requests.map((r) => r.headers['authorization']?.single).toSet(),
      {'Bearer FLIIN-PRO-WRONG', 'Bearer $license'},
    );
  });

  test('devrait refuser dès fliin init un registre http:// hors de localhost, en nommant l’URL, sans rien écrire', () async {
    final app = await createFlutterProject('http_app');
    final init = await _fliin([
      '-C',
      app.path,
      'init',
      '--registry',
      'http://registry.example.com/',
      '--trusted-key',
      _publicKey,
    ], home: tempDir().path);
    expect(init.exitCode, 64, reason: '${init.stderr}');
    expect(
      '${init.stderr}',
      allOf(
        contains('http://registry.example.com/'),
        contains('(use https://)'),
      ),
    );
    expect(File(p.join(app.path, 'fliin.yaml')).existsSync(), isFalse);
  });

  test('devrait sortir 3 en nommant l’URL quand un blob manque, et 5 quand il est altéré', () async {
    final app = await createFlutterProject('faults_app');
    final home = tempDir().path;
    final init = await _fliin([
      '-C',
      app.path,
      'init',
      '--registry',
      '${_server.uri}',
      '--trusted-key',
      _publicKey,
    ], home: home);
    expect(init.exitCode, 0, reason: '${init.stderr}');
    final file = SourceRegistry.read(_source).manifests
        .singleWhere((m) => m.name == 'switch')
        .files
        .single;
    final path = DistLayout.blobPath(file.sha256);
    addTearDown(() => _server.faults.remove(path));

    _server.faults[path] = const Status(404);
    final missing = await _fliin(['-C', app.path, 'add', 'switch'], home: home);
    expect(missing.exitCode, 3, reason: '${missing.stderr}');
    expect(
      '${missing.stderr}',
      allOf(contains('${_server.uri}$path'), contains('HTTP 404')),
    );

    _server.faults[path] = const Tamper();
    final tampered = await _fliin([
      '-C',
      app.path,
      'add',
      'switch',
    ], home: home);
    expect(tampered.exitCode, 5, reason: '${tampered.stderr}');
    expect('${tampered.stderr}', contains('Integrity check failed for ${_server.uri}$path'));
    expect(
      File(p.join(app.path, 'lib/ui/fliin/components/switch/fl_switch.dart'))
          .existsSync(),
      isFalse,
    );
  });

  test('devrait passer par HTTPS_PROXY quand il est défini', () async {
    final proxy = await ConnectProxy.start();
    addTearDown(proxy.close);
    final search = await _fliin(
      [
        'search',
        'activer ou désactiver un réglage',
        '--registry',
        '${_server.uri}',
        '--key',
        _publicKey,
      ],
      home: tempDir().path,
      environment: {
        for (final name in ['HTTPS_PROXY', 'https_proxy'])
          name: '127.0.0.1:${proxy.port}',
      },
    );
    expect(search.exitCode, 0, reason: '${search.stderr}');
    expect(proxy.targets, isNotEmpty);
    expect(proxy.targets.toSet(), {'127.0.0.1:${_server.uri.port}'});
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:fliin/fliin.dart';

import 'fake_registry.dart';

typedef CliRun = ({int code, String out, String err});

/// Lance le CLI sur [dir] avec [registry] (défaut : le registre source du
/// dépôt), sorties capturées. [licenses] : aucune clé de licence par défaut,
/// jamais celle de la machine.
Future<CliRun> fliin(
  Directory dir,
  List<String> args, {
  Registry? registry,
  LicenseStore? licenses,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await run(
    ['-C', dir.path, ...args],
    openRegistry: (_) async => registry ?? FakeRegistry(),
    io: (out: out, err: err),
    licenses:
        licenses ??
        LicenseStore(
          environment: {
            'HOME': Directory.systemTemp.createTempSync('fliin-home').path,
          },
        ),
  );
  return (code: code, out: '$out', err: '$err');
}

Map<String, Object?> jsonOf(CliRun run) =>
    jsonDecode(run.out) as Map<String, Object?>;

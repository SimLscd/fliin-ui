import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;

import '../registry/build.dart';
import '../registry/lint.dart';
import '../registry/signing.dart';

class RegistryBuildCommand extends Command<int> {
  RegistryBuildCommand() {
    argParser
      ..addOption(
        'source',
        defaultsTo: 'flutter/registry',
        help: 'The source folder: items/*.json and lib/.',
      )
      ..addOption(
        'out',
        defaultsTo: 'dist',
        help: 'The static registry folder.',
      )
      ..addOption(
        'key',
        defaultsTo: 'fliin-signing.key',
        help: 'The Ed25519 private key (fliin registry keygen).',
      )
      ..addOption(
        'version',
        help: 'The pointer version (default: the one in the latest.json of --out, plus one).',
      )
      ..addMultiOption(
        'yank',
        valueHelp: 'item@version',
        help:
            'Yanks this version from resolution, on top of the versions the '
            'latest.json of --out already yanks. Repeatable.',
      )
      ..addFlag(
        'include-pro',
        negatable: false,
        help:
            'Keeps the code of Pro items: the Pro registry, or a local '
            'registry for tests. Without it, the registry lists Pro items '
            'and serves none of their code.',
      )
      ..addOption(
        'blobs-from',
        valueHelp: 'dist',
        help:
            'Another dist/ to read the published blobs that --out lacks: the '
            'Pro dist/, so the public registry computes the breaking changes '
            'of a new Pro version.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Prints {items, blobs, pointerVersion}.',
      );
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      'Writes dist/ from the source, then the signed latest.json last.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final source = args.option('source')!;
    final out = args.option('out')!;
    final SigningKey key;
    try {
      key = await SigningKey.read(args.option('key')!);
    } on SigningKeyError catch (e) {
      stderr.writeln(e);
      return 3;
    }
    final int? version;
    switch (args.option('version')) {
      case null:
        version = null;
      case final text:
        version = int.tryParse(text);
        if (version == null || version < 1) {
          usageException('--version expects a positive integer: $text');
        }
    }
    final List<ItemRef> yank;
    try {
      yank = [
        for (final text in args.multiOption('yank'))
          ItemRef.parseVersioned(text),
      ];
    } on FormatException catch (e) {
      usageException('--yank: ${e.message}: ${e.source}');
    }
    try {
      final stamp = BuildStamp.following(out, version: version, yank: yank);
      if (stamp.previous == null && version == null) {
        stderr.writeln(
          'No latest.json in $out. The pointer starts at version 1 and the '
          'index carries over no version published elsewhere. A client that '
          'has already seen a higher version of this registry will reject '
          'it. To publish again, start from the published dist/ or pass a '
          'higher --version.',
        );
      }
      if (stamp.previous == null) {
        stderr.writeln(
          'No previous version in $out, so no breaking change was computed '
          '(breaking[] only holds the declared "semantic" ones).',
        );
      }
      final read = SourceRegistry.read(source);
      final registry = args.flag('include-pro') ? read : read.withoutProCode();
      final findings = lintSource(read, out: out, root: source);
      for (final finding in findings) {
        stderr.writeln(finding);
      }
      final blocking = findings.where((f) => f.rule.blocking).length;
      if (blocking > 0) {
        stderr.writeln(
          'Publishing refused: $blocking writing rule '
          '${blocking > 1 ? 'violations' : 'violation'}. Nothing was written '
          'in $out.',
        );
        return 1;
      }
      final summary = await DistWriter(
        out,
        blobsFrom: args.option('blobs-from'),
      ).write(registry, stamp: stamp, key: key);
      stdout.writeln(
        args.flag('json')
            ? jsonEncode({
                'items': summary.items,
                'blobs': summary.blobs,
                'pointerVersion': summary.pointerVersion,
              })
            : '${summary.items} items, ${summary.blobs} blobs, latest.json '
                  'version ${summary.pointerVersion} signed by ${key.publicKey} in $out',
      );
      return 0;
    } on BuildError catch (e) {
      stderr.writeln(e);
      return 1;
    }
  }
}

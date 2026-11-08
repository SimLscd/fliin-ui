import 'dart:io';

import 'package:path/path.dart' as p;

import '../project/fliin_yaml.dart';
import '../tokens/project_tokens.dart';
import 'exit_code.dart';
import 'project_command.dart';

class TokensCommand extends ProjectCommand {
  TokensCommand(super.openRegistry, super.io) {
    argParser.addFlag(
      'check',
      negatable: false,
      help: 'Exits with 1 if tokens.g.dart differs from what would be generated, without writing.',
    );
  }

  @override
  String get name => 'tokens';

  @override
  String get description =>
      'Regenerates core/tokens/tokens.g.dart from core/tokens/fliin.tokens.json.';

  @override
  bool get writesProject => !argResults!.flag('check');

  @override
  Future<int> execute() async {
    final dir = projectDir;
    final config = readFliinConfig(dir);
    if (config == null) {
      return fail(
        ExitCode.environment,
        '$fliinYamlName not found. Run fliin init.',
      );
    }
    final tokensDir = Directory(
      p.join(dir.path, config.render.root, 'core', 'tokens'),
    );
    final relative = p.relative(
      p.join(tokensDir.path, tokensDartName),
      from: dir.path,
    );
    final json = p.relative(
      p.join(tokensDir.path, tokensJsonName),
      from: dir.path,
    );
    final check = argResults!.flag('check');
    return switch (generateTokens(
      tokensDir,
      prefix: config.render.prefix,
      check: check,
    )) {
      TokensWritten() => succeed(
        {'tokens': json, 'generated': relative, 'upToDate': false},
        ['$relative written from $json.'],
      ),
      TokensUpToDate() => succeed(
        {'tokens': json, 'generated': relative, 'upToDate': true},
        ['$relative is up to date.'],
      ),
      TokensStale() => fail(
        ExitCode.failure,
        '$relative differs from $json. Run fliin tokens.',
        {'tokens': json, 'generated': relative, 'upToDate': false},
      ),
      TokensInvalid(:final error) => fail(ExitCode.failure, '$json: $error', {
        'tokens': json,
        'generated': relative,
      }),
    };
  }
}

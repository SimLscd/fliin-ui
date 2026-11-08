import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fliin_schema/fliin_schema.dart' hide Platform;
import 'package:path/path.dart' as p;

import '../project/agents.dart';
import '../project/flutter_sdk.dart';
import 'exit_code.dart';
import 'init.dart';
import 'project_command.dart';

/// `flutter create`, puis `fliin init`, puis un `lib/main.dart` dont le
/// `builder:` pose déjà le scope : une app qui affiche un composant dès le
/// premier `fliin add`, sans rien à coller.
class CreateCommand extends ProjectCommand {
  CreateCommand(super.openRegistry, super.io) {
    argParser
      ..addOption(
        'project-name',
        help: 'The Dart package name (default: the folder name).',
      )
      ..addOption(
        'org',
        help: 'The organization, as a reverse domain name (flutter create --org).',
      )
      ..addOption(
        'platforms',
        help: 'Comma-separated platforms (flutter create --platforms).',
      )
      ..addOption(
        'preset',
        valueHelp: 'code',
        help: 'Same as fliin init --preset.',
      )
      ..addMultiOption(
        'agent',
        allowed: [for (final kind in AgentKind.values) kind.wire, 'none'],
        help: 'Same as fliin init --agent.',
      )
      ..addOption('root', help: 'Same as fliin init --root.')
      ..addOption('prefix', help: 'Same as fliin init --prefix.')
      ..addOption('registry', help: 'Same as fliin init --registry.')
      ..addMultiOption(
        'trusted-key',
        help: 'Same as fliin init --trusted-key.',
      );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Creates a Flutter app with Fliin initialized and its scope in place.';

  @override
  String get invocation => 'fliin create <folder>';

  @override
  Future<int> execute() async {
    final args = argResults!;
    if (args.rest.length != 1) usageException('Expected one folder.');
    final dir = Directory(
      p.normalize(p.join(projectDir.path, args.rest.single)),
    );
    if (dir.existsSync() && dir.listSync().isNotEmpty) {
      return fail(
        ExitCode.failure,
        '${dir.path} exists and is not empty. Pick an empty or new folder.',
      );
    }
    final existed = dir.existsSync();
    final relative = p.relative(dir.path, from: projectDir.path);
    // Un échec ne laisse rien : un dossier non vide ferait refuser la
    // relance, et une app sans Fliin n'est pas ce qui a été demandé.
    var done = false;
    try {
      final package =
          args.option('project-name') ?? _packageName(p.basename(dir.path));
      final sdk = await FlutterSdk.locate(Platform.environment);
      final created = await Process.run(sdk.flutter, [
        'create',
        '--empty',
        '--project-name',
        package,
        if (args.option('org') case final org?) ...['--org', org],
        if (args.option('platforms') case final platforms?)
          '--platforms=$platforms',
        dir.path,
      ]);
      if (created.exitCode != 0) {
        return fail(
          ExitCode.failure,
          'flutter create failed:\n${created.stderr}${created.stdout}',
        );
      }

      final out = StringBuffer();
      final err = StringBuffer();
      final runner = CommandRunner<int>('fliin', '')
        ..argParser.addOption('directory', abbr: 'C')
        ..addCommand(InitCommand(openRegistry, (out: out, err: err)));
      final int code;
      try {
        code =
            await runner.run([
              '-C',
              dir.path,
              'init',
              '--json',
              // Le dossier vient d'être créé : dans un dépôt parent, il le salit.
              '--allow-dirty',
              for (final option in ['preset', 'root', 'prefix', 'registry'])
                if (args.option(option) case final value?) '--$option=$value',
              for (final option in ['agent', 'trusted-key'])
                for (final value in args.multiOption(option))
                  '--$option=$value',
            ]) ??
            0;
      } on UsageException catch (e) {
        usageException('fliin init refused: ${e.message} Nothing was created.');
      }
      final init = jsonDecode('$out') as Map<String, Object?>;
      if (code != ExitCode.ok.code) {
        final error = init['error']! as Map<String, Object?>;
        return fail(
          ExitCode.values.firstWhere(
            (c) => c.code == code,
            orElse: () => ExitCode.failure,
          ),
          'fliin init failed: ${error['message']} Nothing was created.',
          {'init': init},
        );
      }

      final config = init['config']! as Map<String, Object?>;
      final render = RenderConfig(
        root: config['root']! as String,
        prefix: config['prefix']! as String,
        package: package,
      );
      File(p.join(dir.path, 'lib', 'main.dart'))
          .writeAsStringSync(mainDart(render));
      final agents = init['agents']! as Map<String, Object?>;
      final configured = (agents['configured']! as List<Object?>)
          .cast<String>();
      final noAgents = args.multiOption('agent').contains('none');
      done = true;
      return succeed(
        {
          'path': dir.path,
          'package': package,
          'init': init,
          'written': ['lib/main.dart'],
          'next': [
            'cd $relative',
            'fliin search "<intent>" --json',
            'fliin add <item> --json',
          ],
        },
        [
          'App $package created in $relative. Fliin initialized in '
              '${render.root} (prefix ${render.prefix}).',
          '  lib/main.dart: ${render.prefix}Scope set in the builder: of '
              'MaterialApp.',
          if (configured.isNotEmpty)
            '  fliin MCP server connected: ${configured.join(', ')}.',
          if (!noAgents) '  AGENTS.md: the working loop for your agents.',
          '',
          'Next:',
          '  cd $relative',
          '  fliin search "<intent>"',
          '  fliin add <item>',
          if (configured.isEmpty)
            '  fliin agents --agent claude|cursor|gemini|codex|vscode',
        ],
      );
    } finally {
      if (!done && dir.existsSync()) {
        if (existed) {
          for (final entity in dir.listSync()) {
            entity.deleteSync(recursive: true);
          }
        } else {
          dir.deleteSync(recursive: true);
        }
      }
    }
  }

  /// [folder] en nom de paquet Dart : minuscules, `_` pour le reste.
  static String _packageName(String folder) {
    final name = folder.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
    return RegExp('^[a-z]').hasMatch(name) ? name : 'app_$name';
  }
}

/// Le `lib/main.dart` de `create` : MaterialApp, parce que les extraits de
/// route des écrans poussent des `MaterialPageRoute`.
String mainDart(RenderConfig render) {
  final prefix = render.prefix;
  return '''
import 'package:flutter/material.dart';

import 'package:${render.package}/${render.importRoot}/core/fliin.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) =>
        ${prefix}Scope(child: child ?? const SizedBox.shrink()),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ${prefix}Scope.of(context);
    return ColoredBox(
      color: theme.colors.surface,
      child: Center(
        child: Text(
          'fliin add <item>',
          style: theme.typography
              .resolve(${prefix}TextRole.body)
              .copyWith(
                color: theme.colors.onSurface,
                decoration: TextDecoration.none,
              ),
        ),
      ),
    );
  }
}
''';
}

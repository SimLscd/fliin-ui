import 'dart:convert';
import 'dart:io';

import 'package:fliin/src/project/agents.dart';
import 'package:fliin/src/project/fliin_yaml.dart';
import 'package:fliin/src/project/invalid_project_file.dart';
import 'package:fliin_schema/fliin_schema.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/cli.dart';

void main() {
  late Directory dir;
  final render = RenderConfig(
    root: 'lib/ui/fliin',
    prefix: 'Ac',
    package: 'demo',
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('fliin-agents-'));
  tearDown(() => dir.deleteSync(recursive: true));

  String read(String path) => File(p.join(dir.path, path)).readAsStringSync();
  void write(String path, String text) => File(p.join(dir.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);
  Object? json(String path) => jsonDecode(read(path));

  AgentFiles writeFor(List<AgentKind> kinds) =>
      writeAgentConfigs(dir, kinds, executable: '/bin/fliin', render: render);

  group('detectAgents', () {
    test(
      'devrait ne rien détecter quand le projet ne porte aucune trace d’agent',
      () {
        write('.vscode/settings.json', '{}');
        expect(detectAgents(dir), isEmpty);
      },
    );

    test(
      'devrait détecter chaque client par sa trace, dans l’ordre de AgentKind',
      () {
        write('.codex/config.toml', '');
        write('CLAUDE.md', '# App\n');
        write('.cursor/rules/a.mdc', '');
        write('GEMINI.md', '');
        write('.github/copilot-instructions.md', '');
        expect(detectAgents(dir), [
          AgentKind.claude,
          AgentKind.cursor,
          AgentKind.gemini,
          AgentKind.codex,
          AgentKind.vscode,
        ]);
      },
    );
  });

  group('writeAgentConfigs', () {
    test('devrait importer AGENTS.md dans CLAUDE.md une seule fois quand Claude Code est branché deux fois', () {
      write('CLAUDE.md', '# Mon app');
      writeFor([AgentKind.claude]);
      writeFor([AgentKind.claude]);
      expect(read('CLAUDE.md'), '# Mon app\n\n@AGENTS.md\n');
      expect(json('.mcp.json'), {
        'mcpServers': {
          'fliin': {
            'command': '/bin/fliin',
            'args': ['mcp'],
          },
        },
      });
    });

    test('devrait faire lire AGENTS.md à Gemini CLI en gardant ses autres fichiers de contexte', () {
      write(
        '.gemini/settings.json',
        '{"context": {"fileName": "NOTES.md"}, "theme": "x"}',
      );
      writeFor([AgentKind.gemini]);
      final settings = json('.gemini/settings.json')! as Map<String, Object?>;
      expect(settings['context'], {
        'fileName': ['AGENTS.md', 'NOTES.md'],
      });
      expect(settings['theme'], 'x');
      expect(settings['mcpServers'], contains('fliin'));
    });

    test('devrait garder GEMINI.md quand Gemini CLI n’avait aucun fichier de contexte déclaré', () {
      writeFor([AgentKind.gemini]);
      expect((json('.gemini/settings.json')! as Map)['context'], {
        'fileName': ['AGENTS.md', 'GEMINI.md'],
      });
    });

    test('devrait écrire le serveur VS Code sous servers, en stdio', () {
      writeFor([AgentKind.vscode]);
      expect(json('.vscode/mcp.json'), {
        'servers': {
          'fliin': {
            'type': 'stdio',
            'command': '/bin/fliin',
            'args': ['mcp'],
          },
        },
      });
    });

    test('devrait remplacer la table fliin de Codex et ses sous-tables sans toucher au reste', () {
      write('.codex/config.toml', '''
model = "gpt-5"

[mcp_servers.fliin]
command = "/old/fliin"
args = ["mcp"]

[mcp_servers.fliin.env]
A = "1"

[mcp_servers.other]
command = "other"
''');
      writeFor([AgentKind.codex]);
      writeFor([AgentKind.codex]);
      expect(read('.codex/config.toml'), '''
model = "gpt-5"

[mcp_servers.other]
command = "other"

[mcp_servers.fliin]
command = "/bin/fliin"
args = ["mcp"]
''');
    });

    test('devrait reconnaître la table fliin de Codex quand un tableau sur plusieurs lignes ouvre une ligne par un crochet', () {
      write('.codex/config.toml', '''
[mcp_servers.other]
args = [
  ["nested"],
  "x",
]

[mcp_servers.fliin]
command = "/old/fliin"
''');
      writeFor([AgentKind.codex]);
      expect(read('.codex/config.toml'), '''
[mcp_servers.other]
args = [
  ["nested"],
  "x",
]

[mcp_servers.fliin]
command = "/bin/fliin"
args = ["mcp"]
''');
    });

    for (final (label, toml) in [
      (
        'en table en ligne sous [mcp_servers]',
        '[mcp_servers]\nfliin = { command = "x" }\n',
      ),
      ('par clés pointées à la racine', 'mcp_servers.fliin.command = "x"\n'),
      (
        'dans une table mcp_servers en ligne',
        'mcp_servers = { other = { command = "y" } }\n',
      ),
    ]) {
      test('devrait refuser sans écrire quand Codex déclare fliin $label', () {
        write('.codex/config.toml', toml);
        expect(
          () => checkAgentConfigs(dir, [AgentKind.codex]),
          throwsA(
            isA<InvalidProjectFile>().having(
              (e) => e.reason,
              'reason',
              contains('[mcp_servers.fliin]'),
            ),
          ),
        );
        expect(read('.codex/config.toml'), toml);
      });
    }

    test('devrait écrire AGENTS.md aux noms du projet et le réécrire entre ses marqueurs', () {
      write('AGENTS.md', '# App\n');
      writeFor(const []);
      final first = read('AGENTS.md');
      expect(first, startsWith('# App\n\n<!-- fliin:start -->'));
      expect(first, contains('`lib/ui/fliin/`'));
      expect(first, contains('AcScope.of(context)'));
      writeFor(const []);
      expect(read('AGENTS.md'), first);
    });
  });

  group('fliin agents', () {
    void initialised([List<AgentConfig> agents = const []]) => writeFliinConfig(
      dir,
      FliinConfig(render: render, registries: const {}, agents: agents),
    );

    test('devrait sortir en 3 quand le projet n’est pas initialisé', () async {
      final run = await fliin(dir, ['agents']);
      expect(run.code, 3);
      expect(run.err, contains('fliin init'));
    });

    test(
      'devrait brancher les agents détectés et les ajouter à fliin.yaml',
      () async {
        initialised();
        write('.cursor/rules/a.mdc', '');
        final run = await fliin(dir, ['agents', '--json']);
        expect(run.code, 0, reason: run.err);
        expect(jsonOf(run)['added'], ['cursor']);
        expect(read('.cursor/mcp.json'), contains('"fliin"'));
        expect(read('AGENTS.md'), contains('<!-- fliin:start -->'));
        expect(readFliinConfig(dir)!.agents, [isA<CursorAgent>()]);
      },
    );

    test('devrait écarter sans le réécrire un client détecté dont la config a des commentaires', () async {
      initialised();
      const jsonc = '// Copilot\n{"servers": {}}\n';
      write('.vscode/mcp.json', jsonc);
      write('.cursor/rules/a.mdc', '');
      final run = await fliin(dir, ['agents', '--json']);
      expect(run.code, 0, reason: run.err);
      final out = jsonOf(run);
      expect(out['agents'], ['cursor']);
      expect(out['skipped'], [
        {
          'agent': 'vscode',
          'path': '.vscode/mcp.json',
          'reason': isA<String>(),
        },
      ]);
      expect(read('.vscode/mcp.json'), jsonc);
      expect(readFliinConfig(dir)!.agents, [isA<CursorAgent>()]);

      final text = await fliin(dir, ['agents']);
      expect(text.out, contains('fliin agents --agent vscode'));
    });

    test('devrait sortir en 1 sans rien écrire quand le client nommé a une config à commentaires', () async {
      initialised();
      write('.vscode/mcp.json', '// Copilot\n{}\n');
      final run = await fliin(dir, ['agents', '--agent', 'vscode']);
      expect(run.code, 1);
      expect(run.err, contains('mcp.json'));
      expect(File(p.join(dir.path, 'AGENTS.md')).existsSync(), isFalse);
    });

    test(
      'devrait garder les agents de fliin.yaml et ajouter ceux de --agent',
      () async {
        initialised([const ClaudeCodeAgent()]);
        final run = await fliin(dir, ['agents', '--agent', 'codex', '--json']);
        expect(run.code, 0, reason: run.err);
        final out = jsonOf(run);
        expect(out['agents'], ['claude', 'codex']);
        expect(out['added'], ['codex']);
        expect(read('.codex/config.toml'), contains('[mcp_servers.fliin]'));
        expect(read('CLAUDE.md'), contains('@AGENTS.md'));
        expect(readFliinConfig(dir)!.agents, [
          isA<ClaudeCodeAgent>(),
          isA<CodexAgent>(),
        ]);
      },
    );

    test(
      'devrait reprendre le port et le jeton d’Android Studio déjà tirés',
      () async {
        initialised([const AndroidStudioAgent(port: 50123)]);
        write('.fliin/local.json', '{"androidStudio": {"token": "secret"}}');
        final run = await fliin(dir, ['agents', '--json']);
        expect(run.code, 0, reason: run.err);
        expect(
          (jsonOf(run)['androidStudio']! as Map)['httpUrl'],
          'http://127.0.0.1:50123/mcp',
        );
        expect(read('.fliin/local.json'), contains('secret'));
        expect(jsonOf(run)['written'], isNot(contains('.fliin/local.json')));
        expect(run.out, isNot(contains('secret')));
      },
    );
  });
}

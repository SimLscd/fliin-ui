import '../project/project.dart' show minimumFlutter;
import 'site_text.dart';

/// A block of the getting started guide: the HTML page and its Markdown
/// version render the same blocks, so that neither says more than the other.
sealed class GuideBlock {
  const GuideBlock();
}

/// A paragraph: [copy], each `{name}` filled by inline [code], a [links]
/// target, a [plain] value or another text of the site ([labels]).
final class GuideText extends GuideBlock {
  const GuideText(
    this.copy, {
    this.code = const {},
    this.links = const {},
    this.plain = const {},
    this.labels = const {},
  });

  final Copy copy;
  final Map<String, String> code;
  final Map<String, GuideLink> links;
  final Map<String, String> plain;
  final Map<String, Copy> labels;
}

/// A link to a page of the site, by its path from the site root, labeled by
/// a text of [Copy] or, for a file name, by [code].
final class GuideLink {
  const GuideLink(this.path, {this.label, this.code});

  final String path;
  final Copy? label;
  final String? code;
}

/// A code block: shell commands, or Dart.
final class GuideCode extends GuideBlock {
  const GuideCode(this.code, {this.lang = 'sh'});

  final String code;
  final String lang;
}

/// A bulleted list of paragraphs.
final class GuideList extends GuideBlock {
  const GuideList(this.items);

  final List<GuideText> items;
}

typedef GuideSection = ({String id, Copy title, List<GuideBlock> blocks});

/// The guide's folder, from the site root.
const guidePath = 'getting-started/';

/// A preset the theme page can build: `guide_test` checks that it decodes.
const guidePreset = 'c05ONTp0000000';

/// The `lib/main.dart` the guide shows after `fliin add button`, in the app
/// that `fliin create my_app` makes: it compiles as is there.
const guideMainDart = '''
import 'package:flutter/material.dart';

import 'package:my_app/ui/fliin/components/button/fl_button.dart';
import 'package:my_app/ui/fliin/core/fliin.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) =>
        FlScope(child: child ?? const SizedBox.shrink()),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlScope.of(context);
    return ColoredBox(
      color: theme.colors.surface,
      child: Center(
        child: FlButton(label: 'Save', loading: _saving, onPressed: _save),
      ),
    );
  }
}''';

/// The lines `fliin init` prints for the `builder:` of the app, in place.
const _scopeSnippet = '''
import 'package:my_app/ui/fliin/core/fliin.dart';

MaterialApp(
  builder: (context, child) => FlScope(
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
)''';

/// The home page's quick start for a new app: each command, and what it
/// leaves behind. `guide_test` passes every `fliin` line to the CLI.
const quickStartNew = [
  ('dart pub global activate fliin', null),
  ('fliin create my_app', null),
  ('cd my_app', null),
  ('fliin add button', Copy.startNoteFolder),
  ('fliin verify button', Copy.startNoteVariants),
];

/// The same for an app that already exists.
const quickStartExisting = [
  ('dart pub global activate fliin', null),
  ('fliin init', Copy.startNoteScope),
  ('fliin add button', Copy.startNoteFolder),
  ('fliin verify button', Copy.startNoteVariants),
  ('fliin agents --agent claude', Copy.startNoteMcp),
];

/// The guide, in the order of a first use.
List<GuideSection> guideSections() => [
  (
    id: 'requirements',
    title: Copy.guideRequirementsTitle,
    blocks: [
      GuideText(
        Copy.guideRequirements,
        plain: {'flutter': '${minimumFlutter.major}.${minimumFlutter.minor}'},
      ),
      const GuideText(
        Copy.guideRequirementsGit,
        code: {'init': 'fliin init', 'dirty': '--allow-dirty'},
      ),
    ],
  ),
  (
    id: 'install',
    title: Copy.guideInstallTitle,
    blocks: const [
      GuideText(Copy.guideInstall),
      GuideCode('dart pub global activate fliin'),
      GuideText(
        Copy.guideInstallPath,
        code: {
          'path': r'$HOME/.pub-cache/bin',
          'windows': r'%LOCALAPPDATA%\Pub\Cache\bin',
        },
      ),
      GuideCode('fliin version'),
    ],
  ),
  (
    id: 'create',
    title: Copy.guideCreateTitle,
    blocks: const [
      GuideText(
        Copy.guideCreate,
        code: {
          'create': 'fliin create',
          'main': 'lib/main.dart',
          'scope': 'FlScope',
        },
      ),
      GuideCode('fliin create my_app\ncd my_app\nflutter run'),
      GuideText(
        Copy.guideCreateOptions,
        code: {
          'create': 'fliin create',
          'init': 'fliin init',
          'root': '--root',
          'prefix': '--prefix',
          'preset': '--preset',
          'agent': '--agent',
        },
      ),
    ],
  ),
  (
    id: 'init',
    title: Copy.guideInitTitle,
    blocks: const [
      GuideText(Copy.guideInit),
      GuideCode('fliin init'),
      GuideText(
        Copy.guideInitRegistry,
        code: {'registry': '--registry', 'key': '--trusted-key'},
      ),
      GuideText(Copy.guideInitWrites),
      GuideList([
        GuideText(
          Copy.guideFileYaml,
          code: {'file': 'fliin.yaml', 'root': 'lib/ui/fliin', 'prefix': 'Fl'},
        ),
        GuideText(
          Copy.guideFileLock,
          code: {'file': 'fliin.lock.json', 'update': 'fliin update'},
        ),
        GuideText(Copy.guideFileCore, code: {'file': 'lib/ui/fliin/core/'}),
        GuideText(Copy.guideFileAgents, code: {'file': 'AGENTS.md'}),
        GuideText(Copy.guideFileIgnore, code: {'file': '.gitignore'}),
        GuideText(
          Copy.guideFileLicense,
          code: {'file': 'lib/ui/fliin/LICENSE'},
        ),
      ]),
      GuideText(
        Copy.guideScope,
        code: {'init': 'fliin init', 'builder': 'builder:'},
      ),
      GuideCode(_scopeSnippet, lang: 'dart'),
      GuideText(
        Copy.guideScopeBody,
        code: {'scope': 'FlScope', 'widgets': 'widgets.dart'},
      ),
    ],
  ),
  (
    id: 'add',
    title: Copy.guideAddTitle,
    blocks: const [
      GuideCode('fliin add button'),
      GuideText(
        Copy.guideAdd,
        code: {
          'add': 'fliin add',
          'core': 'core',
          'spinner': 'spinner',
          'folder': 'lib/ui/fliin/components/',
        },
      ),
      GuideText(
        Copy.guideAddOwn,
        code: {'main': 'lib/main.dart', 'create': 'fliin create my_app'},
      ),
      GuideCode(guideMainDart, lang: 'dart'),
      GuideText(
        Copy.guideFind,
        code: {
          'search': 'fliin search',
          'list': 'fliin list',
          'view': 'fliin view',
        },
        links: {
          'components': GuideLink(
            'components/',
            label: Copy.guideComponentPages,
          ),
        },
      ),
      GuideCode('fliin search "confirm before deleting"\nfliin view button'),
    ],
  ),
  (
    id: 'theme',
    title: Copy.guideThemeTitle,
    blocks: const [
      GuideText(
        Copy.guideThemePreset,
        links: {'theme': GuideLink('theme/', label: Copy.themeTitle)},
        labels: {'getCode': Copy.presetGetCode},
      ),
      GuideCode('fliin theme --preset $guidePreset'),
      GuideText(Copy.guideThemePrimary),
      GuideCode('fliin theme --primary "#7C3AED"'),
      GuideText(
        Copy.guideThemeFiles,
        code: {
          'json': 'core/tokens/fliin.tokens.json',
          'dart': 'tokens.g.dart',
          'pubspec': 'pubspec.yaml',
          'create': 'fliin create --preset',
        },
      ),
    ],
  ),
  (
    id: 'verify',
    title: Copy.guideVerifyTitle,
    blocks: const [
      GuideCode('fliin verify button'),
      GuideText(
        Copy.guideVerify,
        code: {
          'verify': 'fliin verify',
          'folder': 'build/fliin/verify/button/',
        },
      ),
      GuideText(Copy.guideVerifyChanged),
      GuideCode('fliin verify --changed'),
    ],
  ),
  (
    id: 'update',
    title: Copy.guideUpdateTitle,
    blocks: const [
      GuideCode('fliin update --check\nfliin diff button\nfliin update'),
      GuideText(
        Copy.guideUpdate,
        code: {
          'check': 'fliin update --check',
          'diff': 'fliin diff',
          'update': 'fliin update',
        },
      ),
      GuideText(
        Copy.guideConflict,
        code: {
          'sidecar': 'fl_button.dart.fliin-new',
          'ext': '.fliin-new',
          'update': 'fliin update',
        },
      ),
      GuideText(
        Copy.guideUpdateSafe,
        code: {'update': 'fliin update', 'markers': '--conflict=markers'},
      ),
    ],
  ),
  (
    id: 'agents',
    title: Copy.guideAgentsTitle,
    blocks: const [
      GuideText(
        Copy.guideAgents,
        code: {
          'init': 'fliin init',
          'agents': 'AGENTS.md',
          'root': 'lib/ui/fliin',
          'claude': 'CLAUDE.md',
          'cursor': '.cursor/',
          'codex': '.codex/',
        },
      ),
      GuideCode('fliin init --agent claude,cursor\nfliin agents --agent codex'),
      GuideText(
        Copy.guideAgentsClients,
        code: {
          'clients': 'claude, cursor, gemini, codex, vscode, android-studio',
          'none': '--agent none',
          'init': 'fliin init',
        },
      ),
      GuideText(
        Copy.guideMcp,
        code: {
          'mcp': 'fliin mcp',
          'search': 'search_items',
          'get': 'get_item',
          'select': 'request_selection',
        },
      ),
      GuideText(
        Copy.guideLlms,
        links: {'llms': GuideLink('llms.txt', code: 'llms.txt')},
      ),
    ],
  ),
  (
    id: 'pro',
    title: Copy.guideProTitle,
    blocks: const [
      GuideText(
        Copy.guideProBody,
        links: {'pro': GuideLink('pro/', label: Copy.guideProTitle)},
      ),
      GuideCode('fliin login\nfliin add account-settings'),
      GuideText(
        Copy.guideProKey,
        code: {
          'login': 'fliin login',
          'path': '~/.config/fliin/credentials.json',
          'windows': r'%APPDATA%\fliin\',
          'env': 'FLIIN_LICENSE_KEY',
          'status': 'fliin status',
          'logout': 'fliin logout',
        },
      ),
      GuideText(
        Copy.guideProWithout,
        code: {'add': 'fliin add', 'update': 'fliin update'},
      ),
    ],
  ),
  (
    id: 'next',
    title: Copy.guideNextTitle,
    blocks: const [
      GuideList([
        GuideText(
          Copy.guideNextComponents,
          links: {
            'components': GuideLink(
              'components/',
              label: Copy.componentsTitle,
            ),
          },
        ),
        GuideText(
          Copy.guideNextScreens,
          links: {
            'blocks': GuideLink('blocks/', label: Copy.blocksTitle),
            'pro': GuideLink('pro/', label: Copy.guideProTitle),
            'screens': GuideLink(
              'screens/',
              label: Copy.screensTitle,
            ),
          },
        ),
        GuideText(
          Copy.guideNextTheme,
          links: {
            'theme': GuideLink('theme/', label: Copy.themeTitle),
          },
        ),
      ]),
    ],
  ),
];

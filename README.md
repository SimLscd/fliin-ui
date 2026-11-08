# Fliin

Flutter components that you copy into your app and keep.

Fliin is not a package you depend on. The `fliin` command-line tool copies the source of each item into your project, under your own prefix and imports, and from then on the code is yours to read and change. Around the copy:

- **Checked on 16 variants.** `fliin verify` renders each item inside your app on iOS and Android, light and dark, text at 1.0× and 2.0×, left to right and right to left.
- **Updated without losing your edits.** `fliin update` merges each file three ways: the version you installed, your copy and the new version. A conflict goes to a `.fliin-new` file next to yours instead of breaking the build.
- **A theme from one color.** `fliin theme` adjusts the palette until every text and control pair passes WCAG AA in light and dark, or applies a preset from [fliin.dev/theme](https://fliin.dev/theme).
- **A local MCP server for your agents.** `fliin mcp` lets Claude Code, Cursor, Gemini CLI, Codex, VS Code and Android Studio search items by intent and read their API. Your code never leaves your machine.

The components depend on `package:flutter/widgets.dart` alone, so they work under `MaterialApp`, `CupertinoApp` or `WidgetsApp`.

## Quick start

You need Flutter 3.47 or later.

```sh
dart pub global activate fliin
fliin create my_app      # or fliin init in an app you already have
cd my_app
fliin add button
fliin verify button
```

Documentation, live components and the theme builder: [fliin.dev](https://fliin.dev). The CLI on pub.dev: [fliin](https://pub.dev/packages/fliin) and [fliin_schema](https://pub.dev/packages/fliin_schema).

## What is in this repository

| Folder | What it holds |
|---|---|
| `packages/fliin` | the CLI: install, theme, verify, update, the MCP server, `registry build` |
| `packages/fliin_schema` | the data model: manifests, signed index, lockfile, tokens, theme solver, three-way merge |
| `flutter/registry` | the source of the free items: `lib/core/`, `lib/components/`, `lib/icons/`, a manifest per item in `items/`, their tests and reference renders |
| `flutter/harness` | the rendering harness that `fliin verify` copies into your app |

What is not here: **Fliin Pro**, the blocks and screens sold at [fliin.dev/pro](https://fliin.dev/pro). Their code, manifests, tests and renders stay out of this repository; `flutter/registry/external_items.txt` only names the few that a free item points to. The website is not here either.

This repository is an export of the maintainer's source repository, regenerated at each release. Its history starts at the first export.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first: the SDK is pinned, and an accepted pull request is carried over to the source repository by the maintainer, then comes back here with the next export.

## License

MIT, [LICENSE](LICENSE). Some files derive from third-party work (HeroUI, the icon sets): see [NOTICE](NOTICE), [`flutter/registry/lib/LICENSE`](flutter/registry/lib/LICENSE) and [LICENSES/](LICENSES/).

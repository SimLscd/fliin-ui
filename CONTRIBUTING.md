# Contributing to Fliin

Thanks for your interest. A few things to know before you open a pull request.

## This repository is an export

Fliin is developed in a private source repository, which also holds Fliin Pro and the website. This public repository is an export of the free part, regenerated at each release; it is never edited by hand.

So a pull request here is not merged as is. When the maintainer accepts it, they carry the change over to the source repository, credit you as its author, and it comes back here with the next export. Small, focused pull requests are the easiest to carry over. For anything larger than a fix, open an issue first.

## Set up

The repository pins its Flutter SDK, 3.47.7, so that analysis, formatting and golden renders are the same everywhere. Once per clone:

```sh
git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git .tooling/flutter-3.47.7
source tool/env.sh    # puts the pinned SDK first on the PATH; run it in every new shell
```

Never use another Flutter on your PATH: `tool/env.sh` fails rather than fall back to it. `FLIIN_FLUTTER_ROOT` points it to an SDK elsewhere.

There are two pub workspaces, because a Flutter member would force the Flutter SDK on the whole workspace and the CLI must install with `dart pub global activate`, without Flutter:

- the root, pure Dart: `packages/fliin` (the CLI) and `packages/fliin_schema`;
- `flutter/`: `flutter/registry` (the source of the items, package `fliin_ui`, prefix `Fl`) and `flutter/harness`.

## Check your change

```sh
tool/ci.sh
```

That is the whole CI: analysis with `--fatal-infos`, the registry lints, the generated files, and the tests of both workspaces. The GitHub workflow only calls this script. Tests run per package (`cd packages/fliin && dart test`); tests that create a Flutter app are tagged `slow`.

Golden renders are compared on macOS only; elsewhere the comparison is skipped. Never update goldens (`flutter test --update-goldens`) to make a test pass without looking at the render: a difference on macOS is a change of rendering.

## Rules

- Components under `flutter/registry/lib/` import `package:flutter/widgets.dart` and the base libraries only, never material or cupertino, and use directional types only (`EdgeInsetsDirectional`, `AlignmentDirectional`). `dart run tool/lint_registry.dart` checks it.
- No literal color, radius or font outside `flutter/registry/lib/core/tokens/`. `tokens.g.dart` is generated: edit `fliin.tokens.json`, run `dart run packages/fliin/tool/gen_tokens.dart`, commit both.
- Do not edit `harness_source.g.dart` or `verify_entries.g.dart` by hand: `dart run tool/embed_harness.dart` and `dart run packages/fliin/tool/gen_verify_entries.dart` write them.
- A published item version never changes: a fix to an item bumps its version in `flutter/registry/items/<item>.json`.
- Everything the CLI prints, and every comment or message in a file copied into an app, is in English: short sentences, the same word for the same notion (item, registry, variant, lockfile, preset, tokens).
- Tests are named for the behavior they check. Comments say why, not what.
- No new pub dependency in `flutter/registry`: its files are copied into apps that will not have it.

Some comments and test names are in French, the maintainer's language. You can write yours in English.

## License

By contributing, you agree that your contribution is licensed under the MIT License of this repository.

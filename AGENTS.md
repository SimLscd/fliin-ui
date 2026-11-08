# Notes for coding agents

Read [CONTRIBUTING.md](CONTRIBUTING.md): it holds the setup, the rules and the checks.

- `source tool/env.sh` before any `dart` or `flutter` command: the Flutter SDK is pinned to 3.47.7 under `.tooling/`.
- `tool/ci.sh` is the full check; run it before you hand back a change.
- Two pub workspaces: the root (pure Dart: `packages/fliin`, `packages/fliin_schema`) and `flutter/` (`flutter/registry`, `flutter/harness`). Run tests from each package's folder.
- `flutter/registry/lib/` imports `package:flutter/widgets.dart` only, no literal color, radius or font outside `core/tokens/`, directional types only.
- Generated files are never edited by hand: `tokens.g.dart` (`packages/fliin/tool/gen_tokens.dart`), `harness_source.g.dart` (`tool/embed_harness.dart`), `verify_entries.g.dart` (`packages/fliin/tool/gen_verify_entries.dart`).
- Never update goldens to make a test pass without looking at the render.
- This repository is an export of a private source repository: Fliin Pro is not here, and nothing should depend on it.

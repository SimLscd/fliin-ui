#!/usr/bin/env bash
# The CI of this repository: .github/workflows/ci.yml only calls this script. Run it before opening a pull request.
set -euo pipefail
source "$(dirname "$0")/heavy.sh"
cd "$(dirname "$0")/.."
source tool/env.sh
echo "== SDK"; dart --version; flutter --version | head -1
echo "== workspace A"
dart pub get
dart analyze --fatal-infos
echo "== registry lints and generated files"
dart run tool/lint_registry.dart
dart run tool/embed_harness.dart --check
dart run packages/fliin/tool/gen_tokens.dart --check
dart run packages/fliin/tool/gen_verify_entries.dart --check
echo "== workspace B"
(cd flutter && flutter pub get && flutter analyze --fatal-infos)
for p in packages/fliin_schema packages/fliin; do
  echo "== $p"; (cd "$p" && dart test -j "$FLIIN_TEST_JOBS")
done
for p in flutter/registry flutter/harness; do
  echo "== $p"; (cd "$p" && flutter test --concurrency="$FLIIN_TEST_JOBS")
done
[ "$(uname)" = Darwin ] || echo "golden comparisons skipped outside macOS: the references are macOS renders"
echo "== OK"

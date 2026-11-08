#!/usr/bin/env bash
# The CI of this repository: .github/workflows/ci.yml only calls this script. Run it before opening a pull request.
#
#   tool/ci.sh                    everything, one lane after the other
#   tool/ci.sh checks|cli|flutter   one lane, one CI job
#
# cli and flutter run shard FLIIN_SHARD_INDEX of FLIIN_SHARD_TOTAL (default 0 of 1, everything): the test files
# tool/ci_shard.dart gives it, split by file from the timings in tool/ci_weights.tsv.
set -euo pipefail
source "$(dirname "$0")/heavy.sh"
cd "$(dirname "$0")/.."
source tool/env.sh
lane="${1:-all}"
case "$lane" in
  all | checks | cli | flutter) ;;
  *) echo "usage: tool/ci.sh [checks|cli|flutter]" >&2; exit 64 ;;
esac
shard_index="${FLIIN_SHARD_INDEX:-0}"
shard_total="${FLIIN_SHARD_TOTAL:-1}"

checks() {
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
}

# Runs `$1 test <options>` in each of the following packages, on the test files of this shard.
run_shard() {
  local tool="$1" options="$2"; shift 2
  local files package mine
  files="$(dart tool/ci_shard.dart "$shard_index" "$shard_total" "$@")"
  echo "== shard $shard_index of $shard_total: $(grep -c . <<< "$files" || true) test files"
  for package in "$@"; do
    mine="$(awk -v p="$package" '$1 == p && NF == 2 { print $2 }' <<< "$files")"
    # shellcheck disable=SC2086 # one option and paths without spaces, split on purpose
    [ -z "$mine" ] || (cd "$package" && "$tool" test $options $mine)
    # a part of a split file, alone in its `test`
    while read -r _ path part parts; do
      (cd "$package" && "$tool" test $options --total-shards "$parts" --shard-index "$part" "$path")
    done < <(awk -v p="$package" '$1 == p && NF == 4' <<< "$files")
  done
}
cli_tests() { run_shard dart "-j $FLIIN_TEST_JOBS" packages/fliin_schema packages/fliin; }
flutter_tests() { run_shard flutter "--concurrency=$FLIIN_TEST_JOBS" flutter/registry flutter/harness; }

case "$lane" in
  checks) checks ;;
  cli) dart pub get; (cd flutter && flutter pub get); cli_tests ;;
  flutter) (cd flutter && flutter pub get); flutter_tests ;;
  all) checks; cli_tests; flutter_tests ;;
esac
[ "$lane" = checks ] || [ "$(uname)" = Darwin ] ||
  echo "golden comparisons skipped outside macOS: the references are macOS renders"
echo "== OK"

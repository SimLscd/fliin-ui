# À sourcer : `source tool/env.sh`. Met le SDK Flutter épinglé du projet en tête du PATH.
FLIIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# Un worktree (un par agent, CLAUDE.md) n'a pas de .tooling/, ignoré par git : il prend celui du dépôt principal.
FLIIN_MAIN_ROOT="$(cd "$(git -C "$FLIIN_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$FLIIN_ROOT/.git")/.." && pwd)"
if [ -z "${FLIIN_FLUTTER_ROOT:-}" ] && [ ! -x "$FLIIN_ROOT/.tooling/flutter-3.47.7/bin/flutter" ]; then
  export FLIIN_FLUTTER_ROOT="$FLIIN_MAIN_ROOT/.tooling/flutter-3.47.7"
fi
export FLIIN_FLUTTER_ROOT="${FLIIN_FLUTTER_ROOT:-$FLIIN_ROOT/.tooling/flutter-3.47.7}"
if [ ! -x "$FLIIN_FLUTTER_ROOT/bin/flutter" ]; then
  echo "tool/env.sh : SDK Flutter épinglé absent de $FLIIN_FLUTTER_ROOT. Pour l'installer :" >&2
  echo "  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git \"$FLIIN_FLUTTER_ROOT\"" >&2
  return 1 2>/dev/null || exit 1
fi
export PATH="$FLIIN_FLUTTER_ROOT/bin:$PATH"
# T3 Code envoie un GET et une poignée de main TLS à chaque port qu'ouvre un processus portant
# T3CODE_THREAD_ID, une seconde après l'ouverture : flutter_tester les prend pour la connexion de
# Flutter et le test ne se charge pas (« Invalid WebSocket upgrade request »). Sans la variable, aucune sonde.
unset T3CODE_THREAD_ID

#!/usr/bin/env bash
# Lance une commande sous le verrou machine de heavy.sh, à priorité basse : tests ciblés, check.dart,
# tout ce qui charge la machine hors de ci.sh et slice.sh. Elle attend que le script lourd en cours finisse.
#   tool/locked.sh flutter test --concurrency=2 test/button_test.dart
set -euo pipefail
[ "$#" -gt 0 ] || { echo "usage : tool/locked.sh <commande> [arguments…]" >&2; exit 2; }
source "$(dirname "$0")/heavy.sh"
exec "$@"

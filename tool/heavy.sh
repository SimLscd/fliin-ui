# À sourcer en tête des scripts lourds (ci.sh, slice.sh, locked.sh), avant leur `cd` : `source "$(dirname "$0")/heavy.sh"`.
# En local, un seul de ces scripts tourne à la fois sur la machine (verrou), à priorité basse, et les
# tests bornent leurs processus parallèles : chaque flutter_tester pèse plusieurs centaines de Mo, et un
# par cœur saturait la mémoire. Sous macOS, `taskpolicy -c utility` plafonne leur qualité de service, et
# celle de leurs enfants, à « utility » : le système fait passer avant eux le travail de l'utilisateur sur
# les cœurs rapides, sans les brider sur une machine libre. `-b` (arrière-plan) les cantonnait aux cœurs
# basse consommation et bridait le disque : lint_test passait de 24 à 111 s et des tests du CLI
# dépassaient leur délai de 30 s. En CI (variable CI posée par GitHub Actions), rien ne change.
unset T3CODE_THREAD_ID  # la sonde de ports de T3 Code, voir env.sh
if [ -z "${CI:-}" ] && [ -z "${FLIIN_HEAVY_LOCKED:-}" ] && command -v lockf >/dev/null; then
  export FLIIN_HEAVY_LOCKED=1
  echo "== verrou /tmp/fliin-heavy.lock (un seul ci.sh, slice.sh ou locked.sh à la fois)" >&2
  if command -v taskpolicy >/dev/null; then
    exec lockf -k /tmp/fliin-heavy.lock taskpolicy -c utility nice -n 10 "$0" "$@"
  fi
  exec lockf -k /tmp/fliin-heavy.lock nice -n 10 "$0" "$@"
fi
if [ -n "${CI:-}" ]; then
  FLIIN_TEST_JOBS="${FLIIN_TEST_JOBS:-$(getconf _NPROCESSORS_ONLN)}"
else
  # Un flutter_tester des goldens pèse jusqu'à 3,5 Go : un processus par tranche de 3,5 Go de mémoire,
  # deux cœurs laissés au reste, entre 3 et 12. Un M5 Max (18 cœurs, 36 Go) en lance 10, mesuré sans
  # saturer sur ci.sh et slice.sh ; l'ancienne machine en prenait 3.
  cores="$(getconf _NPROCESSORS_ONLN)"
  mem_gb="$(( $(sysctl -n hw.memsize 2>/dev/null || awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo) / 1073741824 ))"
  jobs=$(( mem_gb * 2 / 7 )); [ "$jobs" -gt $(( cores - 2 )) ] && jobs=$(( cores - 2 ))
  [ "$jobs" -lt 3 ] && jobs=3; [ "$jobs" -gt 12 ] && jobs=12
  FLIIN_TEST_JOBS="${FLIIN_TEST_JOBS:-$jobs}"
fi
export FLIIN_TEST_JOBS

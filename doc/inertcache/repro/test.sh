# Executable form of README.md, run by bin/proscala-test.
#
# The bug is a hang, so every compile runs under a deadline: GNU `timeout`
# (`gtimeout` where coreutils is installed with a g- prefix) kills the whole
# process group, JVM included, and exits 124 when the deadline passes.

within() { # within <seconds> <scalac args> — sets $STATUS (124: timed out)
  local secs="$1" t; shift
  t="$(command -v timeout || command -v gtimeout)" || skip "needs timeout(1) from coreutils"
  export -f scalac_cmd; export DIST STOCK_CP JAVA_CP
  echo "\$ timeout $secs scalac $*" >> "$LOG"
  set +e; OUTPUT="$("$t" "$secs" bash -c 'scalac_cmd -color:never "$@"' scalac "$@" 2>&1)"; STATUS=$?; set -e
  printf '%s\n' "$OUTPUT" >> "$LOG"
}

# Patched: ~6-8 s. Unpatched: does not finish (>180 s).
with_feature() {
  within 120 -d . repro.scala
  [ "$STATUS" = 0 ] || fail "expected to compile within 120 s (status $STATUS)"
}

without_feature() {
  within 90 -d . repro.scala
  [ "$STATUS" = 124 ] || fail "expected not to finish within 90 s (status $STATUS)"
}

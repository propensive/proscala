# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -cp "$COMPILER_CP" -d . Repro.scala
  runs '^terms 12 nodes 38$' . Repro 12
  runs '^terms 200 nodes 602$' . Repro 200
}

without_feature() {
  compiles -cp "$COMPILER_CP" -d . Repro.scala
  runs '^terms 5 nodes 17$' . Repro 5
  echo "\$ java Repro 12" >> "$LOG"
  set +e; OUTPUT="$(java -cp ".:$JAVA_CP" Repro 12 2>&1)"; STATUS=$?; set -e
  printf '%s\n' "$OUTPUT" >> "$LOG"
  [ "$STATUS" != 0 ] || fail "expected Repro 12 to overflow"
  printf '%s\n' "$OUTPUT" | grep -q 'RecursionOverflow' || fail "expected a RecursionOverflow from Repro 12"
}

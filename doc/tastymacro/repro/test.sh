# Executable form of README.md, run by bin/proscala-test.

setup() {
  mkdir -p a b
  compiles -d a Macro.scala Use.scala Other.scala
}

with_feature() {
  setup
  compiles -from-tasty -d b -classpath a a/app/Macro.tasty a/app/Use.tasty a/app/Other.tasty
  # one run: nothing was suspended
  case "$OUTPUT" in *suspended*) fail "a unit was suspended: $OUTPUT" ;; esac
}

without_feature() {
  setup
  fails_with 'Conflicting definitions' -from-tasty -Xprint-suspension -d b -classpath a a/app/Macro.tasty a/app/Use.tasty a/app/Other.tasty
  printf '%s\n' "$OUTPUT" | grep -q 'suspension triggered by macro call' || fail "expected a suspension"
}

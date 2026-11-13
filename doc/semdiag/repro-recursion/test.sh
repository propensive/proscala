# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zsemantic-diagnostics

library() { ls "$DIST"/lib/scala-library*.jar | head -1; }

with_feature() {
  compiles -cp "$COMPILER_CP" -d . Repro.scala
  # the type cannot be pickled, so it is formatted without TASTy, and that is all
  runs '^formatted: ' . Repro "$(library)" marked
}

without_feature() {
  # with the markup off (no flag), formatting a type never pickles it
  compiles -cp "$COMPILER_CP" -d . Repro.scala
  runs '^formatted: ' . Repro "$(library)" plain
}

# Executable form of README.md, run by bin/proscala-test.
#
# The bug needs a second copy of the macro's dependency on the *compiler's* own
# classpath, as an embedding host would have it. So Use.scala is compiled by
# launching the compiler directly, with hostcp/ beside its jars; the standard
# library goes on -cp explicitly rather than through -usejavacp, which would
# put hostcp/ on the compilation classpath too.
ZFLAG=-Zisolated-macros

hostc() { # hostc <scalac args> — the compiler, with hostcp/ on its own classpath
  echo "\$ java -cp hostcp:<compiler> dotty.tools.dotc.Main $*" >> "$LOG"
  set +e; OUTPUT="$(java -cp "hostcp:$JAVA_CP" dotty.tools.dotc.Main -color:never "$@" 2>&1)"; STATUS=$?; set -e
  printf '%s\n' "$OUTPUT" >> "$LOG"
  [ "$STATUS" = 0 ] || fail "expected to compile: $*"
}

prepare() {
  mkdir -p session hostcp macro out
  compiles -d session Lib.scala            # the library, as the compilation sees it
  compiles -d hostcp host/Lib.scala        # the host's copy of the same library
  compiles -cp session -d macro Macro.scala
}

with_feature() {
  prepare
  hostc $ZFLAG -cp "session:macro:$JAVA_CP" -d out Use.scala
  runs '^session$' out repro.run
}

without_feature() {
  prepare
  hostc -cp "session:macro:$JAVA_CP" -d out Use.scala
  runs '^host$' out repro.run
}

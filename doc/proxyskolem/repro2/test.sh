# Executable form of README.md, run by bin/proscala-test.
# The patch acts only in capture-checked units, so both runs enable it.

with_feature() {
  mkdir -p out
  compiles -language:experimental.captureChecking -d out minilib.scala
  compiles -language:experimental.captureChecking -classpath out -d out miniuse.scala
}

without_feature() {
  case "$SCALA_VERSION" in
    3.9.*) ;;
    *) skip "the skolem-identity mode does not reproduce on the 3.10 line (stock 3.10.0 compiles it)" ;;
  esac
  mkdir -p out
  compiles -language:experimental.captureChecking -d out minilib.scala
  fails_with 'Found: +\(\?1 : mini\.TC\.text\[Any\]\)' -language:experimental.captureChecking -classpath out -d out miniuse.scala
}

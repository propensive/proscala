# Executable form of README.md, run by bin/proscala-test.
# Always on: no -Z flag.

with_feature() {
  compiles -sourcepath sp -d . Use.scala
}

without_feature() {
  fails_with 'StaleSymbolException: stale symbol; module class compileTimeOnly' -sourcepath sp -d . Use.scala
}

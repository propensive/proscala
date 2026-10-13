# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  fails_with 'cannot subsume a read-only capture set' -d . repro.scala
}

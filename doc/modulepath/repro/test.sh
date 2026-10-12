# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala Test.scala
}

without_feature() {
  fails_with 'is not a legal path' -d . repro.scala Test.scala
}

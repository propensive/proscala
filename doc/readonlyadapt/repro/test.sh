# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -d . repro.scala
}

without_feature() {
  reports 'NoSuchElementException: key not found' -experimental -d . repro.scala
}

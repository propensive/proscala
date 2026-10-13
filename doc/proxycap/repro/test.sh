# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  fails_with 'capability `lambda` cannot flow into capture set \{\}' -d . repro.scala
}

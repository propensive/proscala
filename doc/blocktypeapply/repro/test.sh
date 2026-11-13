# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  reports 'unexpected tree for type application' -d . repro.scala
}

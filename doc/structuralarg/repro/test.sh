# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  reports 'NoSymbol.* cannot be cast to .*ClassSymbol' -d . repro.scala
}

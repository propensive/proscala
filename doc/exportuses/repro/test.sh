# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  fails_with 'in the bound of type target leaks into capture scope' -d . repro.scala
}

# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -Wconf:any:s -d . repro.scala
}

without_feature() {
  fails_with 'error overriding method text in trait Inspectable' -Wconf:any:s -d . repro.scala
}

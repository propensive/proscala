# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Required: +\$_lazy_implicit_\$[0-9]+' -language:experimental.captureChecking -d . repro.scala
}

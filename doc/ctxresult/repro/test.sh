# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Reference `x\$1` is not included in the allowed capture set' -language:experimental.captureChecking -d . repro.scala
}

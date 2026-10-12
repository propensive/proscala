# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -Ycc-new -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'capability `typeclass` cannot flow into capture set \{\}' -Ycc-new -language:experimental.captureChecking -d . repro.scala
}

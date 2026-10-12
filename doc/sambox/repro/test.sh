# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -scalajs -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Found: +Object with Source \{\.\.\.\}' -scalajs -language:experimental.captureChecking -d . repro.scala
}

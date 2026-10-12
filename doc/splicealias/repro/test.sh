# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . Macro.scala
  compiles -cp . -language:experimental.captureChecking -d . Use.scala
}

without_feature() {
  compiles -d . Macro.scala
  fails_with 'Found: +Object with TC \{\.\.\.\}' \
    -cp . -language:experimental.captureChecking -d . Use.scala
}

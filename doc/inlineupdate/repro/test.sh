# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -language:experimental.separationChecking -d . repro.scala
}

without_feature() {
  fails_with 'the access is in method [^ ]*inline\$[^ ]*, which is not an update method' -language:experimental.captureChecking -language:experimental.separationChecking -d . repro.scala
}

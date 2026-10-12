# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -Ycc-new -language:experimental.separationChecking -d . meet.scala
}

without_feature() {
  fails_with 'inherits two unrelated classifier traits' -experimental -Ycc-new -language:experimental.separationChecking -d . meet.scala
}

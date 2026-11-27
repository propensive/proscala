# Executable form of README.md, run by bin/proscala-test.

OPTIONS="-language:experimental.captureChecking -language:experimental.separationChecking"

with_feature() {
  compiles $OPTIONS -d . macro.scala
  compiles $OPTIONS -cp . -d . client.scala
}

without_feature() {
  compiles $OPTIONS -d . macro.scala
  fails_with 'is not visible from any in an enclosing function' $OPTIONS -cp . -d . client.scala
}

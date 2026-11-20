# Executable form of README.md, run by bin/proscala-test.
CC="-Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking"

with_feature() {
  compiles $CC -d . lib.scala
  compiles $CC -cp . -d . first.scala
  compiles $CC -cp . -d . client.scala
}

without_feature() {
  compiles $CC -d . lib.scala
  compiles $CC -cp . -d . first.scala
  fails_with 'Found: +lib\.Box\[Array\[Int\]\^\{any\.rd\}\]' $CC -cp . -d . client.scala
}

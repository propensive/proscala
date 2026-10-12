# Executable form of README.md, run by bin/proscala-test.
CC="-Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking -Zopaque-mutability -Zpure-iarrays"

with_feature() {
  compiles $CC -Zfrozen-pure -d . repro.scala
}

without_feature() {
  fails_with 'D\^\{any\.rd\} hides non-local this' $CC -d . repro.scala
}

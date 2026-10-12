# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zunion-captures

with_feature() {
  compiles $ZFLAG -d . repro.scala
}

without_feature() {
  fails_with 'capability `any\.rd` is not classified as trait Unscoped' -d . repro.scala
}

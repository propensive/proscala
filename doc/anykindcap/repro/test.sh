# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'of the type parameter bound (scala\.)?AnyKind' -language:experimental.captureChecking -d . repro.scala
}

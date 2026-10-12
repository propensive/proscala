# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zretains-bounds

with_feature() {
  compiles $ZFLAG -Ycc-new -language:experimental.captureChecking -experimental -d . a.scala b.scala
}

without_feature() {
  fails_with 'Illegal capture reference: +>: \(iterable' -Ycc-new -language:experimental.captureChecking -experimental -d . a.scala b.scala
}

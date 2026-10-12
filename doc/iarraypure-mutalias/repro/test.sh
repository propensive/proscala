# Executable form of README.md, run by bin/proscala-test.
# Inverted: the patched compiler rejects the write; upstream accepts it.
ZFLAG=-Zopaque-mutability

with_feature() {
  fails_with 'Required: +repro\.Buffer\[Int\]\^\{any\}' $ZFLAG -experimental -Ycc-new -language:experimental.separationChecking repro.scala
}

without_feature() {
  compiles -experimental -Ycc-new -language:experimental.separationChecking repro.scala
}

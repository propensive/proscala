# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zunboxed-pure-types

with_feature() {
  compiles $ZFLAG -language:experimental.captureChecking -d . pure-type-inline-box.scala
  compiles $ZFLAG -language:experimental.captureChecking -d . pure-tuple-typemember-box.scala
}

without_feature() {
  fails_with 'Text is a pure type, it makes no sense to add a capture set to it' \
    -language:experimental.captureChecking -d . pure-type-inline-box.scala
  fails_with 'type Form = \(Pounds, Stones\)\^.s1\}\): String has incompatible type' -language:experimental.captureChecking -d . pure-tuple-typemember-box.scala
}

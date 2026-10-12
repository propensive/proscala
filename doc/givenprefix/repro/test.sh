# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zgiven-prefixes

with_feature() {
  compiles $ZFLAG -d . lib.scala use.scala
  fails_with 'value length is not a member of minirepro\.Lst\[Int\]' $ZFLAG -d . lib.scala leak.scala
}

without_feature() {
  fails_with 'Required: +minirepro\.Lst\[Int\]' -d . lib.scala use.scala
  compiles -d . lib.scala leak.scala
}

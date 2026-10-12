# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zalias-captures

with_feature() {
  compiles $ZFLAG -d . defs.scala
  compiles $ZFLAG -cp . -d . lib.scala
  compiles $ZFLAG -cp . -d . client.scala
}

without_feature() {
  compiles -d . defs.scala
  compiles -cp . -d . lib.scala
  fails_with 'is not visible from any in type raises' -cp . -d . client.scala
}

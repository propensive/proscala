# Executable form of README.md, run by bin/proscala-test.

ZFLAG=-Zcheck-inlined-closures

with_feature() {
  compiles $ZFLAG -d . Lib_1.scala
  fails_with 'outlives its scope' $ZFLAG -cp . -d . Test_2.scala
}

without_feature() {
  compiles -d . Lib_1.scala
  compiles -cp . -d . Test_2.scala
}

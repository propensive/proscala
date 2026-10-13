# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . Lib_1.scala
  compiles -cp . -d . Test_2.scala
}

without_feature() {
  compiles -d . Lib_1.scala
  fails_with 'cannot subsume a read-only capture set' -cp . -d . Test_2.scala
}

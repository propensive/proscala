# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -Yexplicit-nulls -Ycc-new -d . repro.scala
}

without_feature() {
  fails_with 'Cannot create ClassBType for special class symbol Null' -Yexplicit-nulls -Ycc-new -d . repro.scala
}

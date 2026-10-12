# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -Yexplicit-nulls -Yno-flexible-types -d . repro.scala
}

without_feature() {
  fails_with 'repro\.scala:22:' -Yexplicit-nulls -Yno-flexible-types -d . repro.scala
}

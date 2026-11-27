# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -Ycc-new -experimental -d . repro.scala
}

without_feature() {
  fails_with 'does not conform to upper bound Coll\[Box' -Ycc-new -experimental -d . repro.scala
}

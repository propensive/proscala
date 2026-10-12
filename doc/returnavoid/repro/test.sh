# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -d . repro.scala
}

without_feature() {
  fails_with 'Found: +(scala\.quoted\.)?Expr\[[^]]*Html\{type Topic\}\]' -experimental -d . repro.scala
}

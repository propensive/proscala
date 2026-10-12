# Executable form of README.md, run by bin/proscala-test.
# Always on: no -Z flag. Both files must be compiled together, so that Use.scala
# is suspended on the not-yet-compiled macro and re-run.

with_feature() {
  compiles -d . Macro.scala Use.scala
}

without_feature() {
  fails_with 'denotation trait [A-Za-z]+ invalid in run [0-9]+' -d . Macro.scala Use.scala
}

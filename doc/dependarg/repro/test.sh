# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  fails_with 'Required: Multiplicable\{type Self = Int; type Operand = Int\}#Result =:= Int' -language:experimental.captureChecking -d . repro.scala
}

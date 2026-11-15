# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  fails_with 'Required: \(P\.k1 : Kind\^\{\}\) \| \(P\.k2 : Kind\^\{\}\)' -d . repro.scala
}

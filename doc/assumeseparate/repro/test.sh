# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -d . repro.scala
}

without_feature() {
  # 3.9 accepts this form (see repro-element for one it rejects)
  case "$SCALA_VERSION" in 3.9*) skip ;; esac
  fails_with 'cannot subsume a read-only capture set' -d . repro.scala
}

# Executable form of README.md, run by bin/proscala-test.
# Always on: no -Z flag.

with_feature() {
  compiles -d . parts.scala
}

without_feature() {
  fails_with 'wildApprox. failed to remove uninstantiated value' -d . parts.scala
}

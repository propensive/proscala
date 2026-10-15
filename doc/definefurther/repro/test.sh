# Executable form of README.md, run by bin/proscala-test.
# Always on: no -Z flag.

with_feature() {
  compiles -d . read.scala
}

without_feature() {
  fails_with 'Recursion limit exceeded' -d . read.scala
}

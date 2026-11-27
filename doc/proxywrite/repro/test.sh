# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -d . repro.scala
}

without_feature() {
  fails_with 'Cannot call update method update of \(arr : p\.Arr\[String\]\^\) & \$proxy1\.Arr\[String\]' -experimental -d . repro.scala
}

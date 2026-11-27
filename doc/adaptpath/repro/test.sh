# Executable form of README.md, run by bin/proscala-test.

with_feature() {
  compiles -experimental -d . repro.scala
}

without_feature() {
  fails_with 'Found: +\(Parsing & Gathering\)#Self' -experimental -d . repro.scala
}

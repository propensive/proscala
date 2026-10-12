# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zpure-iarrays

with_feature() {
  compiles $ZFLAG -language:experimental.separationChecking -Ycc-new repro.scala
}

without_feature() {
  fails_with 'Found: +IArray\[Int\]\^\{any\}' -language:experimental.separationChecking -Ycc-new repro.scala
}

# Executable form of README.md, run by bin/proscala-test.
# A regression test for an early version of the patch, which crashed here
# ("assertion failed: param = T"); the fixed compiler reports two clean errors.
# Stock Scala has no Spreadable, so there is no upstream behaviour to compare.
ZFLAG=-Zspreadable-varargs

with_feature() {
  fails_with 'Found: +\(names : lib\.Lst\[' $ZFLAG -d . lst.scala macro.scala
  # a crash would also fail, but must not be what fails
  if printf '%s\n' "$OUTPUT" | grep -q 'AssertionError'; then fail "compiler crashed"; fi
}

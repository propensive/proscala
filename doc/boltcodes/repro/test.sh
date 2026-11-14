# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zbolt-codes

with_feature() {
  fails_with '\[↯/p\.1\.7\] Type Mismatch Error' $ZFLAG -d . plain.scala
  reports '\[↯/p\.7\.40\] Error' $ZFLAG -d . plain.scala
  # a message given as a plain string, known by its text
  reports '\[↯/p\.11\.21\] Warning' $ZFLAG -d . stored.scala
  compiles $ZFLAG -d . macros.scala
  fails_with '\[↯/p\.2\.2/s\.87\.1\.2\] Error' $ZFLAG -cp . -d . coded.scala
  # the macro's code is taken out of its message
  if printf '%s\n' "$OUTPUT" | grep -q '↯/s'; then fail "the macro's code was left in its message"; fi
  fails_with '\[↯/p\.2\.2\] Error' $ZFLAG -cp . -d . uncoded.scala
}

without_feature() {
  fails_with '\[E007\] Type Mismatch Error' -d . plain.scala
  reports '^-- Error: plain.scala:2' -d . plain.scala
  compiles -d . macros.scala
  fails_with '\[↯/s\.87\.1\.2\] the document is not valid' -cp . -d . coded.scala
  if printf '%s\n' "$OUTPUT" | grep -q '↯/p'; then fail "a bolt code without the flag"; fi
}

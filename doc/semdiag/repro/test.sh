# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zsemantic-diagnostics

with_feature() {
  fails_with '<diagnostic severity="error" kind="TypeMismatch"' $ZFLAG -d . local.scala
  reports '<type tasty="[A-Za-z0-9+/=]+">' $ZFLAG -d . local.scala
  reports '<placeholder id="[0-9]+" kind="local-term" name="b2"' $ZFLAG -d . local.scala
}

without_feature() {
  fails_with '\[E007\] Type Mismatch Error' -d . local.scala
  # and nothing structured
  _scalac -d . local.scala
  if printf '%s\n' "$OUTPUT" | grep -q '<diagnostic'; then fail "XML output without the flag"; fi
}

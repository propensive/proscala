# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zsemantic-diagnostics

with_feature() {
  fails_with '<diagnostic severity="error" kind="TypeMismatch"' $ZFLAG -d . local.scala
  reports '<type tasty="[A-Za-z0-9+/=]+">' $ZFLAG -d . local.scala
  reports '<placeholder id="[0-9]+" kind="local-term" name="b2"' $ZFLAG -d . local.scala
  # a macro's own markup: a tree, as elements, around the text that draws it
  compiles -d . TreeMacro_1.scala
  fails_with '<tree><node role="resolving" name="Fairy"> ■ resolving Fairy' $ZFLAG -cp . -d . TreeUse_2.scala
  reports ' └─<node role="propose" name="puck"> ▸ propose puck</node></node></tree>' $ZFLAG -cp . -d . TreeUse_2.scala
}

without_feature() {
  fails_with '\[E007\] Type Mismatch Error' -d . local.scala
  # and nothing structured
  _scalac -d . local.scala
  if printf '%s\n' "$OUTPUT" | grep -q '<diagnostic'; then fail "XML output without the flag"; fi
  # the macro's tree is then its text alone, with no marker left in it
  compiles -d . TreeMacro_1.scala
  fails_with ' └─ ▸ propose puck' -cp . -d . TreeUse_2.scala
  if printf '%s\n' "$OUTPUT" | LC_ALL=C grep -q "$(printf '\356\200[\200-\203]')"; then fail "markers in plain output"; fi
}

# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zdiagnostic-givens

with_feature() {
  compiles -d . Macro_1.scala
  fails_with 'CUSTOM DIAGNOSTIC: Missing' $ZFLAG -cp . -d . Test_2.scala
  compiles $ZFLAG -cp . -d . Pos_2.scala
  fails_with 'CUSTOM DIAGNOSTIC: scala\.util\.NotGiven\[Present\]' $ZFLAG -cp . -d . NotGiven_2.scala
}

without_feature() {
  # Stock Scala has no @internal.diagnostic (it lives in proscala-library), so
  # supply a stand-in for it. It sits on -cp, which comes after the compiler's
  # own classpath, so Proscala still resolves its real annotation.
  mkdir -p stub
  printf '%s\n' 'package scala.annotation.internal' \
    'final class diagnostic extends scala.annotation.StaticAnnotation' > stub/diagnostic.scala
  compiles -d stub stub/diagnostic.scala
  compiles -cp stub -d . Macro_1.scala
  fails_with 'annotation message' -cp .:stub -d . Test_2.scala
  compiles -cp .:stub -d . NotGiven_2.scala
}

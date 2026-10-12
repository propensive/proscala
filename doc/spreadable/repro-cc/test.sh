# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zspreadable-varargs

with_feature() {
  compiles $ZFLAG -experimental -Ycc-new -language:experimental.captureChecking -d . repro.scala
}

without_feature() {
  # Upstream has no scala.Spreadable (it lives in proscala-library), so supply a
  # stand-in on -cp; that comes after the compiler's own classpath, so Proscala
  # still resolves its real one. Either way the splice is rejected.
  mkdir -p stub
  printf '%s\n' 'package scala' \
    'trait Spreadable[T]:' '  type Out' '  def spread(value: T): Out' > stub/Spreadable.scala
  compiles -d stub stub/Spreadable.scala
  fails_with 'Required: +Seq\[(splicecc\.)?Node\] \| Array\[\? <: (splicecc\.)?Node\]' \
    -experimental -Ycc-new -language:experimental.captureChecking -cp stub -d . repro.scala
}

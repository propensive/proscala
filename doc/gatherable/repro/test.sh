# Executable form of README.md, run by bin/proscala-test.
ZFLAG=-Zgatherable-varargs

with_feature() {
  compiles $ZFLAG -experimental -d . defs.scala use.scala
  runs 'total 6; letters has 2; 9' . Test
  # a caller needs neither the flag nor an instance: the signature is unchanged
  mkdir -p caller
  printf '%s\n' '@main def Caller = println(s"caller ${total(1, 2)}")' > caller/caller.scala
  compiles -experimental -cp . -d caller caller/caller.scala
  runs 'caller 3' caller:. Caller
  # with no instance in scope, a method with a repeated parameter is an error
  fails_with 'no given scala\.Gatherable\[Int\] is in scope' $ZFLAG -experimental -d . missing.scala
}

without_feature() {
  # Upstream has no scala.Gatherable (it lives in proscala-library), so supply a
  # stand-in on -cp; that comes after the compiler's own classpath, so Proscala
  # still resolves its real one. Either way `xs` is a `Seq` in the body.
  mkdir -p stub
  printf '%s\n' 'package scala' \
    'trait Gatherable[T]:' '  type Out' '  def gather(elements: Seq[T]): Out' > stub/Gatherable.scala
  compiles -d stub stub/Gatherable.scala
  fails_with 'value total is not a member of Seq\[Int\]' -experimental -cp stub -d . defs.scala use.scala
  compiles -experimental -cp stub -d . missing.scala
}

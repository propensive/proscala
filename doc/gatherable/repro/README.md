# Reproduction: a repeated parameter received as a `Series`

`defs.scala` declares `Series`, an opaque alias over `Vector` with its own
extension methods, and a `Gatherable` instance naming it as the type repeated
parameters are received as. `use.scala` defines two methods with repeated
parameters whose bodies use `Series`'s API on them directly.

## To reproduce

    scalac -Zgatherable-varargs -experimental -d out defs.scala use.scala
    scala -cp out Test

prints

    total 6; letters has 2; 9

The last call splices an ordinary `Seq` (`total(Seq(4, 5)*)`): callers are
unaffected, and need neither the flag nor an instance.

Without `-Zgatherable-varargs` the parameter is a `Seq` in the body, as
upstream has it, and `use.scala` is rejected:

    value total is not a member of Seq[Int]

`missing.scala` is a method with a repeated parameter where no instance is in
scope. With the flag it is an error:

    -Zgatherable-varargs: no given scala.Gatherable[Int] is in scope to receive this repeated parameter

and without it, it compiles as usual.

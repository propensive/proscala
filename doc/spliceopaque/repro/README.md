# Reproduction: crash on an erroneous splice argument

Reproduces the "assertion failed: param = T" compiler crash fixed by the
"Keep the opaque-splice fallback retype speculative" commit on the
spliceopaque patch branches.

`macro.scala` passes an opaque `Lst` where `Varargs` requires a plain
`Seq[Expr[String]]` — a genuine type error — at a `xs*` splice position
inside a quote, under an overloaded callee (`IArray.apply`). The patch's
original fallback retyped the failing argument in the enclosing context,
leaking duplicate type variables and quote-hole registrations into the
typer state used by overload resolution.

## To reproduce

Compile both files together with default flags:

    scalac -d out lst.scala macro.scala

A compiler carrying the first version of the spliceopaque patch (releases
3.8.4-p5 / 3.9.0-RC1-p5) crashes:

    java.lang.AssertionError: assertion failed: param = T
      at dotty.tools.dotc.core.ConstraintHandling.approximation(ConstraintHandling.scala:588)
      at ...
      at dotty.tools.dotc.typer.ProtoTypes$FunProto.typedArgs(ProtoTypes.scala:543)
      at dotty.tools.dotc.typer.Applications.resolveOverloaded1(...)

## Expected behaviour (fixed compiler, and stock upstream)

Two clean errors: a type mismatch at `Varargs[String](names)` (`Lst[...]`
is not a `Seq[...]`) and the consequent failure of the `IArray.apply`
overload resolution.

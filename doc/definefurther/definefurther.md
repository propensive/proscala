# Treat an endless instantiation as no further definition in canDefineFurther

Stops a speculative attempt to instantiate more type variables, made while adapting a tree to its expected type, from turning a recursion that never ends into a fatal error.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

When Typer adapts a tree to its expected type and the adaptation fails, it does
not give up at once. It asks `Inferencing.canDefineFurther` whether
instantiating more of the tree's type variables would change anything, and if
so it instantiates them and tries again. It asks the same before giving up on
selecting a member of a qualifier, or on an ambiguous extension search:

```scala
def canDefineFurther(tp: Type)(using Context): Boolean =
  val prevConstraint = ctx.typerState.constraint
  isFullyDefined(tp, force = ForceDegree.failBottom)
  && (ctx.typerState.constraint ne prevConstraint)
```

It is speculative: the answer only decides whether another attempt is worth
making. If no further definition is possible, the adapter reports the failure it
already has, and an implicit search treats that as one candidate failing and
moves on to the next.

Instantiating a type variable can recurse, through the subtype checks that
adjust the constraint, and for some types the recursion has no end. Scala 3.10
bounds such recursion with fuel (scala/scala3#25937, `-Xmax-fuel`): when the
fuel runs out, the compiler throws `RecursionOverflow` and reports "Recursion
limit exceeded" as an error. Thrown from inside `canDefineFurther`, it ends the
whole attempt, though the step only had to answer whether one more attempt was
worth making.

## Reproducing it

Soundness reaches it in the tests of locomotion and embarcadero, where the first
`read[X in Protobuf]` of a compilation unit resolves the `Protobuf` decoding
given for `X`. One candidate's adaptation fails, `canDefineFurther` is asked
about it, and instantiating the result type's variables recurses without end.
Scala 3.10.0 reports:

```
Recursion limit exceeded.
Maybe there is an illegal cyclic reference?
```

at `locomotion_test.scala:169` and `embarcadero_test.scala:748`, where 3.9
compiles both modules. There is no self-contained reproduction yet
(`repro/FIXME.md`).

## The solution

`canDefineFurther` answers the question it was asked: if instantiating the
type's variables does not terminate, the type cannot be defined further.

```scala
def canDefineFurther(tp: Type)(using Context): Boolean =
  val prevConstraint = ctx.typerState.constraint
  // A speculative step (it lets the adapter retry after instantiating more type
  // variables): if instantiating one recurses without end, the answer is that the
  // type cannot be defined further, not a fatal error.
  try
    isFullyDefined(tp, force = ForceDegree.failBottom)
    && (ctx.typerState.constraint ne prevConstraint)
  catch case _: RecursionOverflow => false
```

The adapter then reports its ordinary failure, if the tree really does not fit,
and an implicit search goes on to its other candidates. With the patch, both
Soundness modules compile.

Only `RecursionOverflow` is caught, and only around this speculative step: a
recursion that runs out of fuel anywhere else is still reported, as is any
other error raised while instantiating.

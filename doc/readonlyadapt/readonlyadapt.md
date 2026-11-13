# Keep the type arguments a read-only adaptation does not improve

Stops the capture checker crashing with `NoSuchElementException` when a mutable reference is adapted to a read-only expected type through a constructor that fixes only some of its type arguments.

## Context

Under capture checking a class that extends `caps.Mutable` distinguishes its
`update` methods, which write, from the rest, which only read. A reference to
such an object can be held *read-only*: `Ref^{r.rd}` may call `get` but not
`set`. Since read-only is weaker than full access, a full reference can be used
wherever a read-only one is expected:

```scala
class Ref extends Mutable:
  private var x: Int = 0
  def get: Int = x
  update def set(y: Int): Unit = x = y

def view(r: Ref^): Ref^{r.rd} = r
```

The capture checker makes this work by *adapting* the actual type towards the
expected one before comparing them (`Mutability.adaptReadOnlyToExpected`): where
the expected type asks for a read-only capability and the actual type holds the
full one, the actual type is rewritten to the read-only form. For an applied
type it does so argument by argument.

When the two types are applications of *different* classes — `Right[…]` given
where `Either[…]` is expected — the arguments do not line up directly. The
checker lifts the actual type to its base type for the expected class
(`Right[Nothing, Ref^{r}]` as an `Either[Nothing, Ref^{r}]`), improves that
base type's arguments against the expected ones, and then carries each
improvement back to the original argument it came from.

That last step is where it failed. The improvements were collected as pairs,
turned into a map, and the map was applied to *every* original argument as if
it were a total function:

```scala
if updates.nonEmpty then AppliedType(atycon, aargs.map(updates.toMap))
```

A Scala `Map` used as a function throws for a key it does not hold. Whenever
at least one argument was improved and another was not, the unimproved one was
looked up, and the exception escaped the compiler.

## Reproduction

[`repro/`](repro/) — one file, with `-experimental`:

```scala
def right(r: Ref^): Either[Int, Ref^{r.rd}] = Right(r)
```

```
unhandled exception while running cc on repro.scala
java.util.NoSuchElementException: key not found: TypeRef(…,Nothing)
    at dotty.tools.dotc.cc.Mutability$.adaptReadOnlyToExpected(Mutability.scala:232)
```

`Right(r)` is a `Right[Nothing, Ref^{r}]`. Against `Either[Int, Ref^{r.rd}]`
its second argument is improved to `Ref^{r.rd}`; its first, `Nothing`, needs
nothing and has no entry in the map. `Left(r)` fails the same way with the
arguments the other way round. The crash is in every upstream tried: 3.9.0,
3.10.1 and `main`.

Soundness met it with the arguments the other way round: a `Left(x)`, which is
a `Left[Int, Nothing]`, given where an `Either[Int, Data]` was expected and
`Data` was a mutable-classified `Array[Byte]^{}`.

## Solution

An argument without an improvement stays as it is (`cc/Mutability.scala`):

```scala
if updates.nonEmpty then
  // only the improved arguments have an entry; the others stay as they are
  val improved = updates.toMap
  AppliedType(atycon, aargs.map(aarg => improved.getOrElse(aarg, aarg)))
else actual
```

Nothing else changes: the improved arguments are exactly those the map already
produced, and a type none of whose arguments is improved was already returned
unchanged by the `else`. The fix is always on, since it only turns a crash into
the result the code was written to give.

`tests/pos-custom-args/captures/mutability-partial-improve.scala` covers
`Right`, `Left` and a conditional that produces both.

## Upstream

This is upstream's code and upstream's bug; worth reporting with the
reproduction, as the fix is one line.

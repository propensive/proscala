# Treat an anonymous class instance's ascription as inferred

Keeps the capture checker from reading the type Typer ascribes to an anonymous class instance as a declared type when the instance reaches it from TASTy, in an inline method's body.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

An expression `new Stream { ... }` defines a local class, and its value cannot
have that class as its type outside the block that defines it. Typer avoids the
class by ascribing the instance with the type of its parents, so the expression
becomes

```scala
{
  final class $anon() extends Object(), Stream { ... }
  new $anon(): Stream
}
```

The ascription's type tree is an `InferredTypeTree`, and the capture checker
treats it as one: in Setup it gets a capture set variable, which the instance's
own captures then fill.

TASTy does not record whether a type tree was inferred. When the expression is
part of an inline method's body, the inline site reads it back from TASTy with
the ascription as a plain `TypeTree`, and Setup maps it as a declared type. On
3.10, a declared stateful type written without a capture set means a read-only
reference: `Stream` becomes `Stream^{any.rd}`. An instance that is returned as
an exclusive `Stream^` then fails, but only at inline sites in other
compilation units.

## Reproducing it

```scala
// Lib_1.scala
trait Stream extends caps.ExclusiveCapability, caps.Stateful:
  def start: Int
  update def skip(count: Int): Unit

trait Backend:
  def source(): Stream^

object Backends:
  inline given backend: Backend = new Backend:
    private def readStream(start: Int): Stream^ =
      new Stream:
        private var start0: Int = start
        def start: Int = start0
        update def skip(count: Int): Unit = start0 += count

    def source(): Stream^ = readStream(1)
```

```scala
// Test_2.scala
import Backends.backend

def test = summon[Backend]
```

`Lib_1.scala` compiles, and so do both files compiled in one run. Compiled
against `Lib_1.scala`'s output, `Test_2.scala` fails on Scala 3.10.0:

```
Found:    Stream^{any.rd}
Required: Stream^{any²}

Note that {any²} is an exclusive capture set of the stateful type Stream^{any²},
it cannot subsume a read-only capture set of the stateful type Stream^{any.rd}.
```

3.9 accepts it. Soundness's WASI socket backend, `coaxial.socketBackends.wasiSockets`,
is exactly this shape: an `inline given` (so that the WIT calls in it expand
where the WASI facades are on the classpath) whose `readStream` builds an
anonymous `Stream[Data]`. Every program that summons a `Socket.Backend` with it
in scope failed to compile.

## The solution

In Setup's traversal, an ascription whose expression is the instantiation of an
anonymous class is transformed as an inferred type, whether or not it arrived as
an `InferredTypeTree`:

```scala
case tree @ Typed(expr, tpt: TypeTree) if isAnonymousInstance(expr) =>
  traverse(expr)
  transformTT(tpt, NoSymbol, boxed = false, inferred = true)
```

where `isAnonymousInstance` recognises `new $anon(...)`: an application of the
constructor of a `New` whose class is anonymous. No source can write that
expression, since an anonymous class has no name to write, so every such
ascription is one Typer made. `transformTT` takes the new `inferred` flag
alongside the tree's own `isInferred`. An ascription a programmer writes around
the whole block, `(new Stream { ... }): Stream`, is not affected: its
expression is the block, not the instantiation.

The patch's test is `pos-custom-args/captures/anonascribe`, compiled in two
runs, and the outcome of every test in `tests/{neg,pos}-custom-args/captures` is
unchanged.

# Do not force completion when filtering prunable inline methods

Stops the new inline-traits pruning phase from completing every declaration of
every class it transforms, which crashed compilation-suspension re-runs with a
`StaleSymbolException`.

## Context

Upstream #26156 ("Inline Traits & Specialized Traits", `3adfcbd32a`, after
3.10.0-dev-p13's base) added `PruneInlinedMethods`, an `InfoTransformer` that
removes already-inlined specialized methods from class scopes. The phase has no
feature gate: its `transformInfo` filters the declarations of *every* class
denotation brought forward past it, and the filter predicate
(`Specialization.isSpecializedMethod`) begins with symbol-flag tests. Reading a
symbol's flags completes it, and merely touching `sym.denot` replays the
intervening info transforms — so the phase turned every denotation advance into
a completion cascade at whatever point it happened to occur.

That is harmless for symbols whose completers resolve against the current run.
But a symbol loaded from a `-sourcepath` file is only entered, never
type-checked, so its members keep their `Namer` completers, and the symbols
the compiler loads for itself while initialising belong to the run before the
first compilation run. When the pruning phase forces such a completer — a
member's signature, a class's parent application, an implicit search walking
imported scopes — it can resolve a name to one of those earlier symbols, whose
denotation has no counterpart in the current run, and `bringForward` fails:

    StaleSymbolException: stale symbol; module class compileTimeOnly$ …
    defined in Period(1.1-2), is referred to in run Period(2.1)

## How to reproduce

`repro/` shows it in four short files. A unit with an inline call names a
class, `Foo`, that comes from a `-sourcepath` directory which also shadows the
standard library's `scala.Unit` and `scala.annotation.compileTimeOnly`:

```scala
// sp/lib/Foo.scala
import scala.annotation.compileTimeOnly
class Foo[T](x: T)(implicit num: Integral[T])
object Foo:
  class Inclusive[T](x: T)(implicit num: Integral[T]) extends Foo(x)
```

```scala
// Use.scala
inline def one: Int = 1
object Use:
  val a: Int = one
  val foo: Foo[Int] = ???
```

```
scalac -sourcepath sp -d . Use.scala
```

A sourcepath file is parsed and entered, not type-checked, so `Inclusive`
still has its `Namer` completer when erasure advances `Foo`'s companion past
`pruneInlinedMethods`; `isDeletable` reads its flags, completing it, and the
implicit search for its parent's `Integral[T]` walks the import, whose
`compileTimeOnly` is the symbol the compiler loaded for itself while
initialising, before the run began. Its module class cannot be brought
forward, and stock 3.10.0 crashes with the `StaleSymbolException` above. The
patch compiles it.

The in-tree form was the distribution build's Scala.js scalalib overlay step,
which compiles `library-js-aux/src/scala/runtime/*.scala` with
`-sourcepath library/src -scalajs`, where the stdlib itself comes from the
sourcepath. On an unpatched tree at `9542a5f686`, `make` fails at exactly this
step while compiling `BoxesRunTime.scala` during erasure; the same invocation
compiles cleanly under `-Yskip:pruneInlinedMethods,pruneInlineTraits`.
Upstream's later gate on `needsInlining` (#26842, and its backport in
3.10.0-RC2) spares that build today, which is why the stream's own build no
longer shows it, but any unit that inlines still runs the phase.

## Solution

`isDeletable` now pre-filters on the **last known denotation, without
advancing it**:

```scala
val lastDenot = sym.lastKnownDenotation
lastDenot.isCompleted
&& lastDenot.flagsUNSAFE.isAllOf(InlineMethod)
&& !lastDenot.flagsUNSAFE.is(JavaDefined)
&& Specialization.isSpecializedMethod(sym)
```

The justification: a symbol that is still uncompleted at this phase, or whose
flags do not spell an inline method, cannot be a specialized inline method
awaiting pruning — those are created *and completed* earlier in the same run by
the specialization machinery. Only genuine candidates reach
`Specialization.isSpecializedMethod`, whose deeper checks (type-parameter
inspection) are then safe because the symbol is already completed. The
inline-traits feature itself is unaffected: `transformTemplate` calls the same
predicate on current-unit tree symbols, which are completed and current, and
falls through to the full check exactly as before.

An earlier, simpler guard — `sym.isCompleted && …` — was not enough:
`isCompleted` goes through `sym.denot`, and the denotation *advance* itself
(replaying `ElimRepeated` and the other info transforms) triggered the same
cascade through a different path. Reading `lastKnownDenotation` is the part
that matters.

First present in the 3.10 stream; 3.9 predates #26156 and needs no patch.
Upstream candidate: the unguarded forcing bites any build that combines
`-sourcepath` with macro suspension, independent of this fork.

Upstream #27247 later deleted `PruneInlinedMethods` altogether, taking the
unguarded forcing with it, so the patch is not carried on its descendants.

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

That is harmless in a single-run compilation, where completers resolve against
the current run. But `dotc` restarts suspended units in a *second* run inside
the same invocation: when a macro or inline expansion depends on a symbol
compiled in the current run (typically pulled in via `-sourcepath`),
`CompilationUnit.suspend` defers the unit and `Driver.finish` recompiles it
with `compileSuspendedUnits` in a fresh run. In that second run, the pruning
phase's forcing reaches completers — a `Namer` `ClassCompleter` typing a parent
application, whose implicit search walks imported scopes — that resolve symbols
created in the first run. Those have no second-run denotation, and
`bringForward` fails:

    StaleSymbolException: stale symbol; module class compileTimeOnly$ …
    defined in Period(1.1-2), is referred to in run Period(2.1)

## How to reproduce

The in-tree reproduction is the distribution build's Scala.js scalalib overlay
step, which compiles `library-js-aux/src/scala/runtime/*.scala` with
`-sourcepath library/src -scalajs`: one of the units suspends on a
sourcepath-loaded macro dependency and the second run crashes as above while
compiling `BoxesRunTime.scala` during erasure. On an unpatched tree, `make
STREAM=3.10 release` fails at exactly this step (it succeeded at p13, whose
base predates #26156; sources, flags and Makefile are byte-identical). The same
invocation compiles cleanly under `-Yskip:pruneInlinedMethods,pruneInlineTraits`,
which attributes the crash to the new phases without rebuilding anything. No
self-contained reproduction has been extracted yet — it needs a macro whose
dependency arrives via `-sourcepath` (see `repro/FIXME.md`).

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

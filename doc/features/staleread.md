# Tolerate reading newer denotations from stale run contexts

Fixes a `staleSymbolError` crash ("denotation ... invalid in run N") by letting a context captured in an earlier compiler run safely read a denotation that has already been brought forward to a newer run.

## Context

The Scala 3 compiler processes source files in **runs**. A single invocation of `scalac` is normally one run, but the compiler can start further runs internally: the REPL starts a run per input line, and *compilation suspension* — used when a macro's class must be compiled before the code that expands it — re-compiles suspended files in a fresh run. Each run passes every symbol through a fixed sequence of **phases** (parser, typer, ..., capture-checking setup, erasure, backend).

What a symbol *means* — its name, type, owner, flags — can differ from phase to phase, so the compiler stores this information in **denotations**, each stamped with a validity `Period` (a run ID plus a phase interval). A symbol holds a ring of denotations, and `Denotations.current` returns the one valid for the reading context's period, computing new ones on demand. When a new run starts, `bringForward()` re-stamps a still-valid denotation with the new run ID in place; the old run's version ceases to exist. A denotation whose run ID no longer matches the current context is **stale**, and reading one is normally an internal error.

## The problem

`current` assumed the reading context's run is always at least as new as the denotation's. That fails when a closure captures a context in run *N*, run *N+1* starts, and the closure is then forced. `LazyRef` and `TypeMap` instances hold their creating context exactly like this.

Concretely: compile, with `-language:experimental.captureChecking`, a file that uses TASTy-loaded collection types (e.g. `TreeMap` or `LazyList`) together with a not-yet-compiled macro. The macro forces a compilation suspension, so the file is re-compiled in a fresh run. The capture-checking Setup phase then forces lazy type maps over the collection hierarchy that were created *before* the re-run. Those closures read denotations of traits such as `scala.collection.SortedSetFactoryDefaults`, which the new run has already brought forward — and the compiler crashes:

```
error: denotation trait SortedSetFactoryDefaults invalid in run 3.
defined in run 4.
```

The old code saw `valid.runId != currentPeriod.runId`, called `toNewRun`/`bringForward()` — which is designed to move denotations *forward* — and, unable to produce a denotation for the *older* period (it no longer exists), fell through to `staleSymbolError`.

## The solution

Add one case to `SingleDenotation.current` in `compiler/src/dotty/tools/dotc/core/Denotations.scala`: if the denotation's run ID is **newer** than the reading context's, return the denotation unchanged.

This is correct because the situation is unambiguous: the flock was re-stamped in place, so no denotation for the stale period exists any more, and the fresher denotation is the only — and up-to-date — description of the symbol. It is safe because the alternative actions are strictly worse: re-stamping validity backwards to the older run would corrupt the newer run's state, and attempting to "bring forward" into the past either loops or crashes, which is precisely the bug. Reads from a genuinely-current context are untouched, since for them `valid.runId <= currentPeriod.runId` always holds.

## Code

```scala
// SingleDenotation.current, Denotations.scala
if valid == Nowhere then
  nextDefined
else if valid.runId > currentPeriod.runId then
  // The denotation was already brought forward to a NEWER run than the reading
  // context's: the reader holds a stale context (e.g. a `LazyRef`/`TypeMap` closure
  // created in an earlier run and forced after a compilation-suspension re-run, as
  // capture-checking Setup does over TASTy-loaded collection traits). The old flock
  // was re-stamped in place, so no denotation for the stale period exists any more;
  // reading the fresher one is safe, whereas bringing it "forward" to the older run
  // would corrupt the newer run's state (or loop).
  this
else if valid.runId != currentPeriod.runId then
  toNewRun            // normal case: old denotation read from a newer run
else if currentPeriod > valid then goForward
else goBack
```

The new branch must come before the generic `runId != currentPeriod.runId` test, which otherwise routes the newer-denotation case into `toNewRun` and the crash.

## Relevance to Soundness

Soundness combines exactly the ingredients that trigger this: pervasive macros (forcing compilation suspensions) alongside capture-checked modules using TASTy-loaded collections. For example, Turbulence's `Loadable` typeclass (`/Users/propensive/work/soundness/lib/turbulence/src/core/turbulence.Loadable.scala`) enables `language.experimental.captureChecking` and abstracts over `LazyList[Operand]` streams:

```scala
import language.experimental.captureChecking

trait Loadable extends Typeclass:
  type Self <: Documentary
  type Operand
  def load(stream: LazyList[Operand]): Document[Self]
```

Compiling such a module in the same run as code awaiting macro classes from another Soundness module suspends and re-runs the unit, after which capture-checking Setup forces pre-suspension type maps over the collection hierarchy — hitting the stale-context read this patch tolerates.

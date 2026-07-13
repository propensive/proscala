# Evaluate IntegrateMap symbols in the spliced run context

Fixes a compiler crash (`denotation ... invalid in run N`) when a lazy type built with `IntegrateMap` is forced in a later run after a macro-induced compilation suspension.

## Context

Scala 3 macros are compiled code that runs *inside* the compiler: a call site `${ internal.amount[units] }` splices in the result of executing `internal.amount` at compile time. If a macro is defined and used in the same compilation, the compiler cannot execute a macro it has not finished compiling, so it **suspends** the using compilation unit and retries it in a fresh compiler **run** once the macro's classfiles exist. Each run has a `runId`, and every symbol's meaning (its *denotation*) is validated per run: `updateValidity` asserts that denotations only move forward in time, never backward.

`IntegrateMap` (in `compiler/src/dotty/tools/dotc/core/Types.scala`) is a `TypeMap` used by `LambdaType.integrate` when constructing dependent method and poly types: it replaces references to parameter *symbols* with the corresponding `ParamRef`s of the lambda under construction. It exists as a faster, safer variant of `subst` that overrides `derivedSelect` to avoid reloading denotations while the lambda is only half-built.

Types can also be **lazy**: a `LazyRef` wraps a thunk that computes its underlying type on first access — possibly in a *later run* than the one in which the map was created. `TypeMap` anticipates this: it holds its context in a `var mapCtx`, and its `mapOver` case for `LazyRef` "splices in" the new run, temporarily rebasing `mapCtx` onto the forcing run's `runId` before mapping the forced type.

## The problem

`IntegrateMap` is declared as:

```scala
private class IntegrateMap(from: List[Symbol], to: List[Type])(using Context) extends TypeMap
```

That anonymous constructor `using Context` parameter **wins implicit resolution inside the class body** over the inherited `mapCtx` var. So even when the `LazyRef` run-splicing dutifully updates `mapCtx` to the new run, all symbol computations in `apply` and `derivedSelect` — `tp.symbol`, `tp.symbol.is(Method)`, `tp.denot.asSeenFrom(pre)` — still execute in the frozen creation-time context of the *old* run. Loading a denotation in an old-run context drags it backward across runs, and the next forward access trips the assertion.

The symptom is a compiler crash after a suspension/retry cycle, typically:

```
java.lang.AssertionError: assertion failed:
  denotation value x invalid in run 2. ValidFor: Period(3.1-40)
```

A minimal shape that hits it — a macro defined and used in the same compilation (forcing suspension into run 2), where typing the call involves a dependent method type whose construction (via `integrate`) is captured inside a lazy type forced in run 2:

```scala
// Internal.scala
import scala.quoted.*
object Internal:
  def amount[U: Type](using Quotes): Expr[String] = Expr(Type.show[U])

// Amount.scala — same compilation: this unit gets suspended to run 2
object Amount:
  // dependent method type: result mentions the parameter symbol `u`,
  // so integrate/IntegrateMap runs while typing it
  def name(u: Unit)(v: u.type): String = ""
  inline def apply[U]: String = ${ Internal.amount[U] }
```

## The solution

Make the class body use the *live* `mapCtx` rather than the stale constructor context, by shadowing the constructor parameter with a local `given` at the top of both overridden methods. This restores exactly the behaviour every ordinary `TypeMap` gets for free: when `mapOver`'s `LazyRef` case rebases `mapCtx` into the forcing run, all denotation loads follow it, so denotations only ever move forward and `updateValidity` is satisfied. Nothing changes in the single-run case, since there `mapCtx` and the constructor context agree.

## Code

The entire patch is two one-line shadows in `IntegrateMap` (`compiler/src/dotty/tools/dotc/core/Types.scala`):

```scala
private class IntegrateMap(from: List[Symbol], to: List[Type])(using Context) extends TypeMap:
  override def apply(tp: Type) =
    given Context = mapCtx   // shadow the frozen constructor Context
    tp match
      case tp: NamedType =>
        val sym = tp.symbol  // now resolved in the (possibly run-spliced) mapCtx
        ...

  override final def derivedSelect(tp: NamedType, pre: Type): Type =
    given Context = mapCtx   // see `apply`
    ...
    NamedType(pre, tp.name, tp.denot.asSeenFrom(pre))  // denot loaded in current run
```

The `mapCtx` being followed is the one updated by `TypeMap.mapOver`:

```scala
case tp: LazyRef =>
  LazyRef { refCtx =>
    ...
    else // splice in new run into map context
      mapCtx = mapCtx.fresh
        .setPeriod(Period(refCtx.runId, mapCtx.phaseId))
        .setRun(refCtx.run)
      try this(ref1) finally mapCtx = saved
  }
```

## Relevance to Soundness

Soundness modules routinely define macros and invoke them from the *same* module, which is precisely the pattern that forces suspension and a second run. For example, in Quantitative, `lib/quantitative/src/core/quantitative.Amount.scala` calls a macro defined in the sibling file `quantitative.internal.scala`:

```scala
inline def apply[units <: Measure]: Text = ${quantitative.internal.amount[units]}
```

Combined with Quantitative's heavy use of dependent and match types over `Measure`, lazy types created in the first run are forced during the post-suspension run, where the stale-context `IntegrateMap` crashed the compiler.

# Render an escaped type error in the context it was raised in

Makes `Driver.doCompile` render a `TypeError` that escaped a run in the context the error was raised in, so that a cyclic reference met in a late phase is reported as one, instead of the compiler dying with `denotation … invalid in run 1` while trying to describe it.

Always on: it only changes what the compiler prints as it fails.

## Context

Most type errors are caught where they arise — typer catches a `TypeError` and reports it at the tree it was typing — but one raised in a later phase, where nothing catches it, propagates out of `Run.compile` to `Driver.doCompile`, whose last resort is to print it and rethrow:

```scala
case ex: TypeError if !runOrNull.enrichedErrorMessage =>
  println(runOrNull.enrichErrorMessage(s"${ex.toMessage} while compiling ${files.map(_.path).mkString(", ")}"))
  throw ex
```

`toMessage` takes a `Context`, deliberately the handler's rather than the error's own: for a cyclic reference, the handling context says whether the cycle was met while inferring a result type, which is what turns a bare "cyclic reference" into "overloaded or recursive method needs result type" (`TypeErrors.scala`, the comment on `toMessage`, test `i2887b`). That is the right choice for every handler inside a run.

`doCompile` is not inside a run. Its context is the one the run was created *from*, with run id 1; the run itself has id 2, and the run that `finish` starts for the units suspended by the first (sources that use a macro defined in the same compilation) has id 3. A denotation is valid for the run that created it, and a symbol asked for its denotation in an *earlier* run cannot be brought forward — `SingleDenotation.bringForward` asserts, by design, that time only runs forward:

```
assertion failed: denotation class SourceFile invalid in run 1. ValidFor: Period(3.1-75)
```

`CyclicReference.toMessage` asks exactly that, for the symbol whose completion cycled (`cycleSym.flagsUNSAFE`, then `cycleSym.isOneOf(…)`), so a cyclic reference raised in run 3 and caught in run 1 is never described: the assertion replaces it, and what is printed is a stack trace through `updateValidity`, `bringForward` and `toMessage` that names the symbol only incidentally. The same loss happens for any `TypeError` whose message refers to a symbol completed in the run.

## Reproducing it

Soundness meets this in the suspended-units run of `quantitative.core.native` (25 sources, Scala Native 0.5.12's `nscplugin`), in roughly one clean build in three at `-j 6`: a cyclic reference involving the class `scala.annotation.internal.SourceFile` is raised in `scalanative-genNIR`, and the build log showed the assertion above and nothing about the cycle (propensive/proscala#20). The cycle itself — a late-phase base-class computation re-entered through `MoveStatics` — is [movestatics](../movestatics/movestatics.md); this patch is what made it visible, printing

```
Cyclic reference involving class SourceFile
The error occurred while trying to compute the base classes of class SourceFile
  which required to compute the base classes of class SourceFile
```

with `-explain-cyclic`, and the stack of the raise with `-Ydebug-cyclic`. No self-contained reproduction is known yet; `repro/FIXME.md` says what one needs.

Any escaping `TypeError` from a suspended-units run would do, in principle: a `CyclicReference` raised by a phase that does not catch it, in a compilation with at least one suspended unit. Upstream's phases after typer do not catch `TypeError`, and a compiler plugin's phase is as good as any of them.

## The solution

`TypeError` already receives the context it is raised in (`creationContext`); the patch exposes it as `creationCtx`, and `doCompile` renders the message in that context whenever it belongs to a later run than the handler's:

```scala
case ex: TypeError if !runOrNull.enrichedErrorMessage =>
  val msg = ex.toMessage(using if ex.creationCtx.runId > ctx.runId then ex.creationCtx else ctx)
  println(runOrNull.enrichErrorMessage(s"$msg while compiling ${files.map(_.path).mkString(", ")}"))
  throw ex
```

The handler's context is kept when it is at least as recent as the error's — which is never the case here, since `doCompile`'s context predates every run it starts, but keeps the rule honest for a driver that calls `doCompile` from inside a run. The raising context sees every denotation the error can refer to, so the cycle is described: `Cyclic reference involving class SourceFile`, with the `-Ydebug-cyclic` trace if one was recorded, `while compiling <the files>`.

The choice of context costs nothing for the "needs result type" diagnostics: those arise under `Mode.InferringReturnType`, inside typer, where the error is caught before it could reach the driver.

This is a change to a crash's report, not to what the compiler accepts, so it is always on and the compilation still fails; the cyclic reference it reveals is a separate problem, to be fixed where it is raised.

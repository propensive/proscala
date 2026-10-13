# Capture-check closures inlined from compiled code

Makes the capture checker check the body of a closure that reaches it in an inline method's body read from TASTy, which upstream silently skips.

Enabled with `-Zcheck-inlined-closures`: it rejects code that upstream accepts.

## Context

The capture checker checks a closure's body as part of computing the closure's
type. In Setup, each anonymous function whose signature changes under capture
checking gets a completer, and `CheckCaptures.recheckClosureBlock` relies on
completing the function to check its body:

```scala
if !anonfun.isCompleted then
  matchParamsAndResult(mdef.paramss, pt)
  anonfun.ensureCompleted() // this will recheck def
else
  recheckDef(mdef, anonfun)
```

But only one kind of completer rechecks the definition: the one Setup installs
for a function whose result type is an `InferredTypeTree`. A function whose
result type is declared gets a completer that only sets its new info. In source,
a lambda's result type is always inferred, so the difference never shows. In
TASTy, though, type trees are not marked as inferred, and every closure in an
inline method's body arrives at the inline site with a declared result type. If
its parameter types change under capture checking, as any closure taking a
capability does, nothing checks its body.

So code that is rejected when compiled with the library it uses is accepted
when compiled against the library's jar.

## Reproducing it

```scala
// Lib_1.scala
class File extends caps.SharedCapability

def usingFile[T](op: File^ => T): T = op(File())

inline def withFile[T](inline f: File^ => T): T = usingFile { file => f(file) }
```

```scala
// Test_2.scala
def test = withFile(file => () => file)
```

The closure `() => file` lets `file` escape `usingFile`. Compiled in one run,
Scala 3.10.0 rejects `test`:

```
Capability `file` outlives its scope: it leaks into outer capture set 's1 which
is owned by method test.
```

Compiled separately, with `Lib_1.scala` first, it accepts it. The closure
`{ file => f(file) }` comes from TASTy with the declared result type `T`, its
parameter type `File` becomes `File^` in Setup, and its body, which is where the
user's lambda is inlined, is never checked.

Soundness inlines a great deal of code that takes capabilities through closures
(`contingency.attempt`, `Api.Response.attempt` in apoplexy, the stream
combinators of zephyrine), so an error in a caller's code there can go unreported
for as long as the library is consumed as a jar.

## The solution

After completing the function, `recheckClosureBlock` checks its definition
unless its completer already has. `skipRecheck` is the guard `Recheck` already
uses to avoid checking a definition that a completer has checked on an earlier
reference: it holds exactly the definitions `completeDef` has checked.

```scala
if !anonfun.isCompleted then
  matchParamsAndResult(mdef.paramss, pt)
  anonfun.ensureCompleted() // this will recheck def, if its result type is inferred
  if config.Proscala.enabled(config.Proscala.InlinedClosures) && !skipRecheck(anonfun)
  then recheckDef(mdef, anonfun)
```

The body is now checked against the closure's declared result type, so the
reproduction reports the leak twice, once against that result type and once
against the expected type of `usingFile`'s argument, where one run reports it
once.

The patch comes after [closurerecheck](../closurerecheck/closurerecheck.md) in the
series, which edits the same lines to keep a closure that was already checked
from being checked again. It is gated
because it can reject code that compiles today: any capture error in a caller's
code inlined into such a closure, which was previously unreported. The patch's
test is `neg-custom-args/captures/inlinedclosures`.

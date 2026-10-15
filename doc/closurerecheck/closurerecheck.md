# Do not recheck a closure its completer has checked

Stops the capture checker from checking a closure's body a second time, against result types left by the first check, when the closure was completed before its block was reached.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

The capture checker checks most definitions as it reaches them, but it can
also check one on demand: a definition whose type is inferred gets a completer
in Setup, and the first time anything asks for its type, the completer checks
the definition (`CheckCaptures.completeDef`) and records it in `completed`.
When the traversal reaches the definition later, `Recheck` asks `skipRecheck`
and does not check it again.

Closures take a different route. `recheckClosureBlock` checks the anonymous
function itself:

```scala
if !anonfun.isCompleted then
  matchParamsAndResult(mdef.paramss, pt)
  anonfun.ensureCompleted() // this will recheck def
else
  recheckDef(mdef, anonfun)
```

The `else` branch assumes that a function already completed has not been
checked: it was completed only because its types did not change. But a
function can also be completed by an earlier reference, through its completer,
which has already checked it. Then its body is checked twice. A closure nested
in the body was completed the first time, with a result type holding the fresh
capabilities of that check; the second check makes new ones, and they cannot
flow into the old.

## Reproducing it

The error appears only where something asks for the type of a definition inside
a closure before the closure is checked. Soundness reaches that through a
wisteria derivation (whose macro gives some of the definitions it generates
irregular owners), summoned by `summonInline` inside a closure in a compiled
inline method, so the closure's body is reached only from `postCheck`, which
forces a definition inside it. apoplexy's `Api.Response.attempt` is such a
method:

```scala
transparent inline def attempt[value]()(using ...): Attempt[value, Failure] =
  contingency.attempt[Failure]:
    call[value]()(using default)(using online, loggable, connect, client)
```

and `api.pet(42L).get.attempt[Swagger.Pet]()`, with `strategies.throwUnsafely`
in scope and a field of type `Optional[Long]` in `Swagger.Pet`, fails on 3.10.0:

```
Found:    (Long is jacinta.Json.Decodable)^{any}
Required: jacinta.Json.Decodable{type Self = Long}^{any²}

Note that capability `any` cannot flow into capture set {any²}.

The error occurred for a synthesized tree:  jacinta.Json.long(soundness.strategies.throwUnsafely[Any])

where:    any  is a root capability classified as SharedUnscoped created in anonymous function of type (): (Long is jacinta.Json.Decodable)^{fresh} when instantiating given instance throwUnsafely's type contingency.ThrowTactic[fulminate.Hazard, Any]^{fresh²}
          any² is a root capability classified as SharedUnscoped created in anonymous function of type (): (Long is jacinta.Json.Decodable)^{fresh} when instantiating given instance throwUnsafely's type contingency.ThrowTactic[fulminate.Hazard, Any]^{fresh²}
```

Both capabilities come from instantiating `throwUnsafely` in the same by-name
argument, `Json.long(throwUnsafely)` passed to `Json.optional`: once in each
check. The same code compiled with apoplexy in one run is accepted, as it is on
3.9. Current Soundness no longer exercises it; `repro/FIXME.md` records the
Soundness commit that does, a two-file probe against its jars, and which
ingredients were shown to be necessary, but no self-contained reproduction
is known yet.

## The solution

`recheckClosureBlock` asks `skipRecheck`, as `Recheck` does for every other
definition:

```scala
else if !skipRecheck(anonfun) then
  // A definition already rechecked by its completer, on an earlier reference to it,
  // is not rechecked again: its nested closures would be checked against result
  // types holding the first check's fresh capabilities.
  recheckDef(mdef, anonfun)
```

A closure checked by its completer is now checked once, as any other definition
with an inferred type is. The outcome of every test in
`tests/{neg,pos}-custom-args/captures` is unchanged.

The underlying cause, that a closure inlined from TASTy is not checked when
the main traversal reaches it, is addressed separately and behind a flag by
[inlinedclosures](../inlinedclosures/inlinedclosures.md).

# Reproduction: diagnostic-given

A macro-implemented given marked `@scala.annotation.internal.diagnostic` that
aborts with `report.errorAndAbort` while being tried as an implicit candidate:
its message must become the authoritative error when the search fails, without
disturbing the search's *outcome* for `NotGiven`, `summonFrom` fallbacks, or
default `using` arguments.

Compile in **two runs** — the macro library first, then each use site against
it — with no special flags:

```
scalac -d out Macro_1.scala
scalac -classpath out -d out Test_2.scala   # must fail, with the custom message
scalac -classpath out -d out Pos_2.scala    # must succeed
```

`Test_2.scala` summons a `Missing` for which only the aborting
`@diagnostic` given is a candidate. On an unpatched compiler the abort is
discarded and the error is the `@implicitNotFound` text ("annotation
message"); with the patch, the reported error is the macro's own:

```
CUSTOM DIAGNOSTIC: Missing
```

`Pos_2.scala` checks the failure is still a *failure*: with the catch-all
`@diagnostic` given in scope, `NotGiven[Missing]` still resolves, a
`summonFrom` still reaches its fallback case, and a defaulted `using`
parameter still applies its default — all of which a spuriously-succeeding
candidate would corrupt.

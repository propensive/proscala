# Reproduction: searchdiag

A macro-implemented given marked `@scala.annotation.internal.diagnostic` that
aborts with `report.errorAndAbort` while being tried as an implicit candidate:
its message must become the authoritative error when the search fails, without
disturbing the search's *outcome* for `NotGiven`, `summonFrom` fallbacks, or
default `using` arguments.

Compile in **two runs** — the macro library first, then each use site against
it. The use sites need `-Zdiagnostic-givens`, which enables the feature (the
test-suite copies carry it as a `//> using options` directive, which batch
`scalac` does not read):

```
scalac -d out Macro_1.scala
scalac -Zdiagnostic-givens -classpath out -d out Test_2.scala      # must fail, with the custom message
scalac -Zdiagnostic-givens -classpath out -d out Pos_2.scala       # must succeed
scalac -Zdiagnostic-givens -classpath out -d out NotGiven_2.scala  # must fail: NotGiven of a present type
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

`NotGiven_2.scala` checks the other side of the negation: with a `Present`
instance in scope, `NotGiven[Present]` must *not* resolve. `NotGiven[X]` is
resolved by inverting each candidate's result, and the `@diagnostic` catch-all
is itself a candidate for `NotGiven[X]`, so before the fix its abort was
inverted into a spurious success and `NotGiven`'s own instances were never
consulted. With the fix, a `@diagnostic` candidate's failure is never inverted.

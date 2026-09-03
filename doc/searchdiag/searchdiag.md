# Preserve diagnostics from `@internal.diagnostic` implicit candidates

A given marked `@scala.annotation.internal.diagnostic` whose macro aborts with
`report.errorAndAbort` while being tried as an implicit candidate fails the
search normally, but its reported errors become the authoritative message if
the overall search fails — taking precedence over `@implicitNotFound` and over
the compiler's default "no given instance" text.

Enabled by `-Zdiagnostic-givens` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches.

## Context

Soundness's Frontier module provides a catch-all
(`transparent inline given explainMissingContext: [any] => any`) whose macro
explains *why* an implicit search failed: it re-runs the search excluding
itself, and either returns the found instance at its precise type or renders a
diagnostic tree of the candidates tried, what each still requires, and known
classpath instances that could satisfy them.

Upstream Dotty gives such a macro no way to fail usefully. Each candidate is
tried under a fresh buffering `StoreReporter`; an `errorAndAbort` is contained
in `Splicer.splice`, and `typedImplicit` converts it to a `MismatchedImplicit`
and calls `removeBufferedMessages` — the message is destroyed. The only
alternative was for the macro to *succeed* with a tree that errors in a later
phase, but a spurious success corrupts everything that depends on search
failure: `NotGiven` inverts, `summonFrom` never reaches its fallback cases,
and default `using` arguments never apply. There is no third option in user
space, so the compiler provides one.

## The mechanism

- `scala.annotation.internal.diagnostic` (library) marks the given;
  `defn.DiagnosticAnnot` names it.
- In `typedImplicit`, when the candidate reported errors and its symbol
  carries the annotation, the buffered errors are wrapped in a new
  `DiagnosticFailure` (a `MacroErrorsFailure` subclass) instead of being
  discarded. This case must precede the `PreviousErrorType`/`NestedFailure`
  case, which would otherwise reduce an aborted expansion to the generic
  "macro expansion was stopped".
- `rank`'s failure selection and the contextual-vs-implicit-scope merge prefer
  a `DiagnosticFailure` over the usual `maxBy(_.tree.treeSize)` (an aborted
  candidate's tree is a tiny `undefined` reference and would never win by
  size). With several errored diagnostic candidates, the first in try order
  wins.
- `MissingImplicitArgument` renders a `DiagnosticFailure` verbatim: it is not
  replaced by a target type's `@implicitNotFound` message, and the
  import-suggestion addenda are suppressed.

The candidate still *fails*, so every construct that depends on search failure
behaves as if the catch-all were absent: `NotGiven` inverts correctly,
`summonFrom` falls through, default `using` arguments apply, and nested
searches (`Expr.summon`, other macros' probes) simply see a failed candidate.

## The transparent chain rule

Expansion-at-typer checks the *called symbol*'s transparency
(`Inlines.needsTransparentInlining`). A transparent given whose body calls a
non-transparent `inline def` macro stops expanding at that call during the
search: the splice never runs, the candidate spuriously succeeds with an
unexpanded body, and the abort only fires in the `inlining` phase — exactly
the corruption this feature exists to remove. Every hop from the annotated
given to the splice must therefore be `transparent inline`.

## Reproduction

`repro/` holds the feature's test files (also checked in as
`tests/neg-macros/searchdiag/` and `tests/pos-macros/searchdiag/`
on the code branches). With a patched compiler:

```sh
scalac -d out Macro_1.scala
scalac -classpath out -d out Test_2.scala   # error: CUSTOM DIAGNOSTIC: Missing
scalac -classpath out -d out Pos_2.scala    # compiles cleanly
```

`Test_2.scala` summons an `@implicitNotFound`-annotated trait with the
annotated catch-all in scope: the reported error must be the macro's own
message (`CUSTOM DIAGNOSTIC: Missing`), not the annotation's. `Pos_2.scala`
exercises `NotGiven`, a default `using` argument and a `summonFrom` fallback
with the catch-all in scope: all must compile. Unpatched (or with the
annotation removed), the neg case reports the `@implicitNotFound` message with
a "macro expansion was stopped" note instead of the diagnostic.

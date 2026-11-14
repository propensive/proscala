# Mark the stable identifiers of a pattern read from TASTy as backquoted

Keeps a backquoted identifier pattern, `` case `label` => ``, matching only the value it names when its unit is recompiled from TASTy, where it silently became a pattern that matches anything.

## Context

A lower-case identifier in a pattern means one of two things. Bare, it is a
**variable pattern**: `case label =>` matches every value and binds it. In
backquotes it is a **stable identifier pattern**: `` case `label` => `` matches
only a value equal to the existing `label`.

The parser records the difference as an attachment, `Backquoted`, on the
identifier's tree, and Typer acts on it: a variable pattern becomes a `Bind`
node, and a stable identifier stays an `Ident` referring to the value. Two later
phases still ask the old question of an `Ident`, though — "does it have the name
of a variable pattern, and no `Backquoted` attachment?" — the pattern matcher,
which discards such a pattern as one that discerns nothing, and the
exhaustivity checker, which takes it to cover its whole type.

An attachment is not part of a tree's type or structure, and TASTy does not
record it. So a tree read back from TASTy has the stable identifier as a plain
`Ident` with a lower-case name and no mark, and the pattern matcher throws the
test away.

This matters to anything that compiles from TASTy rather than from source:
`scalac -from-tasty`, and tools built on it, such as coverage instrumentation or
a shrinker that regenerates a closed classpath. It is a *silent* miscompilation:
no error, no warning, and a class which behaves differently. In Soundness it
changed the outcome of 240 tests in three suites when library classes were
regenerated from TASTy, through a `` case (`label`, value) => `` in
`legerdemain.Query.apply` and several matches in `octogenarian`.

An `inline` method with such a pattern, expanded from another module's TASTy,
was not affected: the inliner wraps the reference it substitutes in an `Inlined`
node, which is not an `Ident`.

## Reproduction

[`repro/`](repro/) — one file, no flags:

```scala
def direct(label: String, value: String): Int = value match
  case `label` => 1
  case _       => -1
```

```
scalac -d a use.scala
scalac -from-tasty -d b -classpath a a/app/Use.tasty
scala -classpath a app.Use      # -1 -1
scala -classpath b app.Use      # 5 1 without the patch
```

## Solution

After Typer, the two kinds of pattern no longer need the attachment to be told
apart: a variable is always a `Bind`, so an `Ident` in a pattern with the name
of a variable pattern, other than the wildcard `_`, can only have been written
in backquotes. The unpickler (`core/tasty/TreeUnpickler.scala`) therefore puts
the attachment back when it has read the pattern of a case:

```scala
private def markStableIdents(pat: Tree): Unit = pat match
  case pat: Ident =>
    if pat.name != nme.WILDCARD && pat.name.isVarPattern then
      pat.putAttachment(Backquoted, ())
  case Bind(_, body) => markStableIdents(body)
  case Typed(expr, _) => markStableIdents(expr)
  case Alternative(pats) => pats.foreach(markStableIdents)
  case UnApply(_, _, pats) => pats.foreach(markStableIdents)
  case _ =>
```

It follows the pattern through the nodes that can hold another pattern — a
binding, a type ascription, alternatives and the arguments of an extractor —
and stops at anything else.

Restoring the mark where the tree is read, instead of changing the question the
pattern matcher asks, means that every reader of the tree sees what it would
have seen from source: the pattern matcher, the exhaustivity checker, and the
tree printer, which shows the backquotes again under `-Vprint:readTasty`.

## Upstream

Upstream behaves the same in both published versions tried, 3.3.7 and 3.10.0.
The patch is always on: it changes only what a unit read from TASTy compiles to,
and makes that what the source compiles to. Worth reporting upstream with the
reproduction.

`tests/run/backquoted-pattern-from-tasty.scala` covers a nested pattern, a
direct one and alternatives under a binding; it shows the fault only where a
test is also run from its own TASTy, as upstream's suite runs its `run` tests.

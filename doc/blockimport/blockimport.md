# Recheck a block's result expression in its statements' context

Keeps an `import` written among a block's statements in scope for the block's result expression during the capture-checking recheck, so that `import scala.language.unsafeNulls` no longer stops applying part-way down a method.

## Context

A block's statements can include an `import`, and it is in scope for everything
after it — the statements that follow *and* the block's result expression:

```scala
def f(input: String, n: Int): Unit =
  import scala.language.unsafeNulls

  val direct: String = input.substring(0, 1)   // a statement

  var i = 0

  while i < n do                               // the result expression
    val inLoop: String = input.substring(0, 1)
    i += 1
```

`substring` is Java-defined, so under `-Yexplicit-nulls -Yno-flexible-types` it
returns `String | Null`. Both assignments rely on `unsafeNulls` to accept that
as a `String`, and both are inside its scope.

Under capture checking, only the first compiles:

```
-- [E007] Type Mismatch Error:
22 |      val inLoop: String = input.substring(0, 1)
   |                           Found:    String | scala.Null
   |                           Required: String
```

The two lines are identical, one statement apart. What separates them is that
`direct` is a statement of the method-body block while the `while` loop is that
block's *result expression* — a distinction the source gives no reason to care
about. Nesting depth is irrelevant; every level inside the trailing expression
fails.

The feature is only relevant when capture checking is on, which is the clue:
capture-checked code is *rechecked* after typing, and it is the recheck that
rejects these lines. The error arrives from
`CheckCaptures.checkConformsExpr` → `Recheck.checkConforms` → `recheckValDef`,
not from the typer.

## Reproduction

[`repro/`](repro/) — one file, `scalac -Yexplicit-nulls -Yno-flexible-types`,
with capture checking enabled by an import in the file.

Soundness's `stratiform` hits it four times, in `Tel.documentShowable` and
`internal.matchAtomText`; each is a nullable Java result inside a `while` that
happens to be its enclosing block's last expression.

## Solution

`Recheck.recheckStats` already handles imports correctly — it rebuilds the
context for each one and threads it through the remaining statements — but its
result type threw that work away:

```scala
def recheckStats(stats: List[Tree])(using Context): Unit =
  @tailrec def traverse(stats: List[Tree])(using Context): Unit = stats match
    case (imp: Import) :: rest =>
      traverse(rest)(using ctx.importContext(imp, imp.symbol))
    ...
```

so `recheckBlock` had no way to reach the context the statements ended in:

```scala
private def recheckBlock(stats: List[Tree], expr: Tree, pt: Type)(using Context): Type =
  recheckStats(stats)
  val exprType = recheck(expr, pt)   // <- the enclosing context, no import
```

The patch returns that context and rechecks the result expression in it:

```scala
val exprCtx = recheckStats(stats)
val exprType = recheck(expr, pt)(using exprCtx)
```

This is what the typer has always done — `typedBlockStats` returns the context
it ends with, and `typedBlock` types the result expression in it — so the change
makes the recheck agree with the phase whose results it is checking, rather than
introducing a new rule.

The two other callers of `recheckStats`, `recheckClassDef` and
`recheckPackageDef`, recheck a statement list with no trailing expression, so
they ignore the returned context and are unaffected.

Nothing else about the recheck changes: statements were already rechecked in the
right context, and a block with no `import` among its statements gets back
exactly the context it had before.

## Upstream

Not a Proscala regression. The same failure appears with a compiler built from
`upstream/3.10` carrying no patch but [`modulepath`](../modulepath/modulepath.md)
— a five-line accessor remap that cannot affect it — and `Recheck.scala` is
identical in `upstream/3.9` and `upstream/3.10`, so both streams carry the bug
and both take the same patch.

Worth reporting upstream. The rule it breaks is a plain scoping rule rather than
anything specific to nulls: any recheck that consults the context would see the
wrong one in a block's result expression. `unsafeNulls` is simply the feature
where the consequence is visible, because it is the one commonly written as a
statement-level import inside a method.

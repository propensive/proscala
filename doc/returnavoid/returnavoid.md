# Avoid only pattern-bound term symbols in rechecked returns

Stops the capture checker's rechecking of `return` expressions (including the
implicit returns of matches inside macros) from "avoiding" quote-pattern *type*
variables, which broke conformance the typer had already established.

## Context

Capture checking re-types the whole program in the `Recheck` phase. When it
rechecks a `return` (or the labelled return that pattern matching compiles a
`match` into), `recheckReturn` compares the returned expression's rechecked
type against the enclosing method's declared result. Before the comparison it
runs the found type through an `AvoidMap` whose job is narrow: the pattern
matching translation sometimes instantiates a return type with pattern-bound
**singleton** alternatives (`(x1.type | x2.type)`), and those term symbols must
be widened away because they are not visible at the method's result.

The map identified its targets by the `Case` flag alone:

```scala
def toAvoid(tp: NamedType) =
  tp.symbol.is(Case) && tp.symbol.owner.isContainedIn(ctx.owner)
```

But `Case` is not exclusive to pattern-bound *values*. Quote-pattern **type
variables** — the `value` in `case '{ $e: value } =>` — are type symbols that
carry the `Case` flag too. The map widened them out of the *found* type; the
label's recorded return prototype, however, still mentions them (through the
infos of the skolems the typer minted), so the *expected* side kept them. The
two sides no longer matched, and rechecking rejected code the typer had
accepted.

## Reproduction

A macro that matches a quoted type variable and splices an `Expr` whose type
refines over it:

```scala
package iss1428min2

import scala.quoted.*
import language.experimental.captureChecking

trait Html { type Topic }

trait Renderable:
  type Self
  type Result
  def render(v: Self): Html { type Topic = Result }

object Macros:
  def impl[T: Type](expr: Expr[T])(using Quotes): Expr[Html] =
    expr match
      case '{ $e: value } =>
        Expr.summon[Renderable { type Self >: value }] match
          case Some(r) => '{ $r.render($e) }
          case None    => '{ new Html { type Topic = Unit } }
```

Compiled with `scalac -experimental repro.scala` (the file carries the capture
checking language import), an unpatched compiler fails with an [E007] type
mismatch at the `'{ $r.render($e) }` splice, of the shape:

```
Found:    Expr[Html{type Topic}]
Required: quoted.Expr[Html]^...'s2
```

— the found type has had `value` avoided out of its refinement while the
required type (reaching the match's label through the return prototype) has
not. With the patch, the file compiles.

## The solution

Restrict the map to **term** symbols, which is all the accompanying comment
ever claimed it was for. In
`compiler/src/dotty/tools/dotc/transform/Recheck.scala`:

```scala
val avoidMap = new TypeOps.AvoidMap:
  def toAvoid(tp: NamedType) =
     // Only term symbols: this map exists to avoid pattern-bound *singleton*
     // alternatives. Case-flagged *type* symbols — notably quote-pattern type
     // variables — also appear in the label's recorded return prototype
     // (through skolem infos), so avoiding them in the found type but not the
     // expected type breaks conformance the typer already established.
     tp.symbol.isTerm && tp.symbol.is(Case) && tp.symbol.owner.isContainedIn(ctx.owner)
```

The singleton avoidance the map exists for is untouched — pattern-bound values
are term symbols.

A symmetric alternative — avoiding the Case-flagged symbols on the *expected*
side too, so the two sides stay in step — was tried and rejected: it changed
the meaning of legitimate avoidance and broke seventeen places in the
capture-checked standard library. Restricting the found-side map to terms is
both smaller and closer to the map's stated intent.

## Relevance to Soundness

Honeycomb (Soundness's typed-HTML library) builds elements through a macro
that pattern-matches its children as quoted type variables and splices back
expressions whose `Html`-like result types refine over those variables —
exactly the shape above. Under capture checking every such element expression
failed with the E007 mismatch (Soundness issue #1428), making the library
uncompilable; with the patch, honeycomb's `element` macro capture-checks
again.

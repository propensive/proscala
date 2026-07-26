# Splice opaque aliases over Seq and Array in vararg positions

Lets a value of an opaque type alias whose underlying type is a `Seq` or an `Array` be spliced into a vararg position (`f(xs*)`) directly, without an implicit conversion and without a call-site cast.

## Context

Soundness's prelude hides the standard collections behind opaque type aliases
so that only a total, typeclass-driven API is visible:

```scala
object Series:
  def apply[e](elements: e*): Series[e] = ...
  extension [e](series: Series[e]) def stdlib: Vector[e] = ...

opaque type Series[+element] = Vector[element]
```

Outside the defining scope such an alias has no useful supertype, so it cannot
be passed where a `Seq` is expected — and in particular it cannot be spliced
into a vararg parameter, since a `T*` parameter *is* a `Seq[T]` underneath.

The stdlib's own `IArray` solves this with a companion implicit conversion
(`genericWrapArray`), which the vararg-splice elaboration picks up. That
encoding is unusable here: an implicit `Conversion[Series[e], Seq[e]]` in the
companion is in `Series`'s implicit scope everywhere, and implicit conversions
also fire at **member selection** — `series.head`, `series.apply(i)` and the
rest of the partial `Seq` surface all silently compile again through the
conversion, defeating the point of the opaque alias. The only remaining option
was an explicit boundary cast at every call site (`f(series.stdlib*)`) —
hundreds of sites of pure noise.

## Reproduction

With two files (the alias must be opaque, i.e. viewed from outside its
defining file):

```scala
// defs.scala
package defs
object Lst:
  def apply[e](elements: e*): Lst[e] = elements.toList.asInstanceOf[Lst[e]]
opaque type Lst[+e] = List[e]
```

```scala
// use.scala
import defs.*
def sum(xs: Int*): Int = xs.sum
@main def Test = println(sum(Lst(1, 2, 3)*))
```

an unpatched compiler rejects the splice:

```
-- [E007] Type Mismatch Error: use.scala:3:24
  |  Found:    (l : defs.Lst[Int])
  |  Required: Seq[Int] | Array[? <: Int]
```

## Solution

All splice elaboration funnels through `typedWildcardStarArgExpr` in
`typer/Typer.scala`: a `xs*` argument is typed against the expected type
`Seq[T] | Array[_ <: T]`, then translated to a `T*`-typed tree. The patch adds
a fallback on the failure path of that first step: retype the expression with
no expected type, strip opaque aliases by walking `translucentSuperType`
(which yields an opaque alias's right-hand side, `asSeenFrom` its prefix), and
if the underlying type derives from `Seq` or `Array`, insert a cast to it and
continue down the unchanged translation path:

```scala
val expr0 = tryEither(typedRegular) { (fallVal, fallState) =>
  val nestedCtx = ctx.fresh.setNewTyperState()
  val bare = typedExpr(tree.expr)(using nestedCtx)
  val pierced = pierceOpaque(bare)(using nestedCtx)
  if (pierced ne bare) && !nestedCtx.reporter.hasErrors
  then { nestedCtx.typerState.commit(); pierced }
  else { fallState.commit(); fallVal }
}
```

The fallback retype is itself speculative, in a fresh typer state that is
committed only when an opaque alias was actually pierced (`pierced ne bare`)
and the retype succeeded. The patch's first version retyped in the enclosing
context and accepted any retype whose type derived from `Seq`/`Array` even
when no opaque alias was involved; when the argument was genuinely erroneous
— e.g. a mistyped splice inside a quote, pre-typed during speculative
overload resolution — the doubly-typed expression leaked duplicate type
variables and quote-hole registrations into the enclosing typer state, and
overload resolution later crashed instantiating a leftover type variable
whose constraint entry no longer existed ("assertion failed: param = T" in
`ConstraintHandling.approximation`). A minimal reproduction of that crash is
in [`repro/`](repro/).

When the underlying type is an `Array` with a wildcard element —
`Array[? <: T]`, which is what any covariant alias over `IArray` uncovers as —
the cast targets `Array[T]` (the element's upper bound) rather than the
wildcard form. The two erase identically, so this changes nothing at runtime,
but it matters under `-Ycc-new`: the repeated translation of `Array[? <: T]`
is the wildcard-argument `(? <: T)*`, and when the capture checker
re-translates that back to an array (`translateFromRepeated`, which wraps the
element in `TypeBounds.upper`) it builds bounds-of-bounds and trips the
`TypeBounds` constructor assertion. The patch's first version cast to the
wildcard form and crashed the capture checker on any cc-checked splice of an
`IArray`-flavoured alias; a minimal reproduction is in
[`repro-cc/`](repro-cc/).

The cast is a no-op at erasure — an opaque alias erases to its underlying
type — so no wrapper is allocated and nothing changes at runtime. Element-type
conformance is still enforced by the ordinary adaptation of the resulting
`T*` tree against the formal parameter; inference of the callee's type
parameters flows through the cast (`count[T](xs: T*)` infers `T := Int` from
`Lst[Int]`); an opaque alias over a non-collection still fails with the stock
error, committed from the failed first attempt. Aliases over `Array` (such as
Soundness's `Data`) take the existing `Array` branch of the translation, and
mid-position spreads under `-language:experimental.multiSpreads` work because
each spread elaborates through the same method. Pattern positions
(`case Seq(x, rest*)`) use a different branch and are untouched.

Because the pierce only engages when regular typing *fails*, behaviour inside
the alias's defining scope — where the alias is transparent and the splice
already typechecks — is unchanged, as is every splice of an ordinary `Seq` or
`Array`.

The change deliberately pierces *any* opaque alias over a `Seq`/`Array` at a
splice site. A conceivable refinement is a definer-side opt-in annotation
(so third-party abstractions cannot be read out element-wise via a splice),
at the cost of a library addition; for now splicing only reveals what
`translucentSuperType` already reveals to inlining.

Verified with capture checking (`-Ycc-new`, impure element types such as
`List[() => Unit]`, and `IArray`-flavoured aliases — see `repro-cc/`), under
separate compilation, and against the real Soundness `proscenium` prelude,
where `f(series*)` now compiles with no `.stdlib*` bridge.

One capture-checking interaction: the inserted cast is a cast type
application, so under `-Ycc-new` its type argument needs the boxing that the
[castbox](../castbox/castbox.md) patch supplies. On the 3.8 and 3.9 trunks
(which carry castbox) impure-element splices check fine; on 3.10, which has
no castbox port yet, a cc splice of an alias with impure element types fails
with castbox's characteristic "is boxed but ... is not" error (pure element
types and all non-cc code are unaffected). The patch itself is independent —
the gap closes when castbox reaches 3.10.

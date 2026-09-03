# Splice any type with a `Spreadable` instance into a vararg position

Lets a value whose type is not a `Seq` or `Array` be spliced into a vararg position (`f(xs*)`) when its author granted permission with a `scala.Spreadable` instance — without an implicit conversion and, for an abstraction over a collection, without any runtime cost.

Enabled by `-Zspreadable-varargs` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches. `scala.Spreadable` ships in the supplementary `proscala-library` jar, not in `scala3-library`; see [compatibility.md](../compatibility.md).

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

## The permission

`scala.Spreadable[T]` grants exactly one thing: `T` may be spliced. It is
consulted only at a splice position, so unlike a `Conversion` it never applies
to a member selection.

```scala
@experimental
trait Spreadable[T]:
  type Out
  def spread(value: T): Out
```

`Out` names the `Seq` or `Array` that `T` spreads to. The instance is written
where the alias is transparent — inside its own file — so it is the identity:

```scala
object Series:
  given [e] => (Spreadable[Series[e]] { type Out = Vector[e] }) =
    new Spreadable[Series[e]]:
      type Out = Vector[e]
      def spread(value: Series[e]): Vector[e] = value   // a Vector, here
```

Because the permission must be given deliberately, a third-party abstraction
cannot be read out element-wise by a splice unless its author intended it —
which the mechanism this replaces could not express.

`Spreadable` is `@experimental`, and that is the whole gate: instances cannot
be written outside experimental mode, so no separate language import exists.

## Reproduction

With two files (the alias must be opaque, i.e. viewed from outside its
defining file):

```scala
// defs.scala
package defs
object Lst:
  def apply[e](elements: e*): Lst[e] = elements.toList.asInstanceOf[Lst[e]]
  given [e] => (Spreadable[Lst[e]] { type Out = List[e] }) =
    new Spreadable[Lst[e]]:
      type Out = List[e]
      def spread(value: Lst[e]): List[e] = value
opaque type Lst[+e] = List[e]
```

```scala
// use.scala
import defs.*
def sum(xs: Int*): Int = xs.sum
@main def Test = println(sum(Lst(1, 2, 3)*))
```

Without the patch the splice is rejected, instance or no instance:

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
no expected type, look for a `Spreadable` instance for it, and if one is found
produce a `Seq`/`Array`-typed tree for the unchanged translation path below.

How that tree is produced is the point:

- If the value's representation, seen through opaque aliases with
  `translucentSuperType`, already **is** a `Seq` or `Array`, the splice becomes
  a cast to that representation. `spread` is never called, nothing is
  allocated, and the cast is a no-op at erasure because an opaque alias erases
  to its underlying type. This is the `Series` case, and it costs nothing.
- Otherwise `spread` is invoked to convert. This is what admits a type with no
  relationship to the collections at all.

The cast targets the **representation**, never the instance's `Out`. An
instance naming an `Out` that its type does not actually have would otherwise
become a `ClassCastException` at runtime instead of a compile error.

The fallback retype is speculative, in a fresh typer state committed only when
the expression really was spreadable. An earlier design retyped in the
enclosing context; when the argument was genuinely erroneous — a mistyped
splice inside a quote, pre-typed during speculative overload resolution — the
doubly-typed expression leaked duplicate type variables and quote-hole
registrations into the enclosing typer state, and overload resolution later
crashed instantiating a leftover type variable whose constraint entry no longer
existed ("assertion failed: param = T" in `ConstraintHandling.approximation`).
A minimal reproduction is in [`repro/`](repro/). The implicit search runs in
that same nested state, for the same reason.

When the representation is an `Array` with a wildcard element —
`Array[? <: T]`, which is what any covariant alias over `IArray` uncovers as —
the cast targets `Array[T]` (the element's upper bound) rather than the
wildcard form. The two erase identically, so this changes nothing at runtime,
but it matters under `-Ycc-new`: the repeated translation of `Array[? <: T]`
is the wildcard-argument `(? <: T)*`, and when the capture checker
re-translates that back to an array (`translateFromRepeated`, which wraps the
element in `TypeBounds.upper`) it builds bounds-of-bounds and trips the
`TypeBounds` constructor assertion. A minimal reproduction is in
[`repro-cc/`](repro-cc/).

Element-type conformance is still enforced by the ordinary adaptation of the
resulting `T*` tree against the formal parameter; inference of the callee's
type parameters flows through (`count[T](xs: T*)` infers `T := Int` from
`Lst[Int]`); mid-position spreads under
`-language:experimental.multiSpreads` work because each spread elaborates
through the same method. Pattern positions (`case Seq(x, rest*)`) use a
different branch and are untouched. Because the search only engages when
regular typing *fails*, behaviour inside the alias's defining scope — where the
alias is transparent and the splice already typechecks — is unchanged, as is
every splice of an ordinary `Seq` or `Array`.

## Two things that could not be done

**`Out` is unbounded.** `type Out <: Seq[?] | Array[?]` would be the honest
declaration, but it cannot be written: an opaque alias over an `Array` —
`IArray` itself — does not conform to it outside its defining scope, which is
exactly the case this exists to serve. The constraint is checked by the
compiler at the splice site instead, seeing through opaque aliases as it goes.

**Spread values cannot hold the root capability.** Under `-Ycc-new` an
instance cannot be keyed on a type capturing the root capability:
`Spreadable[Vector[() => Unit]]` is rejected with *"type variable T of trait
Spreadable cannot be instantiated ... captures the root capability `any`"*.
This is a general capture-checking restriction on type arguments — a bare
`trait Box[T]` behaves identically — and it is the one respect in which this is
weaker than the unconditional pierce it replaces, which compiles that splice.
Element types capturing a *named* capability are unaffected. This limitation
was accepted deliberately when the feature was adopted.

Read the other way round, it is the discipline rather than a gap: **a
capture-carrying collection is not spreadable — freeze it first.** An instance
keyed on the frozen form is what admits the value, which is exactly how
Soundness's `proscenium` declares its mutable array alias:

```scala
given [element] => (Spreadable[Array[element]^{}] { type Out = scala.Array[element]^{} })
```

A frozen `Array[element]^{}` has an empty capture set, so it instantiates `T`
without difficulty and splices under `-Ycc-new`; a mutable `Array[element]^`
does not, and should not. No compiler support is needed for this: verified on
the 3.10 stream, which carries no `castbox`, where the frozen splice compiles
and the capture-carrying instance is refused at its declaration.

## History

Replaces `spliceopaque`, which pierced *any* opaque alias over a `Seq` or
`Array` at a splice site using the same `translucentSuperType` walk, with no
way for a library to opt in or out — splicing revealed whatever
`translucentSuperType` already revealed to inlining. Both of its reproductions
are kept, since both failure modes are still reachable through the
`Spreadable` path; each now carries the `Spreadable` instance that engages it.

# Classify a frozen type as pure

Under `-Zfrozen-pure`, a stateful type with an explicit, constant, empty capture set — a frozen `Array[T]^{}`, or an opaque alias over one — derives from no capability class, so reaching it through an alias no longer stamps a fresh `^{any.rd}` on every field and result that holds it.

## Context

Under `-Ycc-new`, a mutable type such as `Array` is a capability: a plain reference is a
read-only view, writing needs an exclusive (`^`) reference, and `caps.freeze` consumes an
exclusive array to yield `Array[T]^{}` — an array no reference can ever write through,
which is immutability expressed as a capture set rather than as a second type. Soundness
uses exactly this form as its immutable array (`Data = Array[Byte]^{}`), with
[`-Zopaque-mutability`](../iarraypure-mutalias/iarraypure-mutalias.md) classifying its
opaque `proscenium.Array` alias as the mutable array it hides.

Capability classification, `derivesFromCapTrait` in `cc/CaptureOps.scala`, decides whether
a type is a capability by its head symbol after dealiasing. It never consults the type's
own capture set, so `Array[Int]^{}` classifies exactly as `Array[Int]^` does: mutable, a
capability.

## The problem

That classification feeds `Setup.transformExplicitType`, which gives every explicitly
written type that "derives from Capability" but is not itself written with a capture set
an implied one — for a stateful type, `^{any.rd}`. A frozen array written out in full,
`Array[Int]^{}`, is syntactically capturing and escapes this. But an opaque alias over it
is a bare `TypeRef`: inside the alias's defining scope it dealiases to the frozen array,
classifies as a capability, and is stamped `^{any.rd}` wherever it is written:

```scala
object decimal:
  opaque type D = A[Int]^{}          // A: an opaque alias over Array, under -Zopaque-mutability
  object D:
    val zero: D = A.freeze(A.allocate(2))    // inferred D^{any.rd}
    class Holder(d: D):
      val back: D = zero
      // error: object D needs to extend Capability since it has a field `zero` with `any` in its type
      // error: Separation failure: value back's type decimal.D^{any.rd} hides non-local this of class object D
```

The `.rd` is a read-only capability: it cannot license a write, so nothing is unsound,
but every holder of the alias becomes a capability, every object owning such a field must
extend `Capability`, and a field initialised from another `D` fails separation checking.
[`repro/`](repro/) has the program. In Soundness, twelve opaque types representing
immutable arrays (`gossamer.Ascii`, `hypotenuse.Decimal` and `Bcd`, the `PositionIndex`
of each parser, …) had to be backed by the stdlib's `IArray` for this reason alone — the
one type the checker treats as pure by name ([`-Zpure-iarrays`](../iarraypure/iarraypure.md)).

## The solution

A type with no capability reachable through it has no `update` reachable through it either,
so it is immutable from the type alone — the same argument `caps.freeze` rests on. The
patch makes classification look at the capture set first:

```scala
// cc/CaptureOps.scala
private def derivesFromCapTraitDealiased(cls: ClassSymbol, frozenIsPure: Boolean)(using Context): Boolean =
  tp.dealiasKeepAnnots match
  case tp @ CapturingOrRetainsType(parent, refs)
  if frozenIsPure && refs.isAlwaysEmpty
      && config.Proscala.enabled(config.Proscala.FrozenPure)
      && parent.derivesFromCapTraitDealiased(defn.Caps_Stateful, frozenIsPure = false) =>
    false
  ...
```

Only a *stateful* parent with a *constant, empty* set qualifies: a capability class that is
not stateful (`Foo^{}` for a `Foo extends Capability`) keeps its meaning, and an unsolved
capture-set variable stays mutable until it is solved.

Purity for classification must not become permission to write. `Mutability.exclusivity`,
the check behind every `update` call, previously skipped itself for any type that was not
stateful — which the frozen array now is not. It therefore classifies through the empty set:

```scala
// cc/Mutability.scala
private def exclusivity(required: Boolean)(using Context): Exclusivity =
  if tp.derivesFromStatefulUnfrozen then   // was derivesFromStateful
    ... if tp.captureSet.isExclusive(required) then Exclusivity.OK else Exclusivity.ReadOnly(tp)
  else Exclusivity.OK
```

so `a(0) = 1` on `a: Array[Int]^{}`, on an in-scope alias over it, and `c.set(1)` on a
`c: Cell^{}` of a `Mutable` class all still fail with "its capture set {} is read-only"
(`tests/neg-custom-args/captures/frozen-write.scala`), and widening `^{}` to `^` is still
refused by the parent-classified `compareCaptures`. Every other user of the classification
— read-only adaptation, `freeze`, the fields-imply-captures rule — classifies the *parent*
of a capturing type, or acts on the capture set itself, and is unchanged.

`tests/pos-custom-args/captures/frozen-pure.scala` covers the alias in and out of its
scope, a frozen field in a `Mutable` class whose `this` stays exclusive, frozen arrays as
type arguments and tuple members, and an inferred local stored in a pure field. Every
other test under `tests/*-custom-args/captures` has the same outcome with the flag on,
off, and on the previous release.

## Relevance to Soundness

With the flag, `opaque type Decimal = Array[Int]^{}` compiles as `opaque type Decimal =
scala.IArray[Int]` did, which lets Soundness retire `scala.IArray` altogether: the frozen
`Array[T]^{}` is produced by a *checked* `freeze(consume …)` where `IArray` was pure only by
compiler fiat and `IArray.unsafeFromArray`. The flag changes inferred capture sets, so it
belongs with the other seven that [must be set identically](../compatibility.md) in every
capture-checked module sharing TASTy.

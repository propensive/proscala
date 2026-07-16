# Treat `IArray` as pure under capture checking

Stops the capture checker from classifying `IArray` as a mutable capability through its opaque alias to `Array`, so `IArray` construction and manipulation no longer produce spurious `^{fresh}` capture annotations.

## Context

Scala 3's experimental capture checking (`-language:experimental.captureChecking`, with strict mutability under `-Ycc-new`) tracks which *capabilities* a value captures. A value whose type carries no capabilities is *pure*: it can be stored anywhere, shared freely, and referenced from pure classes. Mutable objects are not pure — under strict mutability, a freshly allocated mutable object (such as an `Array`) is typed with a `^{fresh}` capability, marking it as exclusively-owned mutable state. To turn a mutable value into an immutable one you must `caps.freeze` it, relinquishing the right to mutate.

`IArray[T]` is the standard library's immutable array. It is an *opaque type alias* for `Array[T]`: at runtime it is a plain JVM array, but its interface exposes only reading operations — there is no way to write to an `IArray` through its public API.

The classification of a type as mutable is decided by `derivesFromCapTrait` in `cc/CaptureOps.scala`, which *dealiases* the type before checking whether its class derives from a capability trait such as `caps.Mutable`.

## The problem

Because `derivesFromCapTrait` dealiases first, `IArray[T]` dealiases to `Array[T]`, which under strict mutability is capability-classified as `Mutable`. Consequently every stdlib `IArray` factory and extension method result was decorated `^{fresh}` — as if a mutable array had just been allocated — even though the interface exposes no mutation. The freshness then leaks: fields of pure classes cannot hold `^{fresh}` values, and results cannot be typed with the plain, unadorned `IArray[T]` the user wrote.

Minimal reproduction (previously errored; each right-hand side was inferred as `IArray[...]^{fresh}`):

```scala
import language.experimental.captureChecking

object Test:
  val literal: IArray[Int] = IArray(1, 2, 3)          // was IArray[Int]^{fresh}
  def slicePure(a: IArray[Int]): IArray[Int] = a.slice(0, 1)
  def appendPure(a: IArray[Int], b: IArray[Int]): IArray[Int] = a ++ b

  // A pure class may hold an IArray field built from fresh parts.
  class Holder(parts: List[Int]):
    val data: IArray[Int] = IArray.from(parts)
```

This is the new test at `tests/pos-custom-args/captures/iarray-pure.scala`.

## The solution

Constructing an `IArray` is semantically `caps.freeze`: the underlying array is allocated, filled, and then never again exposed for mutation, so a fresh `IArray` is immutable from birth. The patch makes `derivesFromCapTrait` stop at the `IArray` head instead of dealiasing through it — `IArray` derives from *no* capability trait. Since this one predicate feeds capability classification, `freeze`, and the `Setup` phase alike, the spurious freshness disappears everywhere at once. Mutable `Array` itself is untouched: only the opaque alias's head symbol is special-cased, and anything typed as `Array` still classifies as `Mutable`.

This is sound for the same reason `caps.freeze` is sound: the mutation rights to the underlying array are unreachable through the `IArray` interface. (As always, code that casts an `IArray` back to `Array` steps outside the checked fragment.)

## Code

`compiler/src/dotty/tools/dotc/cc/CaptureOps.scala` — guard the predicate before dealiasing:

```scala
def derivesFromCapTrait(cls: ClassSymbol)(using Context): Boolean =
  tp.typeSymbol != defn.IArrayAlias && derivesFromCapTraitDealiased(cls)

private def derivesFromCapTraitDealiased(cls: ClassSymbol)(using Context): Boolean =
  tp.dealiasKeepAnnots match
    case tp: (TypeRef | AppliedType) =>
      val sym = tp.typeSymbol
      if sym.isClass
      then (if sym.isArrayUnderStrictMut then defn.Caps_Mutable else sym).derivesFrom(cls)
      else tp.superType.derivesFromCapTrait(cls)
    ...
```

The old body becomes the private `derivesFromCapTraitDealiased`; the public entry point first checks whether the type's head symbol is the `scala.IArray` opaque alias and, if so, answers `false` for every capability trait. Note the `isArrayUnderStrictMut` line inside the dealiased check — that is where a dealiased `IArray` was being conflated with mutable `Array`.

`compiler/src/dotty/tools/dotc/core/Definitions.scala` — expose the alias symbol:

```scala
@tu lazy val IArrayAlias: Symbol = ScalaPackageClass.requiredType("IArray")
```

## Relevance to Soundness

Soundness compiles all modules with `-Ycc-new -language:experimental.captureChecking` and uses `IArray` as its fundamental immutable-data representation. For example, `anticipation` defines its binary data type as an `IArray` alias with pure factories (`/Users/propensive/work/soundness/lib/anticipation/src/codec/anticipation_codec.scala`):

```scala
type Data = IArray[Byte]

object Data:
  def apply(xs: Byte*): Data = IArray(xs*)
  def build(count: Int)(lambda: Array[Byte] => Unit): Data =
    val array: Array[Byte] = new Array[Byte](count)
    lambda(array)
    array.asInstanceOf[IArray[Byte]]
```

Without this patch, `Data.apply` infers `IArray[Byte]^{fresh}`, which does not conform to the declared pure `Data`, and the same freshness infects every one of the 174 Soundness source files using `IArray` — including pure class fields such as `gossamer.Writing`'s `IArray(0)` (`/Users/propensive/work/soundness/lib/gossamer/src/core/gossamer.Writing.scala`).

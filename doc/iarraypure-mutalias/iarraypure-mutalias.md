# Classify opaque aliases over mutable types under capture checking

Makes the capture checker's mutable-type classification pierce opaque type aliases, so an alias over `Array` (or a `Stateful` class) is tracked exactly like the type it hides, instead of silently escaping the read-only discipline.

## Context

Under `-Ycc-new`, mutable types get access-control tracking: a plain reference
to an `Array` is a read-only view, calling its `update` method demands an
exclusive (`^`) reference, and separation checking rejects aliased writers.
Soundness builds on this for its separation-checked mutable buffer: hide the
partial `Array` behind an opaque alias, expose total reads to any reference,
and writes only to exclusive ones:

```scala
object Buffer:
  def make[element: ClassTag](size: Int): Buffer[element]^ =
    new Array[element](size)

  extension [element](buffer: Buffer[element]^)
    def place(index: Int, value: element): Unit = buffer(index) = value

opaque type Buffer[element] = Array[element]
```

The alias form matters because it makes the buffer allocation-free — the
alternative, a class wrapping the array, costs an object header and an
indirection per buffer.

## Reproduction

The discipline silently fails on an unpatched compiler. The classification
recursion (`derivesFromCapTraitDealiased` in `cc/CaptureOps.scala`) reaches a
non-class type symbol and falls through to its `superType` — which for an
opaque alias outside its defining scope is the declared upper bound, usually
`Any`. The alias therefore never classifies as mutable, a plain
`Buffer[Int]` parameter is an untracked pure value, and pure values subsume
into any capture set — including the exclusive receiver of a write method:

```scala
def sneaky(buffer: Buffer[Int]): Unit = buffer.place(0, 99)  // compiles!
```

[`repro/repro.scala`](repro/repro.scala) compiles without error on an
unpatched compiler; the read-only guarantee the opaque type appears to offer
does not exist.

## Solution

The recursion now pierces opaque aliases with `translucentSuperType` (the
alias's right-hand side, as `asSeenFrom` its prefix — the same lens the
spliceopaque patch uses at vararg splices):

```scala
else if sym.isOpaqueAlias && !(sym eq defn.IArrayAlias)
then tp.translucentSuperType.derivesFromCapTrait(cls)
else tp.superType.derivesFromCapTrait(cls)
```

With it, `Buffer` classifies as mutable everywhere: `sneaky` is rejected
("Found: Buffer[Int], Required: Buffer[Int]^{any}"), exclusive references
read and write, aliased writers fail separation checking, and a
`consume`-based freeze gives use-after-freeze errors — the full matrix the
class encoding provides, with no allocation.

The stdlib's `IArray` stays excluded from the pierce, extending
[iarraypure](../iarraypure/iarraypure.md)'s treatment (hence this patch
builds on that branch): `IArray` itself must classify as immutable, and so
must any alias over it. The exclusion has to sit on the pierce as well as on
the classification entry point, because inside an alias's own defining scope
the alias dealiases transparently and `IArray` then arrives at the recursion
without passing the guarded entry. The first version of this patch missed
that, and every constructor in Soundness's `proscenium.IArray` companion —
compiled in exactly such a scope — pickled a spurious `^{fresh.rd}` result.

Piercing is unconditional for other aliases: an opaque type over a mutable
type now *is* mutable to the checker, and code that treats such an alias as
immutable-by-convention must either accept read-only tracking or switch its
representation to an immutable type. The whole Soundness build was verified
against the patch; exactly one type needed changing (jacinta's `Bcd`, an
immutable digit store previously backed by `Array[Double]`, now honestly
backed by `IArray[Double]`), and the sneaky-write program above is the only
behavioural change anywhere in its ~400-module surface.

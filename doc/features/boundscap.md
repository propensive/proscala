# Keep TypeBounds out of capability wrapping in CC Setup

Stops the capture checker's Setup phase from wrapping a type member's `TypeBounds`
(in particular the `TypeAlias` info of an opaque type member) in a `CapturingType`,
which produced an ill-formed refinement and crashed the compiler with an
`AssertionError`.

## Context

When Setup transforms an explicitly-written type, any component that derives from a
capability class is wrapped in a `CapturingType` carrying the capture set implied by
that capability (`C` becomes `C^{any}`, or `C^{any.rd}` for `Mutable`). Under strict
mutability (separation checking), `Array` is classified as a mutable capability, and
the classification test dealiases — so an opaque type alias whose right-hand side is
an array, e.g.

```scala
object internal:
  opaque type Bcd = Array[Double]
```

"derives from a capability" as far as the test is concerned.

## The problem

The wrap is only meaningful for *value* types. When the transformed component is a
type member's info — a `TypeAlias`, which is a `TypeType` — wrapping it produces
`AnnotatedType(TypeAlias(...), CaptureAnnotation)`, which is a *term* type. As soon
as the enclosing `RefinedType` (here: the self-refinement `internal.type { type Bcd
= Array[Double] }` recording the opaque member) is rebuilt around it, the
`refinedInfo.isInstanceOf[TypeType]` assertion in `RefinedType`'s constructor fails
and the compiler crashes:

```
java.lang.AssertionError: assertion failed: RefinedType(TermRef(..., object internal), Bcd,
  AnnotatedType(TypeAlias(AnnotatedType(Array[Double], {any.rd})), {any.rd}))
```

The 3.9+ streams do not exhibit this because their classification maps arrays to
`Caps_Mutable` *inside* `derivesFromCapTrait` — and `Mutable` does not derive from
`Capability` — so the wrap condition is never true for these aliases. The 3.8 stream
instead adds `|| isArrayUnderStrictMut` disjuncts to `derivesFromCapability` and
friends, making the alias eligible for wrapping.

Real-world reproduction: `jacinta.core` in the Soundness tree (its `jacinta.internal`
object declares `opaque type Bcd = Array[Double]`, and separation checking is enabled
module-wide) crashes the unpatched 3.8 compiler deterministically when `jacinta_core.scala`
is capture-checked; it compiles cleanly with this patch. The trigger needs the full
module context (a minimal file pair with the same opaque member, export, and union-type
usage does not reproduce), so the regression test for this patch is the Soundness build
itself.

## The solution

Exempt `TypeBounds` from the wrap in Setup's explicit-type transform: a type member's
info keeps its canonical alias spelling (`type B = Array[Double]`, not
`type B = Array[Double]^{any.rd}`), matching both the canonical spelling rule already
applied to standalone type aliases and the observable behaviour of the 3.9/3.10
classification. The alias's right-hand side still receives its own capture annotations
where it appears in value positions.

## Code

`compiler/src/dotty/tools/dotc/cc/Setup.scala` — one extra conjunct in the fallthrough
case of `innerApply`:

```scala
if t.derivesFromCapability
    && t.typeParams.isEmpty
    && !t.isSingleton
    && !t.isInstanceOf[TypeBounds]
    && (!sym.isConstructor || (t ne tp.finalResultType))
then ...
```

## Relevance to Soundness

`jacinta` (the JSON module) declares `opaque type Bcd = Array[Double]` for its
high-precision number representation and compiles with separation checking enabled;
without this patch the 3.8 stream cannot compile `jacinta.core` at all (hard crash),
blocking the entire downstream JSON/codec graph.

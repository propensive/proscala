# Treat non-specialized anonymous-class parents as such, not as a crash

Fixes a compiler crash on anonymous classes whose parent constructor takes a
second argument list, introduced with the experimental inline-traits
machinery.

## Context

Upstream #26156 ("Inline Traits & Specialized Traits", `3adfcbd32a`, after
3.10.0-dev-p13's base) makes `FirstTransform` ask, for every anonymous-class
`TypeDef`, whether the class instantiates a specialized inline trait. The test,
`Specialization.anonymousClassIsSpecialized`, pattern-matches the template's
last parent call; when that call has two argument lists —
`Apply(Apply(t, ctorArgs), ev)` — it assumes the shape could only come from a
specialized trait's evidence list and calls
`Specialization.unapply(t.tpe.resultType.resultType, t.span).get`.

But a two-`Apply` parent call also arises for a completely ordinary parent
whose constructor has a second argument list — most commonly a `using` clause.
For such a parent the type under scrutiny is no `AppliedType`, the `unapply`
returns `None`, and the `.get` throws:

    java.util.NoSuchElementException: None.get
      at dotty.tools.dotc.transform.Specialization$.anonymousClassIsSpecialized
      at dotty.tools.dotc.transform.FirstTransform.transformTypeDef

## How to reproduce

Seven flagless lines (see `repro/`):

```scala
class Base(x: Int)(using s: String)
given String = "ctx"
inline def make(): Base = new Base(1) {}
@main def crash() = println(make())
```

Soundness hits it in `coaxial.wasi` (`coaxial_wasi.scala`), which builds
anonymous implementation classes inside inline givens whose parents take
`using` parameters — the crash that halted the whole 3.10 build sweep.

## Solution

`None` from the `unapply` has an obvious meaning — the parent is not a
specialized trait — so the predicate answers `false` instead of throwing:

```scala
val spec = Specialization.unapply(t.tpe.resultType.resultType, t.span)
spec.exists(_.hasSpecializedParams)
```

One of three defects this stream carries from #26156's unconditional
machinery (see [prunecomplete](../prunecomplete/prunecomplete.md) for the
completion-forcing one); like it, an upstream candidate. 3.9 predates #26156
and needs no patch.

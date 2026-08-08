# Classify and preserve capture information on union types

Closes two union-type gaps in capture checking under strict mutability —
classifying a union's inherited capability as the least upper bound of its
members' classifiers, and keeping an information-bearing empty capture set on
a union with a capability member — so that types like `Unset | Array[Byte]`
behave like their members do alone.

## Context

Under the new capture-checking scheme with separation checking enabled
("strict mutability"), a mutable type such as `Array[Byte]` is tracked: each
occurrence of it acquires a *fresh* root capability, and mutability is
mediated through *classifiers*. An `Array` classifies as `Unscoped`, which is
what allows a fresh instantiated at a local binding to be re-absorbed — `val
r = m()` typechecks even though `m()`'s result carries a fresh, because an
`Unscoped`-classified capability may flow into a local set.

Both halves of this machinery mishandled **unions**. First, a union's
inherited classifier fell through to `classSymbols`, which sees only the
members' common *superclasses* — `Object`, `Matchable` — whose classifier is
`Any`. So while a bare `Array[Byte]` classifies `Unscoped`,
`Unset | Array[Byte]` classified `Any`, and the fresh minted for the union
could never be re-absorbed: every local binding of such a value was an error.

Second, `CapturingType.apply` dropped an empty capture set from a union unless
*every* member derived from a capability trait. An alias like
`type Data = Array[Byte]^{}` inside `Unset | Data` normalizes to
`(Unset | Array[Byte])^{}`; with the `^{}` discarded, the `Array[Byte]` member
re-acquired an implied capture set — a fresh `{any.rd}` — at **each
occurrence** of the union. Two mentions of the same declared alias therefore
never matched each other, so no annotation on the *declaration* could ever
fix a *use site*.

## Reproduction

Eight lines ([repro/repro.scala](repro/repro.scala)), no compiler flags at
all — the two language imports are the whole configuration, and both are
needed (without `separationChecking` there is no strict mutability and the
file compiles unpatched):

```scala
import language.experimental.captureChecking
import language.experimental.separationChecking
type U = Int | Array[Int]^{} | Array[Long]^{}
object O:
  def m(): U = 1
  def use(): U =
    val r = m()
    r
```

An unpatched compiler rejects the binding of `r`:

```
Found:    (Int | Array[Int] | Array[Long])^{any.rd}
Required: (Int | Array[Int] | Array[Long])^'s1

Note that capability `any.rd` is not classified as trait Unscoped, therefore it
cannot flow into capture set 's2 of Unscoped elements.
```

— the normalized union has lost its `^{}` and gained a per-occurrence fresh,
and that fresh classifies as `Any` rather than `Unscoped`, so it cannot flow
into the local set. Replacing the union with a bare `Array[Int]^{}` compiles
unpatched. With the patch, the file compiles as written.

## The solution

Two changes, both in `compiler/src/dotty/tools/dotc/cc/`.

**`CaptureOps.scala`** — `inheritedClassifier` gains an `OrType` case: the
union's classifier is the least upper bound of its members' classifiers, where
an always-pure member (`Unset`, `Int`) contributes nothing (`NothingClass`,
the lub identity) and an unclassified member contributes `Any`, absorbing the
rest:

```scala
def memberClassifier(part: Type): ClassSymbol = part.dealias match
  case part: OrType =>
    lubClassifier(memberClassifier(part.tp1), memberClassifier(part.tp2))
  case part =>
    if part.isAlwaysPure then defn.NothingClass else part.inheritedClassifier
```

The lub — not the existing `leastClassifier` — is what soundness demands here:
a value of a union type is a value of *one* of its members, so the joined
classifier must permit every capability that either member's classifier
permits. `Unset | Array[Byte]` now classifies `Unscoped`, exactly as
`Array[Byte]` does.

**`CapturingType.scala`** — `apply` keeps an empty capture set on a union when
*any* dealiased member derives from a capability trait (previously: only when
all did):

```scala
if refs.isAlwaysEmpty && !parent.isAny && !refs.keepAlways
    && !hasCapabilityPart(parent) then
  parent
```

The `^{}` on such a union is information-bearing: it is what prevents the
capability members from re-acquiring implied capture sets per occurrence, so
two mentions of the same aliased union now denote the same type.

## Relevance to Soundness

Bitumen declares `type Data = Array[Byte]^{}` and threads it through Vacuous's
`Optional[Data]` — precisely `Unset | Data`. `TarBody.pull` in
`bitumen.Tarfile` binds the result of a `() => Optional[Data]` locally, and
under strict mutability every such binding failed with the classifier error
above. Because the per-occurrence freshening meant two mentions of the same
declared type never matched, every source-level fix — casts,
`unsafeAssumePure`, explicit `^{}`, inlining the union — was exhaustively
ruled out before the compiler was patched. Jacinta's JSON representation, a
wide primitive-and-array union (`Long | Int | ... | Array[Any] | ...`), hit
the same mechanism and had been worked around at source; the patch fixes that
shape too, as the reproduction (reduced from jacinta) shows.

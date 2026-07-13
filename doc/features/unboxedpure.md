# Do not box pure types with vacuous or pure-tuple capture sets

A capture-checking fix that stops the compiler from attaching meaningless capture sets to values of provably pure types, which previously caused spurious errors and override failures in inline typeclass code.

## Context

Scala 3's experimental capture checking tracks which *capabilities* (values with effects, such as file handles or async contexts) each value may capture. A type `T^{a, b}` is `T` capturing at most `a` and `b`. When a type appears in a position where its capture set cannot be tracked precisely — for instance, inside an invariant type argument or a type member — the checker *boxes* it: it wraps the type with a capture set, often a fresh inference variable written `^'sN`, to be solved later.

Some types are *always pure*: they can never capture anything. Classes extending `caps.Pure` and opaque types bounded by it fall in this category. Attaching any capture set to such a type is at best redundant, and the checker deliberately rejects a non-empty one with "T is a pure type, it makes no sense to add a capture set to it".

The problem was that the setup phase of capture checking (`cc/Setup.scala`) sometimes *manufactured* capture sets for pure types and then either rejected its own creation or produced types that no longer matched.

## The problem

Two related symptoms, both triggered by inline `Self`-style typeclass methods being re-typechecked under capture checking after inlining.

**1. Spurious "pure type" error.** A pure opaque type flowing out of an inline given acquired a kept-but-empty capture set `Text^{}`, which the finalizer rejected:

```scala
import language.experimental.captureChecking
import scala.caps

opaque type Text <: Matchable & caps.Pure = String & caps.Pure

trait Decomposable extends caps.Pure:
  type Self
  def decomposition(value: Self): Text

inline given derived: [entity] => entity is Decomposable = new Decomposable:
  type Self = entity
  def decomposition(value: entity): Text = Text("x")

extension [left](left: left)
  inline def decompose(using value: left is Decomposable): Text = value.decomposition(left)

val d: Text = Text("hello").decompose
// error: Text is a pure type, it makes no sense to add a capture set to it
```

**2. Broken override via a boxed pure tuple.** A tuple of pure element types in a type-member (invariant) position was given a fresh capture variable, so the derived instance's method type became `Quanta{ type Form = (Pounds, Stones)^'s1 }` and no longer overrode the trait's pure `text(value: Self)`:

```scala
class Pounds extends caps.Pure
class Stones extends caps.Pure

trait Quanta extends caps.Pure:
  type Form

val q: Quanta { type Form = (Pounds, Stones) } = new Quanta { type Form = (Pounds, Stones) }
val s: String = q.show   // failed: derived Showable's `text` no longer overrides the trait's
```

Full reductions live in `tests/pos-custom-args/captures/pure-type-inline-box.scala` and `tests/pos-custom-args/captures/pure-tuple-typemember-box.scala`.

## The solution

Two targeted changes in `compiler/src/dotty/tools/dotc/cc/Setup.scala`:

1. **Strip vacuous capture sets on pure parents.** In `finalizeCapturing`, a `CapturingType` whose parent `isAlwaysPure` and whose capture set is *empty* is now reduced to the bare parent instead of being rejected. An empty capture set on an always-pure type carries no information, so removing it changes nothing semantically. A *non-empty* set on a pure type (e.g. `Int^{io}`) still errors exactly as before, so no genuine mistakes are silenced.

2. **A tuple is as pure as its elements.** `needsVariable` decides whether a type should receive a fresh capture-set variable. Tuples are ordinary case classes, so a `(Pounds, Stones)` previously took the generic class path and got a variable. Since a tuple can only capture what its components capture, the fix asks `needsVariable` of each element type: an all-pure tuple gets no variable, keeping it structurally identical to the pure tuple it must equal in invariant positions.

Both changes only *remove* capture information that is provably vacuous, so no capability tracking is lost: a pure type cannot capture anything, and a tuple of pure types cannot either.

## Code

```scala
// finalizeCapturing: new first case
case CapturingType(parent, refs) if parent.isAlwaysPure && refs.elems.isEmpty =>
  // A vacuously-empty capture set on an always-pure parent carries no information.
  // Strip it rather than rejecting the harmless box.
  parent
```

```scala
// needsVariable: tuples defer to their element types
if sym.isClass then
  tp.tupleElementTypes match
    case Some(elems) =>
      // A tuple captures exactly what its elements do: an all-pure tuple
      // needs no capture-set variable.
      elems.exists(needsVariable)
    case None =>
      !sym.isPureClass && sym != defn.AnyClass
```

## Relevance to Soundness

Both reductions come directly from Soundness code. Anticipation defines `into opaque type Text <: Matchable & caps.Pure` (`lib/anticipation/src/text/anticipation.internal.scala`), and Chiaroscuro's inline `decompose` extension over `Decomposable` (`lib/chiaroscuro/src/core/chiaroscuro_core.scala`) is the direct-mint case. The pure-tuple case is Abacist's `Quanta[base] { type Form = form }`, where `Form` is a tuple of pure unit types such as `(Hours[1], Minutes[1])`; a workaround comment in `lib/abacist/src/core/abacist.protointernal.scala` notes that "forming the refined type within the splice makes capture checking box the `Form` tuple with a fresh capture set, which then fails to unify with the (independently boxed) expected type" — precisely the fresh-var half of this patch. A similar workaround comment exists in `lib/hellenism/src/core/hellenism.internal.scala` for the spurious `Text^…` boxing.

# A shared, level-exempt classifier: `caps.SharedUnscoped`

Adds `scala.caps.SharedUnscoped`, the shared counterpart of `caps.Unscoped`, so that a capability may be both freely aliased (exempt from separation checking) and created at any level (exempt from the scoping check that `Unscoped` exempts exclusive capabilities from).

Always on: the patch adds a library trait and widens three classifier tests to recognise it; code that does not mention the trait is unaffected.

## Context

Capture checking classifies capabilities by marker traits in `scala.caps`. Two classifiers matter here:

- `SharedCapability`: the capability may be aliased freely. Separation checking does not count two references to one shared capability as an overlap, so an error-handling *tactic* that a codec captures and that the same call also takes as evidence is not a conflict.
- `Unscoped`: the capability is exempt from the level check — a value created at a deeper level (inside a synthesised thunk, say) may flow into a result capture set that was minted further out. `Unscoped` is how an ambient strategy, handed out by a polymorphic given at its use site, satisfies a `raises` requirement in a non-inline method result.

The two cannot be combined. `Unscoped extends ExclusiveCapability`, so a class extending both `SharedCapability` and `Unscoped` "inherits two unrelated classifier traits". The lattice has no point that is shared *and* unscoped.

## The problem

Soundness's `contingency.Emit` (the capability behind `raises`) was an `ExclusiveCapability`, with its ambient strategies (`ThrowTactic` and friends) additionally `Unscoped`. Exclusivity made every aliasing of one tactic a separation failure — `json.as[T]` summons a codec capturing the ambient tactic *and* takes the tactic as a using-argument — which cost a `caps.unsafe.unsafeAssumeSeparate` at every such call. Making `Emit` a `SharedCapability` removes those overlaps, but the ambient strategies then cannot stay `Unscoped`, and the level check is back for exactly one shape: a derived codec whose element codec is a by-name parameter, where given resolution synthesises a thunk and the strategy minted *inside* the thunk cannot flow into the by-name's capture root.

```scala
trait Tactic[E] extends caps.SharedCapability
class Throwing[E] extends Tactic[E]
given throwing: [E] => (Throwing[E]^) = Throwing()

given intCodec: (tactic: Tactic[String]) => (Decodable[Int]^{tactic}) = ...
given optionCodec: [T] => (inner: => Decodable[T]^) => Decodable[Option[T]] = ...

def use(): Option[Int] = summon[Decodable[Option[Int]]].decoded("abc")
// error: capability `any` cannot flow into capture set {any²}
//        because any in an enclosing function is not visible from any² in value x$proxy1
//        The error occurred for a synthesized tree:  intCodec(using throwing[String])
```

With `Throwing[E] extends Tactic[E], caps.Unscoped` (and `Tactic` exclusive) the same program compiles; that is the design the shared classification replaces.

## The solution

A new marker trait in `scala.caps`:

```scala
/** The shared counterpart of `Unscoped`: a marker trait for shared capabilities that are not
 *  subject to scoping restrictions. */
@experimental
trait SharedUnscoped extends SharedCapability, Classifier
```

and, in the compiler, one predicate that the places consulting `Unscoped` use instead of testing the class directly:

```scala
extension (sym: Symbol)
  def isUnscopedClassifier(using Context): Boolean =
    sym.derivesFrom(defn.Caps_Unscoped) || sym.derivesFrom(defn.Caps_SharedUnscoped)
```

The sites are the level check itself (`Capability.acceptsLevelOf`), the owner computation that maps an unscoped root to the enclosing top-level class (`Capability.computeOwner`), the closure-result mapping that keeps unscoped roots in anonymous functions, the separation checker's escape test for assignments to outer variables, and the qualifier-capture narrowing in `CheckCaptures.recheckApplication`. Nothing about exclusivity changes: a `SharedUnscoped` capability is shared, so separation checking treats it as it treats any `SharedCapability`.

With `class Throwing[E] extends Tactic[E], caps.SharedUnscoped` the program above compiles, and Soundness's ambient strategies (`strategies.throwUnsafely`, `uncheckedErrors`, `fatalErrors`) carry the classifier while `Emit` is shared.

# Give a differently-classified fresh capability its own root

Fixes a capture-checker crash — `assertion failed: attempting to add any to {any} of value x$proxy1` — when an inferred value type holds two freshly created capabilities whose classifiers are unrelated, by letting the second one keep a root of its own instead of asserting that it can hide in the first.

Always on: a crash fix.

## Context

When capture checking infers the type of a `val`, the capture-set variable created for that type is normalised (`CaptureSet.VarInTypeTree.normalizeLocalCaps`): it should contain a single fresh capability, rooted at the value's own declaration, and every other fresh capability that reached the set is *hidden* in that root. A fresh capability carries a classifier (`SharedCapability`, `Unscoped`, …) inherited from the class that produced it, and a root adopts the classifier of the first capability hidden in it.

## The problem

Hiding asserted that the next capability could be classified like the root:

```scala
def hideIn(ac: LocalCap): Boolean =
  assert(elem.tryClassifyAs(ac.hiddenSet.classifier), fail)
  ...
```

Two fresh capabilities of unrelated classifiers in one inferred type therefore crash the compiler rather than producing a diagnostic — and they arise naturally from an inlined call whose arguments are a polymorphic given of one classifier and an inline given of another:

```scala
trait Tactic extends caps.SharedCapability
class Throwing[E] extends Tactic
given throwing: [E] => (Throwing[E]^) = Throwing()

class Sink extends caps.Unscoped
inline given sink: (Sink^) = Sink()

class Holder(val tactic: Tactic, val sink: Sink^)
given holder: (tactic: Tactic, sink: Sink^) => (Holder^{tactic, sink, caps.any}) = Holder(tactic, sink)

def use(): Int =
  val h = summon[Holder^]   // crash: attempting to add any to {any} of value x$proxy1
  1
```

The proxy value the inliner binds for `holder`'s result has an inferred type whose capture set holds the shared root from `throwing[Any]`, the unscoped root from `sink`, and the result's own `caps.any`. Whichever of the two classified roots is hidden first classifies the declaration root; hiding the other then fails the assertion. In Soundness this surfaced in every test that lends a `Sessional` (an instance whose explicit capture set names a shared `Tactic` beside an unscoped log sink) once `contingency.Emit` became a `SharedCapability`.

## The solution

A classifier mismatch means "this capability cannot be hidden here", which the method already handles for level failures by returning `false`; the caller then mints a further declaration root for the capability:

```scala
def hideIn(ac: LocalCap): Boolean =
  if !elem.tryClassifyAs(ac.hiddenSet.classifier) then
    capt.println(i"classifier mismatch when subsuming in a LocalCap, cannot add $elem to $ac / $fail")
    false
  else if isRefining then
    ...
```

The inferred type then carries one root per classifier, which is what the surrounding code (`inDeclRoots` is a set) already allows. The program above compiles, as does the Soundness suite that crashed.

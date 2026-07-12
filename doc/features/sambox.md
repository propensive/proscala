# Capability-implied captures on SAM anonymous-class type members

Fixes capture-checking errors on Scala.js when a lambda is SAM-converted to a trait whose refinement binds a type member (e.g. `type Self`) to a capability type.

## Context

Under capture checking (`-language:experimental.captureChecking`), types carry *capture sets*: `C^{io}` is a `C` that captures the capability `io`, and `C^` (or `C^{any}`) captures the universal capability. For a class that derives from `caps.Capability`, capturing is *implied*: writing `C` as a declared type really means `C^{any}`, and the compiler's `cc.Setup.transformExplicitType` inserts that implied set automatically. As a normalisation, a type member's own info drops the implied set again — the canonical spelling of `type X = C` is bare `C`.

A *SAM type* is a trait with a single abstract method, so a lambda can implement it: `val s: Source = value => ...`. On the JVM such lambdas stay closures typed verbatim as the expected type, and are lowered late (after capture checking). On Scala.js, `SJSPlatform.isSam` rejects arbitrary (non-`js.Function`) traits, so the `ExpandSAMs` phase — which runs *before* `cc.Setup`/`cc.CheckCaptures` — rewrites the lambda into an anonymous class. That class gets real, separate member symbols, including synthetic type members copied from the expected refinement (`Source { type Self = C }` yields `type Self = C` in the anon class), and capture checking then verifies each member against the declared refinement.

## The problem

Compiling this to Scala.js under capture checking fails, while the JVM build succeeds:

```scala
import caps.*

class Handle extends ExclusiveCapability   // a capability type

trait Source:
  type Self
  def stream(value: Self): Unit            // the single abstract method

val s: Source { type Self = Handle^ } = handle => ()
```

`ExpandSAMs` turns the lambda into `new Source { type Self = Handle^; def stream(value: Handle^) = () }` before capture checking. Then two things go wrong for the synthetic member `type Self = Handle`:

1. `transformExplicitType` boxed the right-hand side to `Handle^{any}` (capability-implied), but the `sym.isType` normalisation immediately stripped it back to bare `Handle`. That is fine for a standalone alias, but here it breaks the anon class internally: the method parameter is typed `Handle^`, which must conform to the inherited `stream(value: Self)` seen through the now-bare member — and `Handle^ <: Handle` fails.
2. Even with both sides boxed, the roots differ: the freshly synthesised member carries `caps.any`, while the declared refinement (checked as a method result) carries a `ResultCap`. `hasMatchingMember` compared them structurally and rejected the match.

The symptom is a spurious "type mismatch / does not conform" error on perfectly ordinary SAM-lambda code, only in the Scala.js linking build.

## The solution

Two coordinated changes:

- **`cc/Setup.scala`**: keep the capability-implied capture set on a type member's info when the member is a *synthetic member of an anonymous class* — exactly the members `ExpandSAMs` fabricates. All other type members keep the canonical bare spelling.
- **`core/TypeComparer.scala`**: in `hasMatchingMember`, treat two type-alias members as matching when both right-hand sides derive from `Capability`, both capture sets are empty or consist purely of root capabilities (`any`, `fresh`, `ResultCap`), and the capture-stripped aliases are the same type. For a capability type the capture is implied and not independently meaningful, so these spellings are interchangeable.

The relaxation only *adds* an acceptance branch, so it cannot reject previously-valid programs; and both changes are inert on the JVM, where the SAM never becomes a class with member symbols before capture checking.

## Code

`Setup.transformExplicitType` — the exception to implied-capture stripping:

```scala
val keepImplied = sym.is(Synthetic) && sym.owner.isAnonymousClass
val tp2 = if sym.isType && !keepImplied then stripImpliedCaptureSet(tp1) else tp1
```

`TypeComparer.hasMatchingMember` — capability-alias equivalence, tried before the ordinary subtype check on member infos:

```scala
def capabilityAliasesMatch(info1: Type, info2: Type): Boolean =
  isCaptureCheckingOrSetup && {
    def universalOrEmpty(t: Type): Boolean =
      val cs = t.captureSet
      cs.isAlwaysEmpty || cs.isConst && cs.elems.forall(_.isTerminalCapability)
    (info1, info2) match
      case (TypeAlias(alias1), TypeAlias(alias2)) =>
        alias1.derivesFromCapability && alias2.derivesFromCapability
        && universalOrEmpty(alias1) && universalOrEmpty(alias2)
        && isSameType(alias1.stripCapturing, alias2.stripCapturing)
      case _ => false
  }
```

Wired in as `capabilityAliasesMatch(info1, info2) || inFrozenGadtIf(tp1IsSingleton) { isSubType(info1, info2) }`.

## Relevance to Soundness

Soundness expresses typeclasses as SAM traits with a `Self` type member and instantiates them with lambdas. In `lib/galilei/src/core/galilei.Handle.scala`, `Handle` is a capability class (`extends caps.ExclusiveCapability`) and its typeclass instances are SAM lambdas over capability-refined handle types:

```scala
given source: [handle <: Handle^] => handle is Source by Data over Credit = _.source()
```

`Source` (in `lib/turbulence/src/core/turbulence.Source.scala`) has the single abstract method `def stream(value: Self): (Stream[Operand] over Transport)^`. The expected type `handle is Source ...` is a refinement binding `type Self = handle`, where `handle` derives from `Capability` — precisely the shape that Scala.js expands to an anonymous class before capture checking, hitting both bugs this patch fixes.

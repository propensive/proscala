# Keep given aliases cached when capture checking is enabled

Prevents an `IllegalCaptureRef` crash in capture-checking Setup by skipping the
`UncacheGivenAliases` optimization — which demotes a stable given alias `val`
to a `def` — whenever capture checking is enabled anywhere in the run.

## Context

A given alias like

```scala
given canvas0: (Board^{canvas}) = canvas
```

elaborates to a `lazy val`. The `UncacheGivenAliases` mini-phase is an
optimization that notices when such a val's right-hand side is a pure, stable
path (so caching it buys nothing) and demotes the `lazy val` to a `def`,
changing the symbol's info to an `ExprType` (`=> Board^{canvas}`).

That is harmless in ordinary compilation: a `def` returning a stable value is
observationally the same as a `val` holding it. Under **capture checking** it
is not. A stable `val` is a *trackable reference*: other types may name it in
their capture sets — `^{canvas0}` — and those `@retains` elements are resolved
to the symbol. After the demotion the symbol is a method with an `ExprType`
info, and a by-name/method reference is **not a legal capability**. Any
capture set still naming it has become malformed.

The malformation is latent until something forces the set. The
dependent-summon casts introduced upstream in 3.9.0-RC5 do exactly that: a
`summon` resolved through a dependent given is cast to its precise dependent
type, and converting that type's retains annotation to a capture set reaches
the demoted symbol and crashes capture-checking Setup:

```
dotty.tools.dotc.cc.IllegalCaptureRef: (canvas0 : => Board^{canvas})
```

This is a compiler crash, not an error the user can address — the source
mentions only legal capabilities.

## Reproduction

Ten lines:

```scala
import scala.language.experimental.captureChecking

trait Board
trait I

given inst: (surface: Board^) => (I^{surface}) = new I {}

def render(canvas: Board^): Unit =
  given canvas0: (Board^{canvas}) = canvas
  summon[I]
```

Compiled with `scalac -experimental repro.scala`, an unpatched compiler
crashes with the `IllegalCaptureRef` above: `canvas0` is a stable alias for
`canvas`, so `UncacheGivenAliases` demotes it; resolving `summon[I]` through
the dependent given `inst` then casts to `I^{canvas0}`, and forcing that
capture set finds a method where a capability should be. With the patch, the
file compiles.

## The solution

The demotion is purely an optimization, so the safe fix is not to perform it
when it can be observed. In
`compiler/src/dotty/tools/dotc/transform/UncacheGivenAliases.scala`:

```scala
override def transformValDef(tree: ValDef)(using Context): Tree =
  val sym = tree.symbol
  // Under capture checking, a stable given alias val is a trackable reference
  // that may already be named in capture sets ({x} in a retains annotation).
  // Demoting it to a def gives it an ExprType underlying, which is no longer
  // a legal capability and crashes cc Setup (IllegalCaptureRef) when a later
  // cast or summon forces the set. Skip the optimization when cc is on
  // anywhere; semantics are unchanged.
  if sym.isAllOf(LazyGiven) && !needsCache(sym, tree.rhs)
      && !Feature.ccEnabledSomewhere then
    ...
```

`ccEnabledSomewhere` (rather than the per-unit `ccEnabled`) is deliberate:
the demoted symbol's new info is visible from *other* units in the same run,
so a cc unit could still meet a method-typed capability minted while
compiling a non-cc unit. Skipping the phase costs only the caching behaviour
the phase would have removed — a `lazy val` where a `def` would have done —
and changes no semantics.

## Relevance to Soundness

Ultimatum (Soundness's terminal-canvas layer) hit this in `Focus`: a
rendering method takes a `canvas` capability and introduces a narrowed local
`given canvas0` alias for it, through which capability-typed drawing evidence
is summoned. From 3.9.0-RC5 — whose new dependent-summon casts force the
relevant capture sets — every module compiling that shape crashed in cc Setup
with `IllegalCaptureRef`. With the patch the alias keeps its `val` identity
and the summons capture-check as written.

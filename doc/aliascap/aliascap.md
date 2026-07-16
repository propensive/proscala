# Keep root capabilities global in type alias infos

Stops capture checking from localizing `caps.any` inside a type alias's own definition, fixing spurious "cannot flow into" errors when a non-capture-checked module's signature mentions a capability-carrying alias.

## Context

This patch touches `Setup.scala` in the capture-checking subsystem (`dotty.tools.dotc.cc`). Capture checking is Scala 3's experimental effect/resource tracking: types can carry a *capture set* (`Foo^{io}`) listing the capabilities a value may use. The *root capability* `caps.any` (written `^`) means "may capture anything". During the Setup phase, before rechecking, the compiler rewrites each symbol's declared type: among other things, `globalCapToLocal` replaces global occurrences of `caps.any` with a `LocalCap` — a fresh capability *owned by* that symbol, so that scoping rules can decide which capabilities may flow into it.

A wrinkle is separate compilation: only units compiled with capture checking enabled go through Setup. Symbols from other units get their signatures "fluidified" (made permissive) on the fly at use sites — and that fluidification does **not** follow type aliases.

## The problem

`Setup.transformExplicitType` localized `caps.any` in *every* symbol's info, including type aliases such as:

```scala
infix type raises [T, E <: Exception] = Tactic[E]^ ?=> T
```

Within capture-checked code this is harmless: Setup expands aliases at each *using* symbol, minting a `LocalCap` owned by the use-site symbol, so the alias's own info is never consulted. But when a method comes from a unit that was **not** capture-checked and its signature spells its result through the alias, fluidification keeps the alias unexpanded. Rechecking dealiases only later — and then meets the `LocalCap` owned by the alias itself, a capability rooted at the alias's (package-)level. No capability from the call site can ever flow into it, so applying such a method fails:

```scala
// Library compiled WITHOUT capture checking:
def parse(s: String): Int raises ParseError = ...

// Client compiled WITH capture checking:
val n = parse("42")   // error:
// Found:    (contextual$1 : Tactic[ParseError])
// Required: Tactic[ParseError]^{any}
// ... not visible from any in type raises
```

The contextual `Tactic` capability provided at the call site cannot be proven to flow into a `LocalCap` pinned to the alias declaration, even though the call is perfectly safe.

## The solution

Skip localization for type aliases: leave `caps.any` global in an alias's own info. Since capture-checked callees never read that info (aliases are expanded and localized per use site during their own Setup), this changes nothing for fully capture-checked code. For the mixed-compilation case, a *global* root in the late-dealiased signature is freshened by recheck per application — exactly what happens for capture-checked callees — so the use-site capability can satisfy it.

The commit notes a cosmetic diagnostic shift in three neg tests (`boundschecks2`, `boundschecks3`, `i19330`): explanatory notes now print "the root capability caps.any" instead of "a root capability in the type of type T"; the errors themselves are unchanged.

## Code

The entire patch is one new branch at the end of `Setup.transformExplicitType` (`compiler/src/dotty/tools/dotc/cc/Setup.scala`):

```scala
if initialVariance < 0 then tp2
else if sym.isAliasType then
  // Keep `caps.any` global in a type alias's own info. Capture-checked units expand
  // aliases during Setup of each USING symbol, localizing root capabilities per use
  // site, so the alias's own info is not consulted there. It is consulted when the
  // signature of a symbol from a unit that was NOT capture-checked mentions the alias:
  // such signatures are fluidified without following aliases, so rechecking dealiases
  // late and would expose a LocalCap owned by the alias itself — a capability at the
  // alias's own (package-)level that no use-site capability can flow into. Leaving the
  // root global here lets recheck freshen it per application, matching the behaviour
  // of capture-checked callees (mixed-compilation interop).
  tp2
else globalCapToLocal(tp2, Origin.InDecl(sym))
```

Previously every non-contravariant position fell through to `globalCapToLocal(tp2, Origin.InDecl(sym))`; now alias infos return `tp2` untouched, preserving the global root.

## Relevance to Soundness

The error in the commit message is Soundness's `raises` alias from Contingency, defined in `lib/contingency/src/core/contingency_core.scala`:

```scala
infix type raises [success, error <: Hazard] = Tactic[error]^ ?=> success
```

This alias appears in signatures throughout Soundness — e.g. `Zipfile.write` in Zeppelin, or Galilei's `def decode(text: Text): %.type raises PathError`. The reproduction `rep/capturing-raises/CapturingRaises.scala` in the Soundness repo documents exactly this failure ("capability `any` ... cannot flow into capture set {any} ... not visible from any in type raises") when calling `Zipfile.write` from capture-checked client code, affecting at least seven test suites (zeppelin, cordillera, burdock, perihelion, surveillance, ziggurat, contingency).

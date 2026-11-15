# Keep root capabilities global in type alias infos

Stops capture checking from localizing `caps.any` inside a type alias's own definition, fixing spurious "cannot flow into" errors when a non-capture-checked module's signature mentions a capability-carrying alias.

Enabled by `-Zalias-captures` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches.

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

## Keeping a lent parameter tracked

With the alias's root global, an alias of a capability can be used at all where a
type member is fixed only by a path. Without the flag, every use of this lending
method is rejected, even a harmless one:

```scala
trait Lender:
  type Result
  def lend[result](lambda: (handle: Result) ?=> result): result

class HandleLender extends Lender:
  type Result = Handle^
  def lend[result](lambda: (handle: Result) ?=> result): result = lambda(using Handle())

extension (x: Int)
  def lendDef[result](using lender: Lender^)(lambda: (handle: lender.Result) ?=> result): result =
    lender.lend(lambda)

def use(): Boolean = 1.lendDef(h ?=> h.alive)                   // accepted with the flag
def closure(): () => Boolean = 1.lendDef(h ?=> () => h.alive)   // must be rejected
```

The flag makes `use` compile, and that exposed a hole that the alias's own root had
been hiding. `closure` lets the handle escape the scope that lends it, and it was
accepted. The lambda's result goes into the capture set of `lendDef`'s type
argument `result`, through the dependent function type
`(handle: lender.Result) ?=> result`, after `handleLender` has been substituted
for `lender`. Capture-set variables are not copied by substitution: they are
mapped, and a capability added to the mapped set is mapped back to the original.
Mapped back, `handle` is the parameter of the *unsubstituted* function type,
whose type is the abstract `lender.Result`. That captures nothing, so `handle`
counted as pure, every set accounted for it, and it never reached the level check
that rejects it when the parameter is written `lender.Result^`.

So under the flag, a parameter that is tracked where it is added, but would not be
once mapped back, is not added. `closure` is now rejected (``capability `h` cannot
flow into capture set``), and `use` still compiles.

## Code

The alias branch at the end of `Setup.transformExplicitType`:

```scala
if initialVariance < 0 then tp2
else if sym.isAliasType && config.Proscala.enabled(config.Proscala.AliasCaptures) then
  tp2   // keep `caps.any` global in a type alias's own info
else globalCapToLocal(tp2, Origin.InDecl(sym))
```

and, in `CaptureSet.BiMapped.tryInclude`, the backward propagation to a mapped set's
source:

```scala
val sourceElem = bimap.inverse.mapCapability(elem)
if config.Proscala.enabled(config.Proscala.AliasCaptures) && lostTracking(elem, sourceElem)
then failWith(IncludeFailure(this, elem))
else source.tryInclude(sourceElem, this)
```

where `lostTracking` holds for a parameter that is tracked while its pre-image is
not. The tests are `{pos,neg}-custom-args/captures/aliascap-lend`.

## Relevance to Soundness

The error in the commit message is Soundness's `raises` alias from Contingency, defined in `lib/contingency/src/core/contingency_core.scala`:

```scala
infix type raises [success, error <: Hazard] = Tactic[error]^ ?=> success
```

This alias appears in signatures throughout Soundness — e.g. `Zipfile.write` in Zeppelin, or Galilei's `def decode(text: Text): %.type raises PathError`. Without the patch, calling such a method from capture-checked code (`Zipfile.write`, say) fails as above, in at least seven test suites. The lending method above has the shape of Aperture's `session`.

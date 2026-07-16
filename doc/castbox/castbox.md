# Box opaque-external type arguments in cast type applications

Makes the capture checker box the type arguments of undealiasable applied types (such as opaque types seen from outside) when they appear as the type argument of a cast, so the cast's spelling of the type matches its declaration-side spelling.

## Context

This patch lives in `compiler/src/dotty/tools/dotc/cc/Setup.scala`, the *setup* phase of capture checking. Under `-language:experimental.captureChecking`, types can carry capture sets (`T^{c}` means "a `T` that captures the capability `c`"). When a capturing type is used as a **type argument**, its capture set must be *boxed*: the captures are sealed inside the box so they don't leak through a generic type parameter, and are re-charged only when the value is unboxed. Setup walks every tree before rechecking and, among other things, boxes type arguments.

For an applied type whose type constructor **cannot be dealiased** — an abstract type, or an opaque type viewed from outside its defining scope — the boxing cannot be pushed into the (invisible) right-hand side, so Setup's `normalizeCaptures` boxes the arguments *as spelled*: `Tagged[T^{c}, L]` becomes `Tagged[box T^{c}, L]`. This is the canonical spelling that every declared type (e.g. a method's result type) receives.

## The problem

Type tests and casts (`isInstanceOf[T]` / `asInstanceOf[T]`) take a special path in Setup's `TypeApply` case: the cast's type argument is deliberately *not* boxed (it isn't a generic type argument), and skipped `normalizeCaptures` entirely. So if the cast's target is itself an opaque-external application like `Tagged[inst.type, L]`, the cast mints an **unboxed** spelling of a type whose canonical spelling has boxed arguments. When the two spellings meet during rechecking, comparison fails with errors like:

```
Found:    Tagged[(inst : TC[Int]^), "contextual"]
Required: Tagged[box (inst : TC[Int]^), "contextual"]
... is boxed but ... is not
```

Such casts arise without the user ever writing one: an opaque type's companion `apply` returns the opaque type, and when that (inline) method is inlined outside the opaque's scope, the inliner inserts an `asInstanceOf[Tagged[...]]` and binds results to proxies. Minimal reproduction:

```scala
import language.experimental.captureChecking
import scala.caps

object internal:
  opaque type Tagged[+value, tag] = value
  object Tagged:
    inline def apply[tag](value: Any): Tagged[value.type, tag] = value

trait Tactic extends caps.ExclusiveCapability

def demo(using t: Tactic): Unit =
  val inst: Object^{t} = new Object {}
  internal.Tagged["label"](inst)   // inlined: inst.asInstanceOf[Tagged[inst.type, "label"]]
  // error: Tagged[box (inst : Object^{t}), "label"] expected,
  //        but the cast produced the unboxed spelling
```

The bug only bites when the tagged value is a *capturing singleton* — a pure argument boxes to itself, so both spellings coincide.

## The solution

In Setup's cast branch, apply exactly the same rule `normalizeCaptures` applies to the same application everywhere else: if the cast's type argument is an `AppliedType` that does not dealias (and is not a function type), box each of its arguments deeply before recording the new type. The cast target itself remains unboxed, as before; only the *arguments inside it* get the treatment they would receive in any other position. This restores the invariant that a given undealiasable type application has one spelling, so the cast-produced type and the declaration-side type compare equal.

## Code

The whole patch is one hunk in the `TypeApply` case of Setup's traverser (`compiler/src/dotty/tools/dotc/cc/Setup.scala`):

```scala
if defn.isTypeTestOrCast(fn.symbol) then
  // Box the arguments of an undealiasable (e.g. opaque-external) type application
  // in a cast's type argument, exactly as `normalizeCaptures` does for the same
  // application elsewhere.
  val boxedArgs = arg.tpe match
    case tp @ AppliedType(tycon, args0)
    if !defn.isFunctionClass(tp.dealias.typeSymbol) && (tp.dealias eq tp) =>
      tp.derivedAppliedType(tycon, args0.mapConserve(_.boxDeeply))
    case tp => tp
  arg.setNuType(
    globalCapToLocal(boxedArgs, Origin.TypeArg(arg.tpe)))
else
  transformTT(arg, NoSymbol, boxed = true, typeArgFormal = formal)
```

The guard `!defn.isFunctionClass(...) && (tp.dealias eq tp)` is copied verbatim from the `AppliedType` case of `normalizeCaptures` (same file), which is what makes the fix correct by construction: casts now produce the same normal form as every other occurrence of the type.

## Relevance to Soundness

Soundness's Denominative library defines exactly this pattern — `lib/denominative/src/core/denominative.protointernal.scala`:

```scala
object protointernal:
  opaque type Tagged[+value, tag] = value
  object Tagged:
    inline def apply[tag](value: Any): Tagged[value.type, tag] = value
```

with the user-facing `aka` in `denominative_core.scala`:

```scala
infix type aka [subject, label <: Label] = denominative.protointernal.Tagged[subject, label]

extension (any: Any)
  inline def aka[label <: Label]: any.type aka label = denominative.protointernal.Tagged[label](any)
```

Soundness tags capability-capturing contextual instances, e.g. `inst.aka["contextual"]` where `inst: TC[Int]^` (see the distilled reproduction in `rep/proxy-tagged/ProxyTagged.scala` in the Soundness checkout). Inlining `aka` inserts the companion `apply`'s cast to `Tagged[inst.type, "contextual"]`; before this patch, the inliner's proxy over that cast carried the unboxed spelling and the whole `x aka "label"` idiom failed to compile under capture checking whenever `x` captured anything.

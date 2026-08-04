# Give an inline accessor for a module the module's `TermRef`

Restores the stable result type of the synthetic accessor an inline method gets for a private object, so that a type reached through that object — `Positional.Profile` — is still a legal path once the method is expanded elsewhere.

## Context

An `inline def` is expanded at the call site, which may be anywhere. If its
body mentions something the call site cannot see, the compiler quietly adds a
**inline accessor** next to the definition — a public forwarder — and rewrites
the body to go through it. The mechanism is meant to be invisible: a library
can keep a helper private and still use it from an inline method.

Soundness's `stratiform` does exactly that. `Positional` is an implementation
detail, so it is `private[stratiform]`; the derivation that needs it is inline,
because it is generated per record type:

```scala
private[stratiform] object Positional:
  class Profile(...)

trait Tel2:
  object DecodableDerivation extends Derivable[Tel.Decodable]:
    inline def conjunction[derivation <: Product: ProductReflection]
    :   derivation is Tel.Decodable =
      lazy val profiles: Array[Positional.Profile]^{} = ...
```

The accessor is generated, but on the 3.10 stream the definition no longer
compiles:

```
-- Error: stratiform.Tel2.scala:280:32
280 |      lazy val profiles: Array[Positional.Profile]^{} =
    |                               ^^^^^^^^^^
    |    (Tel2.this.stratiform$Tel2$$inline$Positional : -> object stratiform.Positional)
    |    is not a legal path
    |    since it refers to nonfinal method stratiform$Tel2$$inline$Positional
```

`Positional.Profile` is a type *selected from a path*, so the prefix must be
stable — a value that always denotes the same thing. The rewritten prefix is a
call to the accessor, and a parameterless `def` is stable only if it cannot be
overridden. Here it can: `Tel2` is a trait, so its members are open, and the
compiler places the accessor in the trait alongside the inline method.

That last point is what makes the accessor's own type decide the outcome. A
module val's declared type is a `TypeRef` to its *module class* — `p.Positional`,
the class — rather than a `TermRef` to the module value — `p.Positional.type`,
the unique instance. Only the second is a singleton, and only a singleton
result rescues a non-final `def`: the realizability check accepts a member
whose type pins down a single value regardless of what an override might do.
Giving the accessor the module class means it promises only "some `Positional`",
so the check has nothing to fall back on and reports the accessor itself as an
illegal path.

## Reproduction

[`repro/`](repro/) — two files, no flags. Three things must coincide, and
dropping any one hides the bug: the object must be inaccessible at the
expansion site (otherwise no accessor is generated), the accessor must land in
a trait (otherwise it is final and stability is not in question), and the
selection must be in type position (that is where the check runs).

```scala
private[p] object Positional:
  class Profile(val name: String)

trait Host:
  object Derivation:
    inline def make(): Int =
      val profiles: Array[Positional.Profile] = Array(Positional.Profile("a"))
      profiles.length
```

## Solution

Five lines in `useAccessor` (`transform/AccessProxies.scala`), remapping the
accessed symbol's info before it becomes the accessor's result type:

```scala
val mappedInfo = accessed.info match
  case tref @ TypeRef(prefix, _) if tref.symbol.is(Module) =>
    TermRef(prefix, tref.symbol.companionModule)
  case other => other
val accessorInfo =
  mappedInfo.ensureMethodic.asSeenFrom(accessorClass.thisType, accessed.owner)
```

The remap fires only for a module — for anything else `accessed.info` is passed
through as before — and it does not widen or narrow what the accessor returns.
`p.Positional.type` and `p.Positional` denote the same object at runtime and
erase identically; the singleton simply records that there is only one, which
is what a path needs.

## Upstream

This is not a new idea: it is upstream's own fix for
[#22593](https://github.com/scala/scala3/issues/22593), added by 2c896f121b
(Chyb, 2025-05-09) with the comment *"TypeRef pointing to module class seems to
not be stable, so we remap that to a TermRef"*.

It was removed by 5321891783, *"Don't infer implicits from non-accessible
companion"* ([#25367](https://github.com/scala/scala3/pull/25367), Rytz,
2026-06-12) — a change about implicit search, not about accessors. That PR made
implicits in an inaccessible companion fail to be inferred at all, which turned
`tests/pos/i22593.scala` into an error case; it was rewritten as
`tests/neg/i22593a.scala`, and the remap, no longer needed by any remaining
test, went with it. But #22593 had two halves. The half about *inferring* an
implicit through a private object is now rejected earlier and for a different
reason; the half about *naming a type* through one was simply left broken, with
no test covering it.

The 3.9 stream branched before that removal and still carries the remap, which
is why this patch exists only for 3.10.

`tests/pos/i22593c` adds the missing coverage. Every test 5321891783 touched —
`tests/pos/i22593a`, `tests/pos/i22593b`, `tests/pos/i25347`,
`tests/neg/i22593a`, `tests/neg/i22593b`, `tests/neg/i25347`,
`tests/neg/i25347b` — still behaves exactly as marked under this patch, so
restoring the remap costs that PR nothing.

Worth reporting upstream, with the reproduction: the removal looks incidental
rather than intended, and the breakage is invisible until a library combines a
private object, an inline method and a trait.

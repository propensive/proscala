# Cache inert types in capture-checking Setup

Adds an identity-keyed cache of "inert" types (types that Setup maps to themselves) to the capture checker's Setup type map, turning an exponential re-traversal of deeply-nested alias unions into a linear one.

## Context

Before the capture checker proper runs, the `Setup` phase (`compiler/src/dotty/tools/dotc/cc/Setup.scala`) rewrites every type in the compilation unit into "capture-checking form": it decorates types with capture-set variables, normalizes function types to their dependent form, and follows type aliases so that capabilities hidden behind aliases are found. The workhorse is `SetupTypeMap`, a `TypeMap` mixing in `FollowAliasesMap`, whose `mapFollowingAliases` dealiases a type, transforms the expansion, and keeps the transformed result only if something changed.

Many types are *inert* under this transformation: they contain no capabilities, no function types to normalize — nothing for Setup to touch. Mapping them returns the identical (`eq`) instance. Singleton string types and unions of them are the canonical example.

## The problem

`FollowAliasesMap` has no memory. Every time an alias reference is encountered, its expansion is re-walked in full — even if that same alias (the same `TypeRef` instance) was already walked moments ago and found to be unchanged. When aliases nest, the cost compounds: an alias whose expansion mentions two other aliases triggers two full sub-walks, each of which re-expands *its* member aliases, and so on. The number of walks is exponential in the alias nesting depth, multiplied by the width of each union.

The trigger case is HTML content-category types: hundreds of shared singleton-string labels organized behind several layers of alias unions, e.g.

```scala
type Flow     = Heading | Phrasing | Sectioning | "address" | "blockquote" | ...
type Phrasing = Embedded | InteractivePhrasing | "abbr" | "area" | "b" | ...
type Embedded = "audio" | "canvas" | "embed" | "iframe" | "img" | ...
```

A single method signature mentioning such a type caused Setup to re-expand the shared lower-level aliases once per path through the alias graph. In practice, compilation of one such signature did not finish at all.

## The solution

`SetupTypeMap.apply` now records, per map instance, every type for which the map returned the identical instance, in a `java.util.IdentityHashMap`. On re-encounter, the type is returned immediately without re-walking. So each shared alias expansion is walked once instead of once per path, making the traversal linear in the size of the alias graph.

Why this is safe:

- **Identity keys, identity results.** A type is only cached when `tp1 eq tp`, i.e. the map provably had nothing to do, and lookup is by reference identity — no reliance on type equality semantics.
- **State-independence of inert types.** `SetupTypeMap` carries traversal state (`variance`, `isTopLevel`), which normally makes caching a `TypeMap` unsound. But a type mapped to the *identical* instance was fully traversed and nothing anywhere inside it needed transformation; that fact cannot change under a different variance or top-level flag, since those flags only influence *how* changes are made, not whether an untouched type acquires content to change.
- **Bounded lifetime.** The cache is a private field of each `SetupTypeMap` instance, so it lives only for one mapping pass and cannot leak stale results across compiler phases or runs.

## Code

The whole patch is in `apply` (`compiler/src/dotty/tools/dotc/cc/Setup.scala`, trait `SetupTypeMap`):

```scala
private val inertTypes = new java.util.IdentityHashMap[Type, Type]()

final def apply(tp: Type) =
  if inertTypes.containsKey(tp) then tp
  else
    val saved = isTopLevel
    if variance < 0 then isTopLevel = false
    try
      val tp1 = tp match
        case defn.RefinedFunctionOf(rinfo: MethodType) =>
          val rinfo1 = apply(rinfo)
          if rinfo1 ne rinfo then rinfo1.toFunctionType(alwaysDependent = true)
          else tp
        case _ =>
          innerApply(tp)
      if tp1 eq tp then inertTypes.put(tp, tp)
      tp1
    finally isTopLevel = saved
```

The pre-existing dispatch (refined-function normalization vs. `innerApply`) is unchanged; the patch only wraps it with the cache check on entry and the `eq`-guarded insertion on exit.

## Relevance to Soundness

This is exactly the shape of Honeycomb, Soundness's typesafe HTML library. In `/Users/propensive/work/soundness/lib/honeycomb/src/core/honeycomb.Whatwg.scala`, the WHATWG content categories are nested alias unions over singleton tag names:

```scala
type Flow =
  Heading | Phrasing | Sectioning | "address" | "blockquote" | "details" | "dialog" | "div" | ...

type Phrasing =
  Embedded | InteractivePhrasing | "abbr" | "area" | "b" | "bdi" | "bdo" | "br" | "cite" | ...

type Sectioning = "article" | "aside" | "nav" | "section"
type Heading    = "h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "hgroup"
```

These appear pervasively in tag definitions such as `Tag.container["article", Flow, Whatwg]()`, so nearly every signature in the module (and in downstream code that renders HTML) mentions one of these unions. Under capture checking, Setup's alias-following walk over these types was the pathological case described above; with the inert-type cache, each shared category is expanded once and Honeycomb compiles normally.

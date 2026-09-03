# Sanitize TypeBounds in `@retains` arguments to the top capability

Stops the capture checker from rejecting `@retains` annotations that contain a
`TypeBounds` — a range produced by deskolemizing an inferred result type — by
approximating the bounds with `caps.any`, the standard sound over-approximation
for a capability that cannot be named.

Enabled by `-Zretains-bounds` ([zflags](../zflags/zflags.md)); without it, upstream's code runs at every site this patch touches.

## Context

Under capture checking, a type's retained capabilities are recorded in an
`@retains(...)` annotation whose arguments must be *capabilities* — stable
references such as parameters, `this`, or `caps.any`. Several places in the
compiler already defend this invariant: `RetainingAnnotation.sanitize` maps a
`SkolemType` element (the unnameable "particular value of that argument" minted
when a dependent method is applied to an unstable argument) to
`SkolemType(Any)`.

There is a second way an illegal element can arrive. When `Namer` infers the
result type of a definition, `inferredResultType` runs it through
`deskolemized`, an `ApproximatingTypeMap`. An approximating map does not map a
skolem to a single type but to a **range** — a pair of lower and upper
approximations. As the map rebuilds the surrounding type, `derivedOrType`
merges the range with neighbouring capture-set elements, and
`derivedAppliedType`, unable to place a range in an argument position, re-packs
it as a **wildcard argument** of `@retains` — that is, a `TypeBounds`
(`>: lo <: hi`).

A `TypeBounds` is not a legal capability. Before the 3.9 line this crashed the
pickler ("no TypeBounds allowed"); now it surfaces when the annotation is
forced and converted to a capture set:

```
Illegal capture reference: >: (iterable : Iterable[Int]) ...
```

A user can neither write nor avoid this in source. The trigger is inferring the
result type of a definition whose capture set mentions a skolem — for example
the **export forwarder** of a `transparent inline` method, whose result type is
always inferred.

## Reproduction

Two files. `a.scala` defines a transparent inline extension method whose
inferred result depends on the (unstable) receiver:

```scala
package rud
extension [value](iterable: Iterable[value])
  transparent inline def annex[right](lambda: value => right) = iterable.map: item =>
    inline compiletime.erasedValue[value] match
      case _: Tuple => (item, lambda(item))
      case _        => (item, lambda(item))
```

`b.scala` re-exports it, forcing Namer to infer the forwarder's type:

```scala
package snd
export rud.annex
```

Compiled together with

```
scalac -Ycc-new -language:experimental.captureChecking -experimental a.scala b.scala
```

an unpatched compiler reports, at the `export` clause:

```
Illegal capture reference: >: (iterable : ...)
```

With the patch, both files compile.

## The solution

`sanitize` gains a case alongside the existing skolem one: a `TypeBounds`
element of a retains set is replaced by `caps.any`. In
`compiler/src/dotty/tools/dotc/cc/RetainingAnnotation.scala`:

```scala
override protected def sanitize(tp: Type)(using Context): Type = tp match
  case SkolemType(_) =>
    SkolemType(defn.AnyType)
  case _: TypeBounds =>
    // An ApproximatingTypeMap turned a retained element into a range ...
    // A TypeBounds is not a legal capability: it either crashes the pickler
    // ("no TypeBounds allowed") or surfaces as "Illegal capture reference" ...
    defn.Caps_any.termRef
  ...
```

This is sound for the same reason the skolem case is: capture sets are
covariant, and by the time the range reaches the annotation its upper bound has
already absorbed the surviving references, so widening the whole element to the
top capability makes checking more conservative, never less. In the motivating
cases the skolem's captures could not be recovered anyway — the range is an
approximation of a value that has no name.

## Relevance to Soundness

Soundness aggregates its libraries into a single `soundness` package by
re-exporting each module's API. Rudiments defines exactly the shape above —
the transparent inline `annex` extension on `Iterable` — and the `soundness`
package object re-exports it. Compiling the aggregation module under capture
checking failed at the export clause with the "Illegal capture reference"
error (Soundness issue #1410), even though `rudiments` itself compiled
cleanly: only the forwarder's freshly inferred type runs through
`deskolemized` and manufactures the bounds. With the patch the re-export — and
with it the `soundness` umbrella — capture-checks again.

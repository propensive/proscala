# Guard against cyclic types in boxDeeply

Stops the capture checker's `boxDeeply` from recursing without bound — a stack overflow in the compiler — when an annotated type's parent dealiases back to the same annotated type, or a tracked singleton's capturing type collapses back to the singleton.

Always on: it only turns a compiler crash into a compilation.

## Context

Capture checking *boxes* a type whose capture set cannot be tracked precisely where it appears — inside an invariant type argument, a type member, the result of a function type — by wrapping it in a capture set to be solved later. `CaptureOps.boxDeeply` (`compiler/src/dotty/tools/dotc/cc/CaptureOps.scala`) does this for a type and, through the function types nested in it, for their results. The capture-checking Setup phase calls it when it normalises the captures of a type argument or a type's bounds (`normalizeCaptures`), when it transforms an explicit type that is to be boxed, and when it transforms an inferred result type (`transformResultType`).

`boxDeeply` is a recursion over the structure of the type. Two of its cases recurse on something *derived* from the type rather than on a proper part of it. For an annotated type that is not a capture annotation, it boxes the parent and re-attaches the annotation:

```scala
case tp @ AnnotatedType(parent, ann) =>
  tp.derivedAnnotatedType(parent.boxDeeply, ann)
```

and for a tracked singleton — a reference to a capability — it recurses on the capturing type it makes of the singleton:

```scala
case tp: (Capability & SingletonType) if tp.isTrackableRef && !tp.isAlwaysPure =>
  recur(CapturingType(tp, CaptureSet(tp)))
```

Each step first dealiases what it is given (`dealiasKeepAnnotsAndOpaques`), which follows type aliases and forces `LazyRef`s.

## The problem

Neither case can tell when it has come back to where it started. If the parent of an annotated type dealiases to that same annotated type again — which a type alias cannot spell, but a cyclic graph of `LazyRef`s can produce, exactly the shape [lazycycle](../lazycycle/lazycycle.md) guards `SetupTypeMap` against — the first case re-enters `boxDeeply` on the parent, which dealiases to the annotated type, whose parent is boxed again, and so on. If `CapturingType(tp, CaptureSet(tp))` hands back `tp` itself (as `CapturingType.apply` does when the capture set it is given is judged empty), the second case re-enters `recur` with the type it had. Either way the compiler dies:

```
[error] Stack overflow in the compiler.
See https://docs.scala-lang.org/overviews/compiler-options/compiling-deeply-nested-code.html
Stack trace:
dotty.tools.dotc.cc.CaptureOps$package$.recur$1(CaptureOps.scala:253)
  dotty.tools.dotc.cc.CaptureOps$package$.boxDeeply(CaptureOps.scala:273)
  dotty.tools.dotc.cc.CaptureOps$package$.recur$1(CaptureOps.scala:253)
  dotty.tools.dotc.cc.CaptureOps$package$.boxDeeply(CaptureOps.scala:273)
  …
```

No stack is deep enough: the trace is the same two frames alternating, at 2 MB and at 64 MB alike.

Soundness exercises this. The `core` module of [flame](https://github.com/propensive/flame), compiled against Soundness 0.72.0 with Proscala 1.0.1's Scala 3.10.0 build, overflows exactly so, before the first unit is checked (`-Ycc-log` prints nothing); it compiled under Proscala `3.9.1-dev-p20` against Soundness 0.71.0. The type that closes the cycle has not yet been distilled from it (see `repro/FIXME.md`).

## The solution

`boxDeeply` keeps the set of types it is currently boxing, as a traversal-local `util.HashSet[Type]`, and records each type it descends into together with its dealiasing. A type met again on the way down is returned unboxed: it is already being boxed further up, and nothing new remains to box in it. The annotated-type case boxes its parent through a local helper that keeps the existing rule for method types (their results are not boxed outside refinements), so for every acyclic type the result is exactly what it was.

```scala
val boxing = util.HashSet[Type]()
def recur(tp: Type): Type =
  val tp1 = tp.dealiasKeepAnnotsAndOpaques
  if boxing.contains(tp) || boxing.contains(tp1) then tp
  else
    boxing += tp
    boxing += tp1
    try recur1(tp, tp1)
    finally
      boxing.remove(tp)
      boxing.remove(tp1)
```

This is the same remedy as `lazycycle`'s, one level up: that guard stops `SetupTypeMap` from forcing a `LazyRef` cycle, and this one stops `boxDeeply` — which the map calls on the types it has produced, and which dealiases for itself — from walking the same cycle.

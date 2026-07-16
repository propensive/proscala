# Reproduction: boundscap

One line. Compile on the **3.8 stream** with separation checking:

```
scalac -language:experimental.captureChecking -language:experimental.separationChecking repro.scala
```

Without the patch, capture-checking Setup wraps the refinement member
`type Bcd = Array[Double]` (whose right-hand side classifies as a mutable
capability under strict mutability, via 3.8's `isArrayUnderStrictMut`
disjuncts) in a `CapturingType`, and rebuilding the `RefinedType` crashes:

```
java.lang.AssertionError: assertion failed: RefinedType(TypeRef(...,AnyRef),Bcd,
  AnnotatedType(TypeAlias(AnnotatedType(Array[Double], {any.rd})), {any.rd}))
  at dotty.tools.dotc.core.Types$RefinedType.<init>
  at dotty.tools.dotc.cc.Setup...
```

With the patch, the file compiles.

Note: the feature doc records that a minimal reproduction via the *opaque
member* route (mimicking jacinta's structure) does not fire — the trick is to
write the refinement **explicitly** in a signature, which forces Setup's
explicit-type transform over the `TypeAlias` directly.

Verified against local `make`-branch builds of the 3.8 stream (2026-07-17):
crashes on `feature/3.8/make` (stock + build only), compiles on
`feature/3.8/boundscap` (= make + this patch alone). The 3.9/3.10 streams
never exhibit it (their classification maps arrays to `Caps_Mutable` inside
`derivesFromCapTrait`).

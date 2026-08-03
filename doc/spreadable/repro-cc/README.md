# Reproduction: capture-checker crash on an Array-flavoured pierce

Reproduces the `TypeBounds` assertion crash fixed by the "Cast Array-flavoured
pierces to the element's upper bound" commit on the patch branches then
named `spliceopaque`, now `spreadable`.

`repro.scala` splices a covariant opaque alias over `scala.IArray` into a
vararg position in a module compiled with `-Ycc-new`. `IArray[T]` uncovers as
`Array[? <: T]`, so the original pierce cast to that wildcard form, whose
repeated translation is the wildcard-argument `(? <: T)*`. When the capture
checker re-translates that repeated type back to an array
(`translateFromRepeated`, `wildcardArg = true`), it wraps the element in
`TypeBounds.upper` — but the element already *is* a `TypeBounds`, and
constructing bounds-of-bounds trips the `TypeBounds` constructor assertion.

## To reproduce

Compile with:

    scalac -experimental -Ycc-new -language:experimental.captureChecking \
      -d out repro.scala

A compiler carrying the first version of the spliceopaque patch (releases up
to and including 3.8.4-p6 / 3.9.0-RC4-p6) crashes:

    java.lang.AssertionError: assertion failed: TypeBounds(...Nothing, ...Node)
      at dotty.tools.dotc.core.Types$TypeBounds.<init>
      at dotty.tools.dotc.core.Types$TypeBounds$.upper
      at dotty.tools.dotc.core.TypeApplications$.translateParameterized$extension
      ... from Recheck$Rechecker.isCompatible / CheckCaptures

## Expected behaviour (fixed compiler)

The file compiles cleanly: the pierce now casts to `Array[T]` (same erasure),
whose repeated translation `T*` round-trips through the capture checker.

Stock upstream rejects the splice with a type error at the same position
(`Found: IArr[Node], Required: Seq[Node] | Array[? <: Node]`), since it has no
such elaboration; the crash needed the opaque to be let through. Without
`-Ycc-new` the original pierce also compiled — the wildcard repeated type only
breaks under the capture checker's re-checking pass.

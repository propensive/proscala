# FIXME: no self-contained reproduction yet

The cycle is reproduced by a real project rather than by standalone files:

- Check out propensive/soundness at `09a0acbc7c` (main, 2026-10-19) with its `build.mill` on
  Proscala 1.0.1's Scala 3.10.0 build and run a clean
  `./mill --no-daemon -j 6 soundness.native.compile`; in about one run in three,
  `quantitative.core.native.compile` fails with `Cyclic reference involving class SourceFile`
  (with `cyclicctx`; the `bringForward` assertion without it) in `scalanative-genNIR` on
  `quantitative.MetricPrefix.scala`, with `-explain-cyclic` showing the stack in
  `movestatics.md`. It does not reproduce by compiling the module's 25 sources alone with
  `dotty.tools.dotc.Main` and the same options (0 of 10), nor by recompiling the one module under
  mill (0 of 3): what varies between runs has not been pinned down.

A standalone reproduction needs a run whose first request for the base classes of an annotation
class comes at a phase after `MoveStatics`: a compilation with suspended units (a macro defined
and used in the same compilation), and a late phase that asks `hasAnnotation` of a library class
— Scala Native's `genNIR` does, through `isStruct`, for every class it instantiates; the JVM
backend has no such query, so the reproduction needs `nscplugin` on the `-Xplugin` path.

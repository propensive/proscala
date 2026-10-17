# FIXME: no self-contained reproduction yet

The overflow is reproduced, deterministically, by a real project rather than by
standalone files:

- Check out propensive/flame at `pins/pyrocosm-0.7.1` with its `build.mill` on
  Proscala 1.0.1's Scala 3.10.0 build (`3.10.0-pro-1.0.1`) and its pins at
  Soundness 0.72.0 and Pyrocosm 0.7.1, and run `./mill flame.core.compile`.
- The compiler dies with `Stack overflow in the compiler`, the trace alternating
  `CaptureOps.recur` (the generic `AnnotatedType` case) and `boxDeeply`, before
  the first `cc check <unit>` line that `-Ycc-log` prints — so the cycle is met
  while Setup transforms the first symbol infos it touches, not inside a unit.
- It happens with every `-Z` flag removed in turn, and with 64 MB of thread
  stack; without this patch's guard the compiler built from this tree overflows
  identically, and with it `flame.core` compiles.

What has not been found is the type that closes the cycle. Removing files or
imports from `flame.core` produces typer errors first, which stop compilation
before capture checking and so hide the overflow; distilling the shape needs a
probe inside the compiler (a `Thread.dumpStack()` at the `recur` guard's hit)
rather than bisection of the source. The ingredient is presumably the one
`lazycycle` names — denotations surviving a suspension re-run — since `flame.core`
derives type-class instances for its own case classes in the same run.

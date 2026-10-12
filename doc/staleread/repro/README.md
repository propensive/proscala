# Reproduction: staleread

Two files, compiled together in one run with no extra classpath:

- `Macro.scala` — a macro implementation, `Macro.succ`;
- `Use.scala` — enables `language.experimental.captureChecking`, defines an
  `inline def succ` that splices `Macro.succ`, and calls it next to a
  `new TreeSet[Int]()`, a TASTy-loaded collection from the standard library.

`Macro` is not compiled yet when `Use.scala` reaches inlining, so the compiler
suspends `Use.scala` and re-compiles it in a fresh run once `Macro` exists.
Capture checking of the re-run then reads a denotation in the `TreeSet`
hierarchy through a context from the earlier run, after the newer run has
already brought that denotation forward.

```
scalac -d . Macro.scala Use.scala
```

Without the patch (stock Scala 3.9.0), the compiler crashes during capture
checking (after a cascade of `error while rechecking ...` lines):

```
java.lang.AssertionError: assertion failed:
  denotation trait SortedSetFactoryDefaults invalid in run 2. ValidFor: Period(3.1-39)
  at ...Denotations$SingleDenotation.updateValidity
  at ...Denotations$SingleDenotation.bringForward
  at ...Denotations$SingleDenotation.toNewRun$1
  at ...Denotations$SingleDenotation.current
```

With the patch, it compiles.

All three ingredients are needed: without the `captureChecking` import, or
with the `TreeSet` swapped for a `HashSet`, stock compiles it. Which trait is
named varies with the code (an `identity` macro instead names
`IterableFactoryDefaults`); `test.sh` matches any.

How it was found: this replaces an earlier 700-line reduction of Soundness's
`gossamer.core`, which needed that module's classpath at an old commit. Its
only collection use was a `new scm.BitSet(n)` in a capture-checked file that
also expanded a same-run macro; rebuilding just that shape from scratch
reproduced the crash directly (`new mutable.BitSet` and `new mutable.TreeSet`
crash too).

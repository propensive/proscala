# Reproduction: staleread

A 13-file, ~700-line reduction of Soundness's `gossamer.core` module
(automated block-level reduction from the original 22 files / ~4,800 lines).
`gossamer.internal.scala` defines macros used by `gossamer_core.scala` in the
**same compilation**, forcing a suspension and re-run; capture-checking Setup
in the re-run then reads collection-hierarchy denotations already brought
forward to the newer run.

It needs the compile classpath of Soundness's `gossamer.core` module
(Soundness commit `211be67b5`, built with a patched toolchain):

```
cd <soundness>; ./mill show gossamer.core.compileClasspath   # → classpath
scalac -experimental -new-syntax -preview -Xmax-inlines 32 -Yno-flexible-types \
  -Yexplicit-nulls -language:experimental.modularity ... (the repo's standard set) \
  -Yno-predef -Yimports:java.lang,scala,proscenium \
  -Ycc-new -language:experimental.captureChecking \
  -classpath <classpath> src/*.scala
```

Without the patch, the compiler crashes:

```
java.lang.AssertionError: assertion failed:
  denotation trait SortedSetFactoryDefaults invalid in run 2. ValidFor: Period(3.1-42)
  at ...Denotations$SingleDenotation.updateValidity
  at ...Denotations$SingleDenotation.bringForward
  at ...Denotations$SingleDenotation.toNewRun$1
  at ...Denotations$SingleDenotation.current
```

With the patch, it compiles.

Because the classpath needs the other fork patches to build at all, the
verified differential is **trunk/3.9 vs trunk-minus-staleread** (trunk with
only the 9-line Denotations guard reverted): CRASH on trunk-minus-staleread
(3× deterministic with batch scalac; no compiler plugins needed), PASS on
trunk/3.9 (2026-07-17). Note the whole-of-Soundness differential also
reproduces this at `gossamer.core` under Mill.

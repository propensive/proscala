# Reproduction: rootclassify

One file, compiled alone:

```
scalac -experimental -Ycc-new -language:experimental.separationChecking mixed.scala
```

Without the patch the compiler crashes while rechecking the inlined proxy value:

```
error while rechecking val x$proxy1: Holder^{} = holder(throwing[Any], new Sink():(Sink^)) against <?>
java.lang.AssertionError: assertion failed: attempting to add any to {any} of value x$proxy1
  dotty.tools.dotc.cc.CaptureSet$VarInTypeTree.hideIn$1(CaptureSet.scala)
  dotty.tools.dotc.cc.CaptureSet$VarInTypeTree.normalizeLocalCaps(CaptureSet.scala)
  dotty.tools.dotc.cc.CheckCaptures$CaptureChecker.interpolateIfInferred(CheckCaptures.scala)
```

With the patch the file compiles.

Verified against a local `make` build of the 3.9 stream (2026-10-07): crashes on
`release/3.9` (3.9.1-dev-p17), compiles on `scratch/sharedunscoped`.

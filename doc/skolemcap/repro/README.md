# Reproduction: skolemcap

A 14-line source file — but it needs the Soundness classpath, matching the
feature doc's observation that the skolem only arises in a sufficiently deep
inline/`summonInline` chain (small self-contained models compile cleanly).
The chain here is superlunary's `Rig.dispatch` → `stageable.extract` →
proscenium's `provide[entity is Decodable in Json]` → `lambda(using
infer[context])`.

Compile `repro.scala` with the compile classpath of Soundness's
`ethereal.test` module (Soundness commit `211be67b5`, built with a patched
toolchain):

```
cd <soundness>; ./mill show ethereal.test.compileClasspath   # → classpath
scalac -experimental -new-syntax -preview -Yno-flexible-types -Yexplicit-nulls \
  -language:experimental.modularity ... (the repo's standard option set) \
  -Yno-predef -Yimports:java.lang,scala,proscenium \
  -Ycc-new -language:experimental.captureChecking \
  -classpath <classpath> repro.scala
```

Without the patch, compilation fails with:

```
Illegal capture reference: (?1 : Any)
  Inline stack trace:
  ... inlined from proscenium_core.scala:104:  lambda(using infer[context])
  ... provide[entity is Decodable in Json](json.as[entity])
  ... stageable.extract[output]: ...
```

With the patch, it compiles.

Because the classpath needs the other fork patches to build at all, the
verified differential is **trunk/3.9 vs trunk-minus-skolemcap** (trunk with
only the 9-line skolemcap hunk reverted), not stock-vs-single-feature:
CRASH on trunk-minus-skolemcap (3× deterministic), PASS on trunk/3.9
(2026-07-17). Derived by reduction from `ethereal_test.scala`, whose full
669-line version fails identically.

# Reproduction: retainbounds

Compile both files together with:

```
scalac -Ycc-new -language:experimental.captureChecking -experimental \
  a.scala b.scala
```

Without the patch, compilation fails at the `export` clause in `b.scala`
with an illegal capture reference whose "reference" is a bounds range —
the deskolemized capture-set element re-packed as a wildcard argument of
`@retains`:

```
Illegal capture reference: >: (iterable : ...)
```

With the patch, both files compile.

Both ingredients are necessary: the `transparent inline` extension method in
`a.scala` gives the forwarder a skolem-bearing inferred capture set, and the
`export` in `b.scala` is what makes Namer infer (and deskolemize) a fresh
result type for it — `a.scala` alone compiles either way.

Derived by reduction from Soundness issue #1410 (`rudiments`' `annex`
re-exported into the `soundness` package).

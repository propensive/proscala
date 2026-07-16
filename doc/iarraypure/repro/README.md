# Reproduction: iarraypure

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking -Ycc-new repro.scala
```

Without the patch, every right-hand side is inferred as `IArray[...]^{fresh}`
(as if a mutable array had just been allocated) and fails to conform to the
declared pure `IArray[...]` types.

With the patch, the file compiles. `repro.scala` is the test the patch adds at
`tests/pos-custom-args/captures/iarray-pure.scala`, copied verbatim.

# Reproduction: dictcaps

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, the memoized recursive-implicit dictionary instance fails
capture checking with:

```
Found:    $_lazy_implicit_$3^{c, any}
Required: $_lazy_implicit_$3
```

With the patch, the file compiles. `repro.scala` is the test the patch adds at
`tests/pos-custom-args/captures/dictcaps.scala`, copied verbatim.

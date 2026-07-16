# Reproduction: castbox

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, compilation fails with a boxed/unboxed spelling mismatch of
the form:

```
Found:    Tagged[(inst : Object^{t}), "label"]
Required: Tagged[box (inst : Object^{t}), "label"]
... is boxed but ... is not
```

With the patch, the file compiles. The snippet is extracted verbatim from
[the feature doc](../castbox.md).

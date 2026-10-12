# Reproduction: castbox

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, compilation fails with a boxed/unboxed spelling mismatch.
Stock Scala 3.9.0 prints the boxed argument without the `box` marker; `-explain`
shows the comparison failing as a "boxed mismatch":

```
-- [E007] Type Mismatch Error: repro.scala:14:9
14 |  expect(internal.Tagged["label"](inst))   // inlined: ...
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |Found:    internal.Tagged[(inst : Object^{t}), ("label" : String)]
   |Required: internal.Tagged[(inst : Object^{t})^{inst}, ("label" : String)]
```

With the patch, the file compiles. The snippet is the one in
[the feature doc](../castbox.md), except that the cast's result is passed to
`expect`, whose declared parameter type carries the canonical (boxed) spelling:
the two spellings must meet for the mismatch to show, and a bare call in
statement position is never compared against anything.

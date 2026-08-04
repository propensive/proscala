# Reproduction: blockimport

Compile with:

```
scalac -Yexplicit-nulls -Yno-flexible-types repro.scala
```

Capture checking is switched on by the file's own
`import language.experimental.captureChecking`, so no further flag is needed.
All three flags matter: without `-Yexplicit-nulls` there is nothing for
`unsafeNulls` to relax, without `-Yno-flexible-types` a Java method's result is
a flexible type that adapts on its own, and without capture checking the recheck
never runs.

Without the patch, on either stream, the `val direct` line compiles and every
line below it fails:

```
-- [E007] Type Mismatch Error: repro.scala:22:42
22 |      val inLoop: String = input.substring(0, 1)
   |                                          ^^^^^
   |                           Found:    String | scala.Null
   |                           Required: String
```

That contrast is the whole file: `direct` and `inLoop` are the same expression
with the same import in scope, and only the first is accepted. `direct` is one
of the block's *statements*; `inLoop` is inside the `while`, which is the
block's *result expression*.

With the patch, the file compiles.

Both streams need it: `Recheck.scala` is identical in `upstream/3.9` and
`upstream/3.10`, and the patch applies to each unchanged.

`repro.scala` is the test the patch adds at
`tests/explicit-nulls/unsafe-common/unsafe-nulls-block-expr.scala`, copied
verbatim.

# Reproduction: integratemap

Compile **both files in the same compilation** (the macro being defined and
used together forces a suspension into a second compiler run):

```
scalac Internal.scala Amount.scala
```

No experimental flags are needed. Without the patch, the compiler crashes
after the suspension/retry cycle with:

```
java.lang.AssertionError: assertion failed:
  denotation value x invalid in run 2. ValidFor: Period(3.1-40)
```

With the patch, both files compile. The snippets are extracted verbatim from
[the feature doc](../integratemap.md).

**Not a working reproduction.** Checked 2026-10-12, this pair compiles on
stock 3.10.0 too (the suspension does happen — `-Xprint-suspension` shows
`Amount.scala` retried — but no `LazyRef` built by `IntegrateMap` is forced in
run 2). The crash needs such a lazy type, made in run 1 in a unit that is *not*
suspended, to be forced after the retry; the Quantitative sources it was
reduced from have that, this sketch does not. `test.sh` therefore checks only
that the patched compiler accepts it.

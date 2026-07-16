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

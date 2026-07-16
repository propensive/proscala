# Reproduction: inlineupdate

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking -language:experimental.separationChecking repro.scala
```

Without the patch, the synthetic inline accessors generated for the private
members referenced from `next()` are not classified as update methods, and the
exclusivity check fails with:

```
the access is in method inline$..., which is not an update method
```

With the patch, the file compiles. The snippet is extracted verbatim from
[the feature doc](../inlineupdate.md).

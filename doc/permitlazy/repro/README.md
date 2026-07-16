# Reproduction: permitlazy

Compile `repro.scala` on **JDK 25** (the `java.lang.classfile` API is the
sealed-interface web that triggers the cycle); no special flags:

```
scalac repro.scala
```

Without the patch, compilation fails with:

```
Cyclic reference involving class BufferedMethodBuilder
```

(reported upstream as scala/scala3#25451). With the patch, the file compiles.
The snippet is extracted verbatim from [the feature doc](../permitlazy.md).

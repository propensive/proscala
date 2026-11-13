# Reproduction: fuelslots

A program that uses the compiler as a library: it parses a sum of `n` terms
and counts the nodes of the tree, with a `ContextBase` that is never
initialized. Compile it against the compiler and run it:

```
scalac -classpath <compiler jars> -d . Repro.scala
java -cp .:<compiler jars> Repro 5
java -cp .:<compiler jars> Repro 12
```

Without the patch — upstream 3.10.0, 3.10.1 and `main` — five terms work and
twelve do not:

```
terms 5 nodes 17
Exception in thread "main" dotty.tools.dotc.core.RecursionOverflow
```

(The exception has no message and no stack trace, by design: it is meant to be
caught by the compiler and reported from the operations it recorded.)

With the patch:

```
terms 12 nodes 38
terms 200 nodes 602
```

Upstream 3.9 is unaffected: there the limit on recursion is the JVM's stack,
not an array of recorded operations.

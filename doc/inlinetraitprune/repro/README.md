# Reproduction: inlinetraitprune

Two files, compiled together, with `-experimental
-language:experimental.inlineTraits`. `counter.scala` declares an inline trait;
`reader.scala` only uses it, calling a method on a value of its type. Nothing is
read from TASTy.

```
F="-experimental -language:experimental.inlineTraits"
scalac $F -d a reader.scala counter.scala     # fails without the patch
scalac $F -d b counter.scala reader.scala     # compiles
```

Without the patch — upstream 3.10.0 and 3.10.1; `main` fixed it in #27302 — the
first order fails in the backend:

```
Concrete method has no definition: def advance(): Unit
```

and the second compiles: the same two files, in the other order. With the patch
both do.

It is the order of the *units*, so recompiling a whole classpath from TASTy
(`scalac -from-tasty a/**/*.tasty`), where the order is whatever the file system
gives, met it too.

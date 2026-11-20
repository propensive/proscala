# Reproduction: opaqueself

No `-Z` flag; capture checking and separation checking are on:

```
CC="-Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking"
scalac $CC -d out lib.scala
scalac $CC -cp out -d out first.scala
scalac $CC -cp out -d out client.scala
```

`lib.scala` defines an opaque alias of `scala.Array` and, in its companion, two
methods: `size`, and `boxed`, whose result holds a frozen array in a type
argument, `Box[Array[E]^{}]`. It is compiled once; the other two files are
compiled against its TASTy.

`first.scala` calls `Array.boxed` and compiles, with or without the patch.

`client.scala` makes the same call after calling `Array.size`. Without the patch
it is rejected:

```
-- [E007] Type Mismatch Error: client.scala:6:13
6 |  Array.boxed(xs)
  |  ^^^^^^^^^^^^^^^
  |Found:    lib.Box[Array[Int]^{any.rd}]
  |Required: lib.Box[lib.Array²[Int]]
  |
  |Note that capability `any.rd` cannot flow into capture set {}.
  |
  |where:    Array  is a class in package scala
  |          Array² is a type in the top-level definitions in package lib with bounds <: [E] =>> Any
  |          any    is a root capability classified as Unscoped created in method client when
  |                 instantiating method boxed's type (xs: lib.Array²[Int]): lib.Box[Array[Int]^{fresh.rd}]
```

The note shows `boxed`'s result read as `Box[scala.Array[Int]^{fresh.rd}]`: the
alias seen through, and its empty capture set replaced. With the patch both
files compile. Upstream 3.9.0, 3.10.0 and 3.10.1 behave the same as Proscala
without the patch, and the `-Z` flags Soundness uses (`-Zopaque-mutability`,
`-Zfrozen-pure`) make no difference to it.

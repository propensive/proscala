# Reproduction: unioncaps

Compile the single file with no flags at all:

```
scalac repro.scala
```

The two `language.experimental` imports in the file are the entire
configuration, and both are needed: without `separationChecking` there is no
strict mutability and the file compiles unpatched.

Without the patch, compilation fails at the binding of `r`: the union has
lost the `^{}` its `Array` members were declared with, acquired a fresh
capability at this occurrence instead, and that fresh classifies as `Any`
rather than `Unscoped`, so it cannot be re-absorbed at the local binding:

```
-- [E007] Type Mismatch Error: repro.scala:7:13 --------------------------------
7 |    val r = m()
  |            ^^^
  |Found:    (Int | Array[Int] | Array[Long])^{any.rd}
  |Required: (Int | Array[Int] | Array[Long])^'s1
  |
  |Note that capability `any.rd` is not classified as trait Unscoped, therefore it
  |cannot flow into capture set 's2 of Unscoped elements.
  |
  |where:    any is a root capability created in value r when instantiating method m's type (): (Int | Array[Int] | Array[Long])^{fresh.rd}
  |
  | longer explanation available when compiling with `-explain`
1 error found
```

With the patch, the file compiles. Replacing the union with a bare
`Array[Int]^{}` makes the unpatched compiler accept the file — the union is
the discriminating trigger.

Derived by reduction from jacinta's JSON representation type (a wide
primitive-and-array union); the same mechanism broke bitumen's
`Optional[Data]` (`Unset | Array[Byte]^{}`) at `TarBody.pull` in
`bitumen.Tarfile`, which does not reduce to a standalone file as cleanly.

# Reproduction: readonlyadapt

One file; capture checking, and `-experimental` for the `caps.Mutable` API.

```
scalac -experimental repro.scala
```

Without the patch — upstream 3.9.0, 3.10.1 and `main` alike — the compiler
crashes in the capture checker on the first definition:

```
unhandled exception while running cc on repro.scala
Exception in thread "main" java.util.NoSuchElementException: key not found:
  TypeRef(TermRef(ThisType(TypeRef(NoPrefix,module class <root>)),object scala),Nothing)
    at dotty.tools.dotc.cc.Mutability$.adaptReadOnlyToExpected(Mutability.scala:232)
```

With the patch the file compiles.

The ingredients are a `Mutable` class, a reference to it passed where a
read-only one is expected (`Ref^{r.rd}`), and a constructor whose class is not
the expected type's and which leaves one of its own type arguments alone:
`Right[Nothing, Ref^{r}]` against `Either[Int, Ref^{r.rd}]`. `left` and `either`
are the same thing through `Left` and through an `if`.

`repro.scala` is the test the patch adds at
`tests/pos-custom-args/captures/mutability-partial-improve.scala`, with the
language import the test directory otherwise supplies.

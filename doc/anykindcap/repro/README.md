# Reproduction: anykindcap

Compile `repro.scala` with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, on the 3.10 stream, both the `anyKindBound[Int => Int]` call
and the `TypeRepr.of[Int => Int]` fail:

```
-- [E223] CaptureChecking Error: repro.scala:12:31
12 |  def impureViaAnyKind = anyKindBound[Int => Int]
   |                                      ^^^^^^^^^^
   |          Reference `any` is not included in the allowed capture set {}
   |          of the type parameter bound scala.AnyKind.
```

The `anyBound[Int => Int]` call immediately below — identical except that its
type parameter is bounded by `Any` rather than `AnyKind` — compiles either way.
That pair is the whole point of the file: the two bounds say equally little
about captures, so they should behave the same.

With the patch, the file compiles.

The 3.9 stream compiles it unpatched: the check was introduced upstream after
3.9 branched, so only 3.10 needs this.

`repro.scala` is the test the patch adds at
`tests/pos-custom-args/captures/anykind-capset.scala`, copied verbatim.

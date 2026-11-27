# Reproduction: proxywrite

Compile the single file with:

```
scalac -experimental repro.scala
```

Without the patch, on scala/scala3 3.10.2-RC1 or later, compilation fails at
the assignment in `test`, which expands the inline extension method `update`:

```
-- Error: repro.scala:16:2 -----------------------------------------------------
16 |  arr(1) = ""
   |  ^^^^^^^^^^^
   |Cannot call update method update of (arr : p.Arr[String]^) & $proxy1.Arr[String]
   |since its capture set {} of value $proxy1 is read-only.
1 error found
```

With the patch, the file compiles. Scala 3.10.0 and 3.10.1 compile it
unpatched.

The trigger is an `inline` method whose receiver has an opaque alias of
`scala.Array` as its type, expanded where the alias is opaque: the inliner then
casts the receiver to the intersection of its own singleton type and its type
as seen through a proxy of the alias's prefix.

Reduced from Soundness's `proscenium.Array` (Proscala issue 64).

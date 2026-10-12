# Reproduction: iarraypure

Compile `repro.scala` with:

```
scalac -language:experimental.separationChecking -Ycc-new repro.scala
```

Separation checking (which implies capture checking) is what turns on strict
mutability, under which `Array` — and hence, unpatched, `IArray` — is classified
as mutable; with capture checking alone the file compiles either way. (The
`pos-custom-args/captures` suite adds the same flag.) The patch is gated: pass
`-Zpure-iarrays` too.

Without the patch, every right-hand side is inferred as `IArray[...]^{fresh}`
(as if a mutable array had just been allocated) and fails to conform to the
declared pure `IArray[...]` types:

```
Found:    IArray[Int]^{any}
Required: IArray[Int]
```

With the patch, the file compiles. `repro.scala` is the test the patch adds at
`tests/pos-custom-args/captures/iarray-pure.scala`, copied verbatim.

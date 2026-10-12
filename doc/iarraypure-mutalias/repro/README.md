# Reproduction: iarraypure-mutalias

Compile `repro.scala` with:

```
scalac -experimental -Ycc-new -language:experimental.separationChecking repro.scala
```

Separation checking is needed: it turns on strict mutability, under which `Array`
is classified as mutable at all (with capture checking alone both compilers
accept the file). The patch is gated: pass `-Zopaque-mutability` too.

Note the direction is the opposite of most reproductions here: the **unpatched**
compiler accepts the file, and that acceptance is the bug. `Buffer` is an opaque
alias over `Array`, so outside its defining scope the mutability classification
recursion falls through to the alias's declared upper bound and never classifies
it as mutable. The read-only `buffer: Buffer[Int]` parameter is therefore treated
as an untracked pure value, and `place` — a write — is allowed through it:

```scala
def sneaky(buffer: Buffer[Int]): Unit = buffer.place(0, 99)  // compiles unpatched
```

With the patch, that line is the one error:

```
Found:    (buffer : repro.Buffer[Int])
Required: repro.Buffer[Int]^{any}
```

Verified (with the flags above) against the 3.9 and 3.10 streams with and
without `-Zopaque-mutability`, and against stock 3.9.0 and 3.10.0.

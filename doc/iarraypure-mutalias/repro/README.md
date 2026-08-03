# Reproduction: iarraypure-mutalias

Compile `repro.scala` with:

```
scalac -experimental -Ycc-new -language:experimental.captureChecking repro.scala
```

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

Like the other reproductions in this repository, this has not been re-verified
against freshly built unpatched and patched compilers; the flags and the
expected error are those recorded in `repro.scala`'s own header.

# Reproduction: sharedunscoped

Two single-file variants of one program, each compiled alone:

```
scalac -experimental -Ycc-new -language:experimental.separationChecking ambient-shared-only.scala
scalac -experimental -Ycc-new -language:experimental.separationChecking ambient.scala
```

`ambient-shared-only.scala` classifies the ambient strategy `Throwing` as a plain
`SharedCapability` and fails, on stock and patched compilers alike, with:

```
Found:    Decodable[Int]^{any}
Required: Decodable[Int]^{any²}

Note that capability `any` cannot flow into capture set {any²}
because any in an enclosing function is not visible from any² in value x$proxy1.

The error occurred for a synthesized tree:  intCodec(using throwing[String])
```

`ambient.scala` classifies it `caps.SharedUnscoped` instead. Without the patch the trait
does not exist; with it, the file compiles.

Verified against a local `make` build of the 3.9 stream (2026-10-07): fails on
`release/3.9` (3.9.1-dev-p17), compiles on `scratch/sharedunscoped`.

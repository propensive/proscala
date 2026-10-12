# Reproduction: proxyskolem (capture flow)

One of two reproductions (the other, the macro resplice, is
[`repro2/`](../repro2/README.md)):
under capture checking, the skolem-typed inline proxy bakes a local capture
into the expansion type, which cannot be avoided into the pure declared
result.

Compile the single file with:

```
scalac -Ycc-new -language:experimental.captureChecking repro.scala
```

Without the patch, on a compiler carrying upstream #26563 (3.9.0-RC5 and
later), compilation fails at `derivedOne`'s match result:

```
capability `typeclass` cannot flow into capture set {}
```

With the patch, the file compiles.

Derived by reduction from Wisteria's `derivedOne` (typeclass derivation via
`summonFrom`/`asMatchable` matches), the shape behind most of the RC5
Soundness failures.

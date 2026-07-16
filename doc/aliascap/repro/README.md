# Reproduction: aliascap

Three units, compiled **separately** (mixed compilation is essential: the
alias comes from a capture-checked unit, the method using it from a
non-capture-checked unit, and the caller is capture-checked again):

```
scalac -d d defs.scala
scalac -cp d -d l lib.scala
scalac -cp d:l -d c client.scala
```

Without the patch, the third step fails with:

```
Found:    (t : Tactic[ParseError])
Required: Tactic[ParseError]^{any}

Note that capability `t` cannot flow into capture set {any}
because (t : Tactic[ParseError]) in method client is not visible from any in type raises.
where:    any is a root capability in the type of type raises
```

With the patch, all three steps compile.

Verified against local `make`-branch builds of the 3.9 stream (2026-07-16):
fails on `feature/3.9/make` (stock + build only), compiles on
`feature/3.9/aliascap` (= make + this patch alone) and on `trunk/3.9`.

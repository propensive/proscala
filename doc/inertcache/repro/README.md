# Reproduction: inertcache

A synthetic model of the HTML content-category alias unions: two alias
families where each level's expansion mentions **both** aliases of the level
below, so the number of paths through the alias graph is 2^depth. At depth 12
(this file), capture-checking Setup's `mapFollowingAliases` re-expands the
shared lower levels once per path.

```
scalac repro.scala
```

- Without the patch: does not finish (>180 s; killed). The hang is
  capture-checking-specific — deleting the `captureChecking` import compiles
  in ~8 s, and so does replacing the checker with the patched one.
- With the patch: compiles in ~7 s.

Because this is a hang rather than an error, treat "slower than ~10× the
patched time" as reproduction.

Verified against local `make`-branch builds of the 3.9 stream (2026-07-16):
hangs on `feature/3.9/make` (stock + build only), compiles on
`feature/3.9/inertcache` (= make + this patch alone) and on `trunk/3.9`.

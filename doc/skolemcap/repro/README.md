# Reproduction: skolemcap

A self-contained, 21-line reproduction needing only the standard library:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch (upstream, or Proscala without `-Zretains-skolems`) it fails:

```
-- Error: repro.scala:21:26 ----------------------------------------------------
21 |def run(): Unit = provide[Decodable](decode)
   |                          ^
   |                          Illegal capture reference: (?1 : Any)
1 error found
```

With `-Zretains-skolems` it compiles. The inlined proxy for the summoned evidence
is then typed with the skolem widened to the top capability:

```scala
val contextual$1: (Decodable^{any}) = decodable(tactic)
decode(contextual$1)
```

Three ingredients are needed; removing any one makes the error disappear:

- the given `decodable` has a dependent result, `Decodable^{tactic}`, retaining its
  parameter;
- the argument for that parameter is not a stable path — `tactic` is a given
  *method* (`() => Tactic`), so `decodable(tactic)` is typed by substituting a
  skolem `?1` for the parameter. A given *value* (`given tactic: Tactic`) is stable
  and compiles cleanly;
- the evidence is resolved by `summonInline` and passed to an `inline`
  context-function argument, as Soundness's `provide` does, so the inliner binds it
  to a proxy val whose explicit type carries the skolem in its `@retains`
  annotation. With a non-`inline` `body` parameter, or with `summonInline` passed
  directly to `decode`, it compiles.

Reduced from the earlier Soundness-based reproduction (the compile classpath of
Soundness's `ethereal.test` module at Soundness `a5c6577d4c`, through superlunary's
`Rig.dispatch` → `Stageable.extract` → proscenium's `provide[entity is Decodable in
Json]`), which failed with the same message. Verified on 2026-10-12 against stock
Scala 3.9.0 and 3.10.0 (both fail), and against Proscala 3.9 and 3.10 with and
without the flag.

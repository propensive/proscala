# Reproduction: givencache

Compile the single file with:

```
scalac -experimental repro.scala
```

(`-experimental` only; the file itself carries
`import scala.language.experimental.captureChecking`.)

Without the patch, the compiler crashes in capture-checking Setup —
`UncacheGivenAliases` has demoted the stable alias `canvas0` to a `def`, so
the capture set forced by the dependent `summon[I]` names a method:

```
dotty.tools.dotc.cc.IllegalCaptureRef: (canvas0 : => Board^{canvas})
```

With the patch, the file compiles.

The crash needs the dependent-summon casts introduced upstream in 3.9.0-RC5
(they are what force the malformed capture set), so earlier toolchains
compile it either way. Derived by reduction from Soundness's
`ultimatum.Focus` (local `given canvas0`).

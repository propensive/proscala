# Reproduction: quoteunshare

Two files, compiled separately, with capture checking and separation checking:

```
scalac -language:experimental.captureChecking -language:experimental.separationChecking -d . macro.scala
scalac -language:experimental.captureChecking -language:experimental.separationChecking -cp . -d . client.scala
```

Without the patch, a later expansion of the macro in `client.scala` is rejected:

```
-- [E007] Type Mismatch Error: client.scala:5:35 -------------------------------
5 |def second(value: Int): Int = serve(value)
  |                              ^^^^^^^^^^^^
  |Note that capability `any²` cannot flow into capture set {any}
  |because any² is not visible from any in an enclosing function.
```

With the patch, both files compile. Stock scala/scala3 3.10.1 and 3.10.2-RC2
fail in the same way.

The trigger is a macro whose quoted code passes an expression where a context
function with a capability parameter is expected, so that the compiler makes a
closure for it, expanded more than once in one compilation unit and at
different depths. With only one of the three methods in `client.scala`, the
file compiles unpatched.

Reduced from Soundness's exegesis and espionage, which expand obligatory's
`JsonRpc.serve` several times in a file.

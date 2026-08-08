# Reproduction: dependarg

Compile the single file with:

```
scalac -language:experimental.captureChecking repro.scala
```

Without the patch, compilation fails at the call in `g`: rechecking the
dependent application substitutes the first using parameter's widened
(box-adapted) type into the second formal, turning the path selection
`multiplicable.Result` into a type projection:

```
-- [E007] Type Mismatch Error: repro.scala:8:110 -------------------------------
8 |def g(using multiplicable: IsM2 by Int, equality: multiplicable.Result =:= Int): Int = f(using multiplicable, equality)
  |                                                                                                              ^^^^^^^^
  |Found:    (equality : multiplicable.Result =:= Int)
  |Required: Multiplicable{type Self = Int; type Operand = Int}#Result =:= Int
  |
  | longer explanation available when compiling with `-explain`
1 error found
```

With the patch, the file compiles.

The discriminating trigger is the using parameter's declared type being a
refining alias applied to another refining alias (`IsM2 by Int`), with
capture checking enabled; a single collapsed alias, or the same file without
the flag, compiles unpatched.

Derived by reduction from Soundness issue #1411 (the statistics extension
methods' path-dependent `Result` evidence, failing at the soundness package's
export forwarders).

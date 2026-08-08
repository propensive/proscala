# Reproduction: returnavoid

Compile the single file with:

```
scalac -experimental repro.scala
```

(`-experimental` only; the file itself carries
`import language.experimental.captureChecking`.)

Without the patch, compilation fails with an [E007] type mismatch at the
`'{ $r.render($e) }` splice — the quote-pattern type variable `value` has
been avoided out of the found type's refinement but not out of the match
label's return prototype:

```
-- [E007] Type Mismatch Error: repro.scala ...
   Found:    Expr[Html{type Topic}]
   Required: quoted.Expr[Html]^...'s2
```

With the patch, the file compiles.

Derived by reduction from Soundness issue #1428 (honeycomb's `element`
macro).

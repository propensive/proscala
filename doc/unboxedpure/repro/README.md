# Reproduction: unboxedpure

Two independent reproductions, one per symptom. Compile each with:

```
scalac -language:experimental.captureChecking <file>
```

- `pure-type-inline-box.scala` — without the patch, fails with
  `Text is a pure type, it makes no sense to add a capture set to it`.
- `pure-tuple-typemember-box.scala` — without the patch, the derived
  `Showable`'s `text` method gains the parameter type
  `Quanta{ type Form = (Pounds, Stones)^'s1 }` and no longer overrides the
  trait's pure `text(value: Self)`.

With the patch, both files compile. They are the tests the patch adds at
`tests/pos-custom-args/captures/pure-type-inline-box.scala` and
`tests/pos-custom-args/captures/pure-tuple-typemember-box.scala`, copied
verbatim.

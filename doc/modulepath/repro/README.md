# Reproduction: modulepath

Compile both files together with:

```
scalac repro.scala Test.scala
```

No language imports and no capture checking are needed.

Without the patch, on the 3.10 stream, both occurrences of `Positional.Profile`
inside the inline method fail:

```
-- Error: repro.scala:16:38
16 |      val profiles: Array[Positional.Profile] = Array(Positional.Profile("a"))
   |                          ^^^^^^^^^^
   |    (Host.this.p$Host$$inline$Positional : => object p.Positional)
   |    is not a legal path
   |    since it refers to nonfinal method p$Host$$inline$Positional
```

With the patch, the files compile.

The 3.9 stream compiles them unpatched: the fix this patch restores is still
present there, and was removed from `main` after 3.9 branched — so only 3.10
needs it.

Three details are each necessary to trigger it, and dropping any one hides the
bug:

- `Positional` must be **inaccessible** at the expansion site (`private`,
  `private[p]` or `protected`), or no inline accessor is generated at all;
- the accessor must land in a **trait**, so it cannot be marked `final` — in a
  class or object the realizability check accepts it whatever its result type;
- `Positional.Profile` must appear in a **type** position, since the check runs
  on the prefix of a type selection.

`repro.scala` is the test the patch adds at `tests/pos/i22593c/Main.scala`,
copied verbatim, and `Test.scala` is `tests/pos/i22593c/Test.scala`.

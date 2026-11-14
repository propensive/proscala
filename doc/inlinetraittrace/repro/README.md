# Reproduction: inlinetraittrace

Two files, compiled separately, with `-experimental
-language:experimental.inlineTraits`. `lib.scala` has an inline trait,
`Snapshot`, one of whose methods makes an inline call (`each`) on the result of
other inline calls (`mark.z till end.z`). `use.scala` is a class extending it.

```
F="-experimental -language:experimental.inlineTraits"
scalac $F -d l lib.scala
scalac $F -d a -classpath l use.scala                          # compiles
scalac $F -from-tasty -d b -classpath a:l a/app/Parser.tasty   # crashes without the patch
```

Without the patch — upstream 3.10.0 and `main` alike — the last command stops in
the unpickler:

```
java.lang.AssertionError: assertion failed: owner discrepancy for local value $proxy1 @ 512,
  expected: local value interval$proxy1 @ 875, found: local method lib$Snapshot$$reconcile @ 142
    at dotty.tools.dotc.core.tasty.TreeUnpickler$TreeReader.symbolAtCurrent(TreeUnpickler.scala:313)
```

With the patch `Parser` recompiles. The patch changes what is *pickled*, so it is
`use.scala` that must be compiled by the patched compiler: TASTy written by an
unpatched one still cannot be read.

That the recompiled class then also *runs* needs [tastyspecialize](../../tastyspecialize/tastyspecialize.md);
without that patch its constructor calls an initializer the trait does not have.

# Mark a unit read from TASTy which uses inline traits as having specializations

Makes a unit which declares or extends an inline trait compile from its TASTy as it does from source: the trait's unit no longer fails with "declared as `inline`, but was not inlined", and a class extending the trait no longer calls an initializer that does not exist.

## Context

The work of an **inline trait** (`-language:experimental.inlineTraits`) is
spread over several phases. In the frontend, the trait's definitions are copied
into each class that extends it. After pickling, three more things happen to
finish the job: `PruneInlineTraits` empties the trait's own definitions, since
its children hold the code; it marks the trait as having no initializer; and
`Erasure` treats a specialised class specially.

Since upstream #26842, each of those phases does nothing unless the compilation
unit says it is concerned, through a flag:

```scala
/** Set to `true` if there are inline traits (with or without Specialized context bounds) */
var hasSpecializations: Boolean = false
```

The flag is set in exactly one place: `CheckInlineTraits`, a frontend phase
that runs straight after Typer. A unit read from TASTy does not pass through
the frontend — `ReadTasty` takes its place — so its flag is never set, and the
later phases all stand aside.

Two things follow, for the two kinds of unit:

- A unit which **declares** an inline trait keeps the trait's body, inline calls
  and all. Those calls are never expanded, because an inline trait's body is not
  meant to be compiled, and `Erasure` reports each one.
- A unit with a class which **extends** an inline trait compiles, but the trait
  is not marked as having no initializer, so the class's constructor calls
  `Trait.$init$`. The trait's class file has no such method. This one is silent
  until the class is instantiated.

Soundness's `zephyrine`, which declares `Cursor.Snapshot`, failed with 24 errors
of the first kind when recompiled from TASTy.

## Reproduction

[`repro/`](repro/) — one file:

```scala
inline trait Counter[operand]:
  var count: Int = 1
  def advance(): Unit = count = count.twice     // `twice` is an inline extension

class Doubler extends Counter[Byte]
```

```
scalac $F -from-tasty -d b -classpath a a/app/Counter.tasty

-- Error: counter.scala:11:38
   |  method twice is declared as `inline`, but was not inlined

scalac $F -from-tasty -d c -classpath a a/app/Doubler.tasty     # compiles
java.lang.NoSuchMethodError: 'void app.Counter.$init$(app.Counter)'
```

## Solution

`CompilationUnit.Force` is the traversal that loads an unpickled tree, and it
already works out the unit's other flags as it goes — `needsInlining`,
`needsStaging`. It now works out this one too, from the same three conditions
`CheckInlineTraits` uses:

```scala
tree match
  case tree: tpd.TypeDef if tree.symbol.isInlineTrait =>
    containsSpecialization = true
  case tree: tpd.Template
  if tree.parents.exists(parent => inlines.Inlines.symbolFromParent(parent).isInlineTrait) =>
    containsSpecialization = true
  case tree: tpd.Ident if tree.symbol == defn.SpecializedModule_apply =>
    containsSpecialization = true
  case _ =>
```

— the unit declares an inline trait, has a class with one among its parents, or
summons a `Specialized` instance — and the unit is given
`hasSpecializations`, and `needsInlining` with it, as `CheckInlineTraits` gives
both.

The frontend phases that *copy* the trait's definitions do not run again, and
need not: the class's TASTy already holds the copies.

With the patch, the trait's unit and the class recompile to the bytecode the
source compilation gave, and the program runs.

## Upstream

Upstream 3.10.0 and `main` fail identically. The flag arrived with upstream
#26842 — on `main`, and backported to `release-3.10.0` in 3.10.0-RC2 — so the
patch applies from each of those on. It is always on. Worth reporting upstream
with the reproduction.

Reading the class back at all, where the trait's methods nest inline calls,
needs [inlinetraittrace](../inlinetraittrace/inlinetraittrace.md).
`tests/pos/inline-trait-unit-from-tasty.scala` is the reproduction as a test.

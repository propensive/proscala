# Test a symbol's owner before its annotations in `MoveStatics`

Reorders the condition in `MoveStatics.transformSym` so that a denotation brought forward through the phase is asked for its `@static` annotation only once it is known to be a member of a module with a companion, which stops a late-phase base-class computation from re-entering itself through the parent's `@SourceFile` annotation and failing with `Cyclic reference involving class SourceFile`.

Always on: it changes the order of three pure tests, not their result.

## Context

`MoveStatics` is the phase that moves `@static` members of a module to its companion class. It is also a `SymTransformer`: when a denotation is *brought forward* to a phase at or after it — `Denotations.current`, walking `goForward` through every transformer between the denotation's last valid phase and the current one — `transformSym` is applied, to every symbol, whether or not it has anything to do with statics:

```scala
def transformSym(sym: SymDenotation)(using Context): SymDenotation =
  if (sym.hasAnnotation(defn.ScalaStaticAnnot) && sym.owner.is(Flags.Module) && sym.owner.companionClass.exists && …
```

`hasAnnotation(cls)` walks the symbol's annotations and matches each by `annot.symbol.derivesFrom(cls)`, so for every annotation it computes the *annotation class's* base classes. Nearly every class loaded from a library compiled by Scala 3 carries one annotation at least: `@SourceFile("…")`, which the pickler adds to each top-level class. Asking whether some such class is `@static` therefore means computing the base classes of `scala.annotation.internal.SourceFile`.

Base classes are cached per run (`BaseDataImpl.isValid` requires the cache's run id to be the current one), and computed, when first asked in a run, at the phase of the asking: `computeBaseData` takes each parent's `baseClasses`, which brings the parent's denotation forward to the current phase — through `MoveStatics`, if the current phase is later.

## The problem

Put those together in a run whose first request for `SourceFile`'s base classes comes at a late phase. The class `SourceFile` extends `scala.annotation.Annotation`; `Annotation` is itself annotated `@SourceFile`. Computing `SourceFile`'s base data locks it, then brings `Annotation` forward; `MoveStatics.transformSym(Annotation)` asks `Annotation.hasAnnotation(ScalaStaticAnnot)`, which matches `@SourceFile` by `SourceFile.derivesFrom(ScalaStaticAnnot)`, which asks for `SourceFile`'s base classes — locked:

```
Cyclic reference involving class SourceFile
The error occurred while trying to compute the base classes of class SourceFile
  which required to compute the base classes of class SourceFile
    SymDenotations$BaseDataImpl.apply
    SymDenotations$ClassDenotation.derivesFrom
    Annotations$Annotation.matches
    SymDenotations$SymDenotation.hasAnnotation
    transform.MoveStatics.transformSym
    Denotations$SingleDenotation.goForward$1   (×14: Annotation brought forward phase by phase)
    SymDenotations$ClassDenotation.computeBaseData
    SymDenotations$ClassDenotation.derivesFrom
    Annotations$Annotation.matches
    SymDenotations$SymDenotation.hasAnnotation
    scala.scalanative.nscplugin.NirGenType.isStruct
```

Nothing catches a `TypeError` in a backend phase, so the compilation dies (and, before [cyclicctx](../cyclicctx/cyclicctx.md), died *describing* the error rather than reporting it).

The first request has to be late in the run for this to happen, which is why typer-first compilations never see it: typer computes the base classes of every annotation class it meets, at a phase before `MoveStatics`, and the cache then serves the rest of the run. The run that meets it is the **suspended-units run** — the second `Run` that `Driver.finish` starts for units suspended because they use a macro defined in the same compilation. Its base-data caches start empty, and whether an early phase of it happens to ask about `SourceFile` before a backend does depends on which units were suspended and what they contain. Soundness meets it in `quantitative.core.native` — Scala Native's `genNIR` asks `isStruct` (that is, `hasAnnotation(@struct)`) of every class it instantiates — in roughly one clean build in three (propensive/proscala#20).

## The solution

`transformSym` tests the two cheap, structural conditions first — the symbol's owner is a module, and that module has a companion — and the annotation last:

```scala
if (sym.owner.is(Flags.Module) && sym.owner.companionClass.exists && sym.hasAnnotation(defn.ScalaStaticAnnot) && …
```

The result is unchanged for every symbol: `&&` of the same three pure tests. What changes is that a class symbol, whose owner is a package or another class, never has its annotations looked at here, so bringing a class forward through `MoveStatics` no longer computes any annotation class's base classes, and the cycle above has no second arm. The other transformer that tests `@static`, `Getters`, already checks that the symbol is a field before it asks.

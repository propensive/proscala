# Reproduction: inlinetraitimport

One file, with `-experimental -language:experimental.inlineTraits`: an inline
trait with an import in its body, a class extending it, and a `main` which
prints `2`. Nothing is read from TASTy.

```
scalac -experimental -language:experimental.inlineTraits -d a counter.scala
scala -classpath a app.Main      # 2
```

Without the patch — upstream 3.10.0 and `main` alike — the compiler crashes:

```
unhandled exception while running erasure on counter.scala
Exception in thread "main" scala.MatchError: ImportType(Ident(Ordinals)) (of class dotty.tools.dotc.core.Types$ImportType)
    at dotty.tools.dotc.core.TypeErasure.dotty$tools$dotc$core$TypeErasure$$apply(TypeErasure.scala:941)
    at dotty.tools.dotc.transform.Erasure$Typer.promote(Erasure.scala:582)
    at dotty.tools.dotc.typer.ReTyper.typedInlined(ReTyper.scala:103)
```

With the patch it compiles and runs.

Move `class Doubler` and `Main` to a second file compiled *after* the first, in
a run of its own, and the crash does not occur without the patch either: it
needs the trait and a class extending it in the same run. Moving the import out
of the trait's body, to the top of the file, also avoids it.

# Reproduction: prunecomplete

One unit, `Use.scala`, compiled with a sourcepath:

```
scalac -sourcepath sp -d . Use.scala
```

`sp/` holds three files that are never named on the command line:
`lib/Foo.scala`, a class whose companion holds a subclass, and two stand-ins
that **shadow standard-library classes** of the same names,
`scala/Unit.scala` and `scala/annotation/compileTimeOnly.scala`.

Without the patch (stock Scala 3.10.0), the compiler crashes during erasure:

```
dotty.tools.dotc.core.Denotations$StaleSymbolException: stale symbol;
  module class compileTimeOnly$#… in module class annotation,
  defined in Period(1.1-2), is referred to in run Period(2.1)
```

With the patch, it compiles.

What happens:

- When the compiler initialises, `Definitions` loads `scala.Unit` and
  `scala.annotation.compileTimeOnly` for its own use. The sourcepath offers
  newer sources for both names, so their symbols are created with
  source-file loaders, in the initialisation run (run 1; the first compilation
  run is run 2).
- `Use.scala` mentions `Foo`, so `Foo` is entered from `sp/lib/Foo.scala` in
  run 2. A sourcepath file is parsed and entered, never type-checked, so
  `Foo.Inclusive` keeps its `Namer` class completer, and nothing in the typer
  asks for it.
- The unit has an inline call, so it `needsInlining`, and
  `PruneInlinedMethods.transformInfo` applies to every class denotation
  advanced past that phase. Advancing `Foo`'s companion in erasure filters its
  declarations with `isDeletable`, whose first test reads each member's
  flags, which **completes `Inclusive`**: its parent application `Foo(x)`
  needs the implicit `Integral[T]`, and the search walks the file's imports.
  `import scala.annotation.compileTimeOnly` names the module loaded during
  initialisation; completing it forces its module class, whose denotation
  cannot be brought forward into run 2.

With the patch, `isDeletable` pre-filters on the symbol's last known
denotation without advancing or completing it, so `Inclusive` is never
completed by the pruning phase.

Each ingredient is needed: without the inline call the pruning phases do not
run for the unit (3.10.0 already carries upstream's gate on `needsInlining`);
without either shadow, or with a wildcard `import scala.annotation.*`, the
import resolves to the jar's symbol, which survives into run 2; with
`Inclusive` at top level rather than in the companion, nothing completes it
from the pruning phase; and without the implicit parameter the parent
application makes no search. The shadow files' timestamps do not matter.

How it was found: the fork's own Scala.js stdlib build, compiled with
`-sourcepath library/src`, failed at this step with exactly this exception
(`doc/prunecomplete/prunecomplete.md`). A tree at that upstream commit
(`9542a5f686`) with the patch reverted fails on a one-line unit whenever the
stdlib comes from the sourcepath; so do upstream nightlies up to 3.10.0-RC1,
and RC2 and 3.10.0 whenever the unit makes an inline call. Greedily removing
the stdlib's sources from the sourcepath, with the stdlib jar on the
classpath, left `Unit.scala`, `compileTimeOnly.scala` and
`NumericRange.scala`; `Foo` is `NumericRange` reduced to the companion
subclass `Inclusive` whose parent application needs its `Integral`.

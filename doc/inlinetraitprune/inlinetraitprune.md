# Make an inline trait's members deferred whichever unit asks first

Stops the compilation of an inline trait from depending on the order of the files: a file which only uses the trait, compiled before the one which declares it, gave "Concrete method has no definition".

## Context

The definitions of an **inline trait** (`-language:experimental.inlineTraits`)
are copied into the classes that extend it, so the trait itself is compiled to
an interface of abstract methods. The phase `PruneInlineTraits` does that in two
halves, which must agree:

- its **tree** transformer empties the right-hand side of each definition in the
  trait's template;
- its **symbol** transformer gives each of those members the `Deferred` flag,
  and marks the trait as an interface without an initializer.

Since upstream #26842 both halves are skipped unless the compilation unit *has
specializations* — declares or extends an inline trait — to spare other units the
work. But the two halves ask about different units. The tree transformer is
handed a template, and asks about the unit that template is in: the trait's.
The symbol transformer is handed a symbol, and asked about *the unit that happens
to be current when the symbol's denotation is first needed at this phase*.

A denotation is transformed once and then kept. So if the first unit to look at
the trait's members is one which merely *uses* the trait — calls a method on a
value of its type, and neither declares nor extends any inline trait — the
transformer declines, and the members stay concrete for the rest of the run.
When the trait's own unit is reached, its definitions are emptied all the same,
and the backend finds concrete methods with no body.

Whether that happens depends on the order of the units, which for two files on
a command line is the order they are given in.

## Reproduction

[`repro/`](repro/) — two files; nothing is read from TASTy:

```scala
// counter.scala
inline trait Counter[operand]:
  var count: Int = 1
  def advance(): Unit = count = count + count

// reader.scala
object Reader:
  def count(counter: lib.Counter[Byte]): Int =
    counter.advance()
    counter.count
```

```
scalac $F -d a reader.scala counter.scala
Concrete method has no definition: def advance(): Unit

scalac $F -d b counter.scala reader.scala      # compiles
```

It was found recompiling a library from TASTy, where every unit of a component
is given at once and the order is the file system's: with
[tastyspecialize](../tastyspecialize/tastyspecialize.md) in place, a trait and
the code using it recompiled in one order and not in the other.

## Solution

The symbol transformer (`transform/PruneInlineTraits.scala`) now goes by the
symbol alone:

```scala
override def transformSym(sym: SymDenotation)(using Context): SymDenotation = {
  if isEraseable(sym) then
    sym.copySymDenotation(initFlags = sym.flags | Deferred)
  else if sym.isClass && sym.isInlineTrait then
    val clsInfo = sym.asClass.classInfo
    val clsInfo2 = clsInfo.derivedClassInfo(decls =
        clsInfo.decls.filteredScope(!isDeletable(_)))
    sym.copySymDenotation(initFlags = sym.flags | PureInterface | NoInits, info = clsInfo2)
  else sym
}
```

`isEraseable` already requires the symbol's owner to be an inline trait, so in
a program without inline traits the transformer still changes nothing; it costs
each symbol one test of its owner's flags. A member of an inline trait is
deferred whatever unit is being compiled, which is also what a unit compiled
separately sees in the trait's class file.

## Upstream

Upstream 3.10.0 and 3.10.1 fail as shown. `main` has since made the same change,
in #27302 ("Fix transformSym in PruneInlineTraits"), so the patch is obsolete
from there: it is carried from #26842, which introduced the test of the unit
(and its backport to `release-3.10.0`), up to that fix. It is always on.

`tests/pos/inline-trait-used-first` is the reproduction as a test; its two files
are compiled together, the user first.

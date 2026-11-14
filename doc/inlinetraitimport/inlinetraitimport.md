# Leave an inline trait's imports out of the classes which extend it

Stops the compiler crashing in Erasure, with `MatchError: ImportType`, when an inline trait with an import in its body is compiled in the same run as a class which extends it.

## Context

An **inline trait** (`-language:experimental.inlineTraits`) is a trait whose
body is copied into every class that extends it, specialised to the class's
type arguments. The copying goes through the trait's statements one by one, and
treats them in two ways:

```scala
val stats1 = stats.map {
  case member: MemberDef => Left((member, inlinedSym(member.symbol, overriddenDecls)))
  case stat => Right(stat)
}
stats1.map {
  case Left((tree, inlinedSym)) => expandStat(tree, inlinedSym)
  case Right(tree) => inlinedRhs(tree)
}
```

A **definition** — a `val`, `var` or `def` — is given a new symbol in the child,
and its right-hand side is inlined. **Anything else** is taken to be an
expression of the trait's initialisation, and is copied as it stands, wrapped
in an `Inlined` node which records where it came from.

An `import` in the trait's body is a statement which is neither. It is not a
definition, so it goes the second way, and the child class gets

```scala
class Doubler() extends Object(), Counter[Byte] {
  import Ordinals.*                       // inside an Inlined node
  override var count: Int = 1
  ...
```

An `Inlined` node has the type of what it wraps, and an import's type is an
`ImportType`, a marker which exists only so that Typer can look names up through
it. It is not the type of any value. Nothing objects until Erasure, which
re-types every `Inlined` node by erasing its type, and has no case for this
one.

It needs the trait and a class extending it in the **same run**. Compiled in
separate runs, the class is not given the import, and compiles.

The remedy for a user is to move the import out of the trait, but an import
beside the members it serves is ordinary Scala, and the crash names neither the
import nor the trait. It was met while writing tests for the fork's other
inline-trait patches.

## Reproduction

[`repro/`](repro/) — one file; nothing is read from TASTy:

```scala
object Ordinals:
  extension (index: Int) inline def twice: Int = index + index

inline trait Counter[operand]:
  import Ordinals.*

  var count: Int = 1
  def advance(): Unit = count = count.twice

class Doubler extends Counter[Byte]
```

```
scalac -experimental -language:experimental.inlineTraits -d a counter.scala

unhandled exception while running erasure on counter.scala
Exception in thread "main" scala.MatchError: ImportType(Ident(Ordinals))
    at dotty.tools.dotc.core.TypeErasure.dotty$tools$dotc$core$TypeErasure$$apply(TypeErasure.scala:941)
    at dotty.tools.dotc.transform.Erasure$Typer.promote(Erasure.scala:582)
    at dotty.tools.dotc.typer.ReTyper.typedInlined(ReTyper.scala:103)
```

## Solution

By the time a trait's body is copied it has been typed: every name in it has
been resolved, and its imports have nothing left to do. `expandDefs`
(`inlines/Inlines.scala`) now leaves them out, beside the two kinds of
statement it already skipped:

```scala
val stats = Inlines.defsToInline(parentSym)
  .filterNot(stat => overriddenDecls.contains(stat.symbol) && stat.symbol.is(Deferred))
  .filterNot(stat => stat.isDef && stat.symbol.isClass)
  .filterNot(_.isInstanceOf[Import])
```

The trait itself keeps its imports; only the copies lose them. The child's
TASTy is then the same as it is when the two are compiled in separate runs, and
the class recompiles from it.

Teaching Erasure to drop an `Inlined` import would also stop the crash, but
would leave a meaningless statement in the child's tree and its TASTy for every
phase in between to step over.

## Upstream

Upstream 3.10.0 and `main` crash identically. The code arrived with inline
traits, in upstream #26156, so the patch applies from there on, and not to the
3.9 line. It is always on, since it only turns a crash into a compilation.
Worth reporting upstream with the reproduction.

`tests/pos/inline-trait-import.scala` is the reproduction as a test.

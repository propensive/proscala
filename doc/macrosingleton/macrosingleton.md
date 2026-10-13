# Reveal an opaque type behind a singleton in the macro-expansion check

Lets a transparent macro expand to a value whose type is an opaque alias, such as an `Unset` sentinel, without failing the check that the expansion conforms to the macro's declared type.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

Scala 3.10 checks that what a macro expands to conforms to the type of the
splice it replaces (scala/scala3#25756). The two types are compared with their
opaque aliases revealed on both sides, since the expansion may have been typed
where an opaque's alias is visible, and the call site may be somewhere it is not.
The comparison maps each type through `dealiasOpaques`, which replaces every
reference to an opaque type by the type it aliases.

A singleton type is a reference to a term, not to a type, so the map passes over
it. That matters for the idiom Soundness uses for optional values: an opaque
type with a single value of that type,

```scala
object opt:
  opaque type Unset <: Matchable = Null
  val Unset: Unset = null

type Optional[value] = Unset | value
```

A macro returning `Optional[String]` that expands to `Unset` has the expansion
type `Unset.type`, the singleton of the value. The expected type has its opaque
revealed, `Null | String`, but the singleton keeps its type, and `Unset.type`
does not conform to `Null | String`: its underlying type is the opaque `Unset`,
whose alias is visible only inside `opt`.

## Reproducing it

```scala
// Macro_1.scala
package repro

import scala.quoted.*

object opt:
  opaque type Unset <: Matchable = Null
  val Unset: Unset = null

export opt.Unset
type Optional[value] = Unset | value

object macros:
  transparent inline def pick(inline flag: Boolean): Optional[String] = ${pickImpl('flag)}
  def pickImpl(flag: Expr[Boolean])(using Quotes): Expr[Optional[String]] =
    if flag.valueOrAbort then '{ "yes" } else '{ Unset }
```

```scala
// Test_2.scala
package repro

def use: Optional[String] = macros.pick(false)
```

Scala 3.10.0 rejects `use`:

```
Macro expansion has type (repro.Unset : => (repro.opt.Unset² : repro.opt.Unset)),
which does not conform to the expected type Null | String
```

3.9, which does not make the check, accepts it. In Soundness, every transparent
macro that can produce `vacuous.Unset` failed this way, among them xenophile's
WASI macros, which read optional values out of WIT records.

## The solution

`dealiasOpaques` widens a singleton whose underlying type contains an opaque
alias, and reveals the opaque in what it widens to:

```scala
// A singleton whose type is (or contains) an opaque alias, such as a
// `val Unset: Unset` of an opaque `Unset`, is widened to it, so that the
// opaque is revealed on this side as it is on the other.
case tp: TermRef if tp.widen.existsPart(_.typeSymbol.isOpaqueAlias) =>
  apply(tp.widen)
```

Only the check's comparison changes: the expansion keeps its own type,
`Unset.type`, and a singleton whose type involves no opaque is compared as
before. Widening loses nothing the check needs, because the expected type it is
compared with is the declared type of the splice, which is never narrower than
the value's type.

The map is written differently on different upstream lines (on some it strips
ordinary aliases before matching, on others it matches them as a case), so the
patch has a version for each, adding the same case. Its test is
`run-macros/macrosingleton`, which compiles the macro and its use separately and
runs the result.

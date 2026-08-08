# Strip ordinary aliases when the macro-expansion check reveals opaques

Fixes the macro-expansion conformance check's rejection of well-typed
expansions whose type hides an opaque behind an ordinary type alias, by
dealiasing before looking for opaques so both sides of the check are
normalized identically.

## Context

After a macro expands, the compiler checks that the expansion's actual type
conforms to the inline definition's declared result type — the
macro-expansion conformance check introduced upstream in #25756 (on the 3.10
line). Because a macro is expanded at the *call site*, where the definition
site's opaque type aliases may not be transparent, the check first runs both
types through a `dealiasOpaques` `TypeMap` that reveals opaque aliases (see
`tests/run-macros/opaque-inline`):

```scala
val dealiasOpaques = new TypeMap:
  def apply(tp: Type): Type = tp match
    case tp: TypeRef if tp.typeSymbol.isOpaqueAlias =>
      val sym = tp.typeSymbol
      apply(sym.opaqueAlias.asSeenFrom(tp.prefix, sym.owner))
    case _ =>
      mapOver(tp)
```

The map only recognizes an opaque that *heads* a `TypeRef` directly. An
opaque hidden behind an **ordinary** alias — say

```scala
opaque type Timestamp = Long
type Date = Timestamp { type Form = Day }
```

— is not revealed: `Date` is not itself an opaque alias, and `mapOver` does
not step *through* an alias into its right-hand side.

That would be harmless if both sides of the check arrived in the same shape,
but they do not. The **expected** type comes from the inline definition's
TASTy, where it has already been dealiased to the refined-`Timestamp` form and
its opaque is duly revealed; the **actual** type of the unpickled expansion
still names `Date`, and stays unrevealed. The check then compares a revealed
`Long {...}` against an unrevealed `Date` and rejects a perfectly well-typed
expansion:

```
Macro expansion has type ... does not conform to the expected type ...
```

## Reproduction

Two files, compiled in two runs (the macro library first):

```scala
// m.scala
object internal:
  opaque type Timestamp = Long
  type Date = Timestamp { type Form = Day }
  ...
  object Date:
    def julianDay(day: Int): Date = day.toLong.asInstanceOf[Date]

inline def opNoArg(): internal.Date = ${dateMacro0}
inline def opArg(left: internal.Monthstamp): internal.Date = ${dateMacro1('left)}
```

```scala
// u.scala
@main def run(): Unit =
  val a: internal.Date = opNoArg()
  val b: internal.Date = opArg(Monthstamp())
```

```
scalac -d out m.scala
scalac -classpath out -d out u.scala
```

No special flags are needed. Without the patch, on the 3.10 stream, the
second run rejects both macro calls with the "Macro expansion has type ...
does not conform" error above; with the patch, both runs succeed. (The check
does not exist before 3.10, so earlier streams need no patch.)

## The solution

Make the map alias-transparent by dealiasing each type before matching, in
`compiler/src/dotty/tools/dotc/inlines/Inliner.scala`:

```scala
val dealiasOpaques = new TypeMap:
  def apply(tp: Type): Type = tp.dealias match
    case tp: TypeRef if tp.typeSymbol.isOpaqueAlias =>
      val sym = tp.typeSymbol
      apply(sym.opaqueAlias.asSeenFrom(tp.prefix, sym.owner))
    case tp =>
      mapOver(tp)
```

`dealias` strips only *ordinary* aliases — it respects opaque scopes, so
nothing is revealed that the map's opaque case would not reveal anyway. Its
effect is purely normalizing: whichever mixture of aliased and dealiased
forms the two sides arrive in, they now reduce to the same shape before the
conformance comparison.

## Relevance to Soundness

Aviation (Soundness's time library) defines its calendar types exactly this
way: `Timestamp` is opaque over `Long`, and `Date`, `Monthstamp` and friends
are ordinary refinement aliases over it, distinguished by a phantom `Form`
member. Its date *literals* — `2000-Jan-1`, parsed and validated at compile
time by an inline macro returning `Date` — tripped the new conformance check
on every use site once the 3.10 line picked up #25756, even though the
expansions were exactly the values the signatures declared. With the patch,
aviation's literal syntax compiles again unchanged.

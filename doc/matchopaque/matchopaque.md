# Follow aliases in an inline call's arguments before exposing opaque types

Lets an inline method of an opaque type be called on a value whose type names that opaque type only through an alias below the top of the type: a match-type alias read from TASTy, or an ordinary alias under a refinement or in a type argument.

## Context

An opaque type is transparent only inside the object that declares it. An
`inline` method declared there is written against the underlying type, but is
expanded somewhere else, where the type is opaque — so the inliner has to carry
the transparency along. It does so with an **opaque proxy**: a local `val`
for the declaring object whose type is refined with the aliases
(`Cell.type { type Ref[value] = AtomicReference[value] }`), and a cast of each
argument that mentions the object to the same type seen through the proxy.
Inside the expansion, `ref.get()` then typechecks, because `ref` is a
`$proxy1.Ref[String]`, which is visibly an `AtomicReference[String]`.

To decide which arguments need the cast, the inliner searches the argument's
type for references to an object that has opaque members. It searched the
*widened, dealiased* type. That is not enough when the type is an application
of a **match alias**:

```scala
type Cell[value] = value match
  case Int => Cell.Whole
  case _   => Cell.Ref[value]
```

`Cell[String]` reduces to `Cell.Ref[String]`, but dealiasing does not reduce
it, and as written it mentions neither `Cell.Ref` nor the object `Cell` — only
the alias and `String`. No proxy is made, the argument is not cast, and the
inlined body sees a value of the still-opaque type.

In a single compilation this never shows, because Typer *simplifies* the type
of every tree it types, the declared type of a definition included, and
simplifying reduces match aliases: `val ref: Cell[String]` is given the type
`Cell.Ref[String]` on the spot. A definition read from TASTy keeps the type
that was written. So the call fails whenever the argument's type came from
TASTy:

- a member of a separately compiled class, declared with the alias;
- everything, in a unit recompiled with `-from-tasty`.

Soundness has exactly this shape. `rudiments` declares its atomic variables as
opaque types inside `object Atomic`, with the inline accessors in their
companions, and a match alias as the name everyone uses:

```scala
type Atomic[value] = value match
  case Int     => Atomic.Int
  case Long    => Atomic.Long
  case Boolean => Atomic.Bool
  case _       => Atomic.Ref[value]
```

Fields are declared `Atomic[X]` throughout, so most of Soundness could not be
recompiled from its TASTy (which fume does, to insert coverage probes):
`parasite-core` alone gave 21 errors.

## The same through an ordinary alias

A match alias is the case `dealias` never follows. An ordinary alias it does
follow — but only at the top of a type. `export Ops.O` gives an opaque type a
second name that is an ordinary alias, and a type that mentions it lower down
keeps the alias: `O { type Form = Int }` is a refinement whose *parent* is the
alias, and `List[O]` has it as an argument. Neither mentions `Ops`, so no proxy
was made, in a single compilation too, with nothing read from TASTy.

Soundness reaches this through its proof idiom: an `Ordinal` confined to a
value is `Ordinal { type Form = xs.type }`, and `Ordinal` is exported from the
object that declares it, so every inline extension on a confined ordinal failed
unless the receiver was first ascribed to plain `Ordinal`.
[`repro2/`](repro2/) is that shape in one file.

## Reproduction

[`repro/`](repro/) — no flags. A library, a unit declaring a `Cell[String]`,
and a client compiled separately:

```scala
object Aliased:
  val ref: Cell[String] = Cell("a")
  def read(): String = ref()          // an inline extension on Cell.Ref
```

```
scalac -from-tasty -d b -classpath l:a a/use/Aliased.tasty

-- [E050] Type Error: use.scala:7:26
 7 |  def read(): String = ref()
   |                       expression does not take parameters
   |This location contains code that was inlined from lib.scala:14
14 |      inline def apply(): value = ref.get().nn
```

Soundness reported the same failure in two other forms, which have not been
reduced to reproductions here: a mismatch against the proxy for the object
itself (`Found: Atomic[…]`, `Required: Atomic$_this.Ref[…]`), and, where the
inline method's body is a macro, a rejected tree (`undefined:
index.getAndIncrement`).

## Solution

`mapOpaquesInValueArg` (`inlines/Inliner.scala`) now follows the aliases in the
argument's type, at any depth, before looking through it:

```scala
private def followAliases(tp: Type)(using Context): Type =
  val follow = new TypeMap:
    def apply(t: Type) = t match
      case t: AppliedType if t.isMatchAlias =>
        val reduced = t.tryNormalize
        if reduced.exists then apply(reduced) else mapOver(t)
      case t: (TypeRef | AppliedType) =>
        val dealiased = t.dealiasKeepAnnots
        if dealiased ne t then apply(dealiased) else mapOver(t)
      case _ => mapOver(t)
  follow(tp)

private def mapOpaquesInValueArg(arg: Tree)(using Context): Tree =
  val argType = followAliases(arg.tpe.widenDealias)
```

A match alias is reduced where it can be, and left as it is where its scrutinee
is still abstract; any other alias is replaced by what it stands for, keeping
its annotations (capture sets among them). An opaque type is not an alias from
outside the object that declares it, so it is where the following stops. The
result is used exactly as before: only to find the proxies and to form the
cast, which is added only if the proxies change the type. An argument with no
alias below the top of its type is untouched.

`Typer`'s own `simplified` would reduce the match aliases too, but it also
instantiates type variables, which an inliner running during typing (for a
transparent inline method) must not do.

## From source and from TASTy

With the patch a unit recompiles from its TASTy to the same instructions as it
compiles to from source, but not to the same bytes. A definition declared with
the match alias keeps its unreduced type when read from TASTy, so the generic
signature derived from it is missing: `val ref: Cell[String]` becomes a field
with the signature `AtomicReference<String>` from source, and a raw
`AtomicReference` from TASTy. Nothing at run time depends on it; reflection
and Java callers see the difference.

## Upstream

This is upstream's behaviour in both published versions tried (3.3.6 and
3.10.0), and is not specific to `-from-tasty`: `repro/client.scala` is an ordinary
compilation, and `repro2/` involves no TASTy at all. It is always on, since it only accepts programs that were
rejected. Worth reporting upstream with the reproduction.

A more general remedy would be for the unpickler to simplify an applied type
tree as Typer does (it already does so for a match type tree, "as that's what
Typer does"); that would also restore the generic signature, but changes what every reader of TASTy sees, so it is
not attempted here.

`tests/pos/opaque-inline-match-alias` covers the separately compiled case, for
both arms of the match and for a nested alias;
`tests/pos/opaque-inline-export-alias.scala` and its counterpart under
`tests/pos-custom-args/captures` cover the ordinary alias.

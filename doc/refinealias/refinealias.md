# Drop the implied capture set from a type alias in a refinement

Makes an alias in a refinement, such as `{ type Self = handle }` where `handle` is bounded by a capability, mean `handle` itself under capture checking, as a type member's own alias already does.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

Under capture checking, a type that derives from a capability class and is
written without a capture set gets the capture set the capability implies: in
Setup, `Res` becomes `Res^`. Setup makes an exception for the info of a type
member: `type X = Res` declares an alias of `Res`, not of `Res^`, and the
implied set is stripped from it (`stripImpliedCaptureSet`).

A refinement holds type members too, but Setup maps its alias infos like any
other part of the type, so the exception is lost. Soundness's typeclasses are
refinements of exactly this shape: `handle is Streamable` is
`Streamable { type Self = handle }`, and a given for a handle type bounded by a
capability is

```scala
given streamable: [handle <: (Handle & Granting[Grant.Read])^]
=>  handle is Streamable by Data over Credit = _.source()
```

Setup turns its result type into `Streamable { type Self = handle^ }`, an alias
of `handle` with a fresh capture set. Each instantiation of the given then mints
a new root capability for it, which no argument's own captures can match.

On 3.9 this went unnoticed, because inference widened the given's type argument
to a type the fresh root could absorb. 3.10 infers the type argument exactly, as
the argument's own type (`Res^{r}`), and the given no longer matches.

## Reproducing it

```scala
trait Res extends caps.SharedCapability:
  def size: Int

trait Streamable:
  type Self
  def stream(s: Self): Int

object Res:
  given streamable: [handle <: Res^] => (Streamable { type Self = handle }) = _.size

extension [source](source: source)(using st: Streamable { type Self = source })
  def checksum: Int = st.stream(source)

def f(r: Res^): Int = r.checksum
```

Scala 3.10.0 rejects `f`:

```
Found:    Streamable{type Self = (Res^'s1)^{any}}
Required: Streamable{type Self = Res^{r}}

Note that capability `r` cannot flow into capture set {any}.

The error occurred for a synthesized tree:  Res.streamable[Res]
```

3.9 accepts it. In Soundness, galilei's `Handle.streamable` and guillotine's
`Job.writableText` failed this way, so neither a file handle nor a running
process could be read as a stream or written to.

## The solution

In Setup's mapping of a type (`toCapturing`), the generic case maps a type as
before, adding the implied capture set where it applies, and then, for a
refinement, strips the implied set from each alias refinement, as is done for a
type member's own info:

```scala
t match
  case _: RefinedType => stripAliasRefinements(t2)
  case _ => t2

private def stripAliasRefinements(t: Type): Type = t match
  case t @ CapturingType(parent, refs) => t.derivedCapturingType(stripAliasRefinements(parent), refs)
  case t @ RefinedType(parent, rname, rinfo: TypeAlias) =>
    t.derivedRefinedType(stripAliasRefinements(parent), rname, stripImpliedCaptureSet(rinfo))
  case t @ RefinedType(parent, rname, rinfo) =>
    t.derivedRefinedType(stripAliasRefinements(parent), rname, rinfo)
  case _ => t
```

Only a capture set the capability implies is removed: `stripImpliedCaptureSet`
recognises the `CSImpliedByCapability` set Setup itself added. A capture set
written in the alias, as in `{ type Self = handle^{io} }`, stays.

Stripping after the mapping, rather than skipping the alias while mapping, leaves
everything else the mapping does to the alias's type in place. The patch's test
is `pos-custom-args/captures/refinealias.scala`, which also covers a capability
summoned through a using parameter. The outcome of every other test in
`tests/{neg,pos}-custom-args/captures` is unchanged.

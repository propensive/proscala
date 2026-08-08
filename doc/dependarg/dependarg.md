# Conserve stable argument paths in dependent-application rechecking

Makes the capture checker substitute a stable argument's path type — rather
than its capture-adapted, possibly widened rechecked type — into the later
formals of a dependent application, so evidence that selects a member of an
earlier parameter still typechecks.

## Context

Capture checking re-types the whole program in the `Recheck` phase. When it
rechecks an application whose method type is *parameter-dependent* — a later
formal mentions an earlier parameter, as in

```scala
def f(using multiplicable: IsM2 by Int,
            equality: multiplicable.Result =:= Int): Int
```

— `recheckArgs` substitutes each argument's type into the remaining formals
before checking the corresponding arguments against them, just as the typer
did when the call was first elaborated. But where the typer substituted the
argument's **stable path** (`multiplicable.type`), `recheckArgs` substituted
the argument's *rechecked* type:

```scala
if fntpe.isParamDependent
then formals.tail.map(_.substParam(prefs.head, argType))
```

`argType` has been through box adaptation, which can widen and dealias a
singleton. When the first parameter's declared type is a refining alias
applied to another refining alias — `IsM2 by Int`, i.e.
`(Multiplicable { type Self = Int }) { type Operand = Int }` — the adapted
type is the widened refinement, not the argument's path. Substituting it
turns the second formal's path selection `multiplicable.Result` into the type
**projection** `Multiplicable{...}#Result`, which selects `Result` from the
*class*, unrefined and unrelated to any particular instance. The actual
`equality` argument, whose type still names the path, no longer conforms, and
rechecking rejects a call the typer accepted. A single alias, or the same
code without capture checking, adapts to a type the substitution survives —
only the doubly-nested refining alias under cc triggers the widening.

## Reproduction

Eight lines ([repro/repro.scala](repro/repro.scala)):

```scala
trait Multiplicable:
  type Self
  type Operand
  type Result
type IsM2 = Multiplicable { type Self = Int }
infix type by[refined <: { type Operand }, operand] = refined { type Operand = operand }
def f(using multiplicable: IsM2 by Int, equality: multiplicable.Result =:= Int): Int = ???
def g(using multiplicable: IsM2 by Int, equality: multiplicable.Result =:= Int): Int = f(using multiplicable, equality)
```

Compiled with `scalac -language:experimental.captureChecking repro.scala`, an
unpatched compiler rejects the call in `g` with:

```
Found:    (equality : multiplicable.Result =:= Int)
Required: Multiplicable{type Self = Int; type Operand = Int}#Result =:= Int
```

— the required side shows the projection the widening substitution produced.
With the patch, the file compiles. Note the discriminating shape: `IsM2 by
Int` is a refining alias applied to another refining alias; collapsing the two
into a single alias, or dropping the capture-checking flag, makes the
unpatched compiler accept the file.

## The solution

Substitute the argument's stable path when it has one, falling back to the
rechecked type otherwise. In
`compiler/src/dotty/tools/dotc/transform/Recheck.scala`, `recheckArgs`:

```scala
if fntpe.isParamDependent then
  // Substitute the argument's stable path type (as Typer did) rather than
  // the capture-adapted rechecked type: box adaptation can widen/dealias a
  // singleton argument, and substituting the widened type turns a later
  // formal's `x.Result` selection into a type projection that the actual
  // argument no longer conforms to. This mirrors the singleton conservation
  // recheckApplication#instArgs already performs for dependent results.
  val substArg =
    if !argType.isSingleton && arg.tpe.isStable then arg.tpe else argType
  formals.tail.map(_.substParam(prefs.head, substArg))
else formals.tail
```

This is the same singleton conservation `recheckApplication`'s `instArgs`
already performs when instantiating a *dependent result* type; the patch
extends it to the dependent *formals*. When the rechecked type is itself a
singleton, or the argument is not a stable path, nothing changes.

The result side needs a matching extension: `instArgs` conserved stable paths
only when the rechecked argument type was an *unboxed capturing* type, so a
stable argument widened to a plain non-capturing type (exactly the
doubly-nested-alias widening above) still projected a dependent result — a
method returning `Optional[divisible2.Result]` failed the same way. The patch
adds a case conserving the path there too; no captures can be lost, since the
rechecked type carries no capture set.

## Relevance to Soundness

Soundness issue #1411. The statistics extension methods on `Iterable[value]`
— `total`, `mean`, `variance`, `std`, `product` — each take a typeclass
instance through a doubly-refining alias (`value is Addable by value`,
`value is Multiplicable by value`) together with path-dependent evidence such
as `equality: addable.Result =:= value`, exactly the shape above. Under
capture checking, every non-inline call site of such a method failed with the
projection mismatch — first visibly at the `soundness` package's synthesized
export forwarders, which are simply the first non-inline call sites the
compiler generates. Their `transparent inline` siblings escaped only because
inline method bodies are not rechecked. With the patch, the forwarders and
all ordinary call sites capture-check as written.

# dependbound

Relates an inferred type argument to an upper bound that names another type parameter while capture sets can still grow, so that a well-typed application is not rejected by the later bounds check.

## Context

Capture checking runs after the typer has chosen every type argument. The
typer knows nothing of capture sets, so the capture checker revisits each
*inferred* type argument and puts a **capture set variable** wherever a
capability might be captured: an argument the typer inferred as `Box` becomes
`Box^{?1}`, and what `?1` holds is worked out from how the value is used.
Checking an expression adds elements to these variables; when a definition has
been checked, they are *solved*, and from then on they are fixed.

A type parameter may be bounded by a type which names an earlier parameter of
the same clause:

```scala
given coll: [element, coll <: Coll[element]] => Sized[coll, element] = ...
```

Here the two arguments are not independent. If they are inferred as
`Box^{?1}` and `Coll[Box^{?2}]`, the bound demands
`Coll[Box^{?2}] <: Coll[Box^{?1}]`, that is, `{?2} <: {?1}`: whatever the
collection's elements capture, `element` must capture too.

Upstream checks type arguments against their bounds twice. While it rechecks
the application it compares only the capture set *of the argument itself* with
that *of the bound itself* — for `Coll[Box^{?2}]` against `Coll[element]`,
two empty sets. The complete comparison of the argument with its bound is made
only in a final pass, after the variables are solved. Nothing in between ever
records that `?2` flows into `?1`. So when the expected type puts a capability
into `?2` and says nothing of `?1`, `?1` is solved as empty, and the final
pass then finds that the argument does not conform to the bound: a failure the
checker brought about itself, by not asking the question while it could still
have been answered.

(Before scala/scala3 #27551, the argument for such a parameter was given no
variable inside it at all, and the application failed sooner, for that reason.
This patch applies from that change on.)

## How to reproduce it

Compiled with `-Ycc-new -experimental`:

```scala
import scala.language.experimental.captureChecking

class Cap extends scala.caps.SharedCapability
class Box(val cap: Cap^)
class Coll[+element]

trait Sized[self, element] extends scala.caps.Pure:
  def size(self: self): Int

object Sized:
  given coll: [element, coll <: Coll[element]] => Sized[coll, element] = _ => 0

extension [self, element](self: self)(using sized: Sized[self, element])
  def size: Int = sized.size(self)

def test(cap: Cap^): Int =
  val boxes: Coll[Box^{cap}] = new Coll
  boxes.size
```

```
Type argument Coll[Box{val cap: Cap^}^{cap²}] does not conform to upper bound Coll[Box{val cap: Cap^'s1}^'s2]
```

The argument for `coll` has rightly been found to hold boxes which capture
`cap`, but `'s2`, the variable of the argument for `element`, was solved
without it.

In [Soundness](https://soundness.dev), `Traversable` and `Mappable` are given
in this form, for `[element, list <: List[element]]`, because the collection's
type may be a refinement of `List[element]` and the typeclass's subject is
invariant. Under capture checking a task captures its monitor, so mapping over
a list of tasks failed to find the instance:

```scala
supervise(List(async(1), async(2)).map(_.await()))
```

## Solution

When the capture checker rechecks a type application, the patch makes the
complete comparison straight away for each inferred argument whose upper bound
names a type parameter of the same clause, with the arguments substituted for
the parameters as the final pass will substitute them. The variables are still
open, so the comparison records the dependency instead of failing:

```scala
private def constrainDependentTypeArgs(tree: TypeApply)(using Context): Unit =
  tree.fun.nuType.widen match
    case tl: PolyType if tree.args.exists(_.isInstanceOf[InferredTypeTree]) =>
      def isDependent(bound: Type) = bound.existsPart:
        case ref: TypeParamRef => ref.binder eq tl
        case _ => false
      lazy val argTypes = tree.args.lazyZip(tl.paramInfos).map: (arg, bounds) =>
        arg.nuType.forceBoxStatus(bounds.hi.isBoxed | bounds.lo.isBoxed)
      for (arg, idx) <- tree.args.zipWithIndex do
        val hi = tl.paramInfos(idx).hi
        if arg.isInstanceOf[InferredTypeTree] && isDependent(hi) then
          TypeComparer.atomicOp(argTypes(idx) <:< hi.substParams(tl, argTypes))
    case _ =>
```

Three things keep the change narrow. Only inferred arguments are related:
one written in the source has no variables of the checker's own to
constrain. Only bounds which name a parameter of the clause are compared,
since any other bound cannot connect two arguments. And the comparison is
atomic: if it fails, whatever it added to any capture set is taken back, and
the application is left exactly as it was for the final pass to report, as
before.

The patch is always on. It cannot make an application pass which the final
bounds check would reject, since that check still runs, on the solved sets; it
only lets the sets be solved with the bound taken into account. The capture
set of `element` grows as a result, which is the truth the bound states, and
anything that receives an `element` from such an application is checked
against it.

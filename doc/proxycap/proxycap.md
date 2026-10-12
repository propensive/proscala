# Infer a closure argument's own captures on its inline proxy

Stops capture checking from rejecting a capturing closure passed to an inline method's function parameter, by inferring the closure proxy's own capture set where the parameter allows any, and keeping everything else the parameter declares.

Always on: it only turns programs that upstream rejects into accepted ones, and it accepts nothing a parameter's declared type forbids.

## Context

When an inline method is expanded, each argument that is not a simple path is
bound to a *proxy*, a local `val`, and the body refers to the proxy instead of the
parameter. The argument is then checked against the proxy's type alone.
[scala/scala3#26989](https://github.com/scala/scala3/pull/26989) (on `main`, and
backported to 3.10.0-RC3) gave proxies **explicit** types, the argument's type
from Typer. Before, their types were inferred, which let an argument capture
anything at all, whatever the parameter declared.

But Typer knows nothing about capture sets. For a closure, its type from Typer is
precise about the closure's parameters and result, which is what #26989 wanted
(its test `cc-inline1` catches a capability leaking through a closure's result
this way), but says nothing about what the closure *itself* captures. Taken at
face value, it declares every closure pure.

## Reproducing it

```scala
import language.experimental.captureChecking

extension [value](iterable: Iterable[value])
  inline def fuse[state](base: state)(lambda: (state, value) ?=> state): state =
    val iterator: Iterator[value] = iterable.iterator
    var state: state = base
    while iterator.hasNext do state = lambda(using state, iterator.next())
    state

def fold[acc](initial: acc)(lambda: (Int, acc) => Exception => acc): acc =
  val errors = List[Exception]()
  (0 until errors.length).fuse(initial)(lambda(summon[Int], summon[acc])(errors(summon[Int])))
```

Scala 3.10.0 rejects it, although `fuse` declares that its `lambda` may capture
anything (`?=>`):

```
Found:    (contextual$1: acc, contextual$2: Int) ?->{lambda} acc
Required: (contextual$1: acc, contextual$2: Int) ?-> acc
```

In Soundness this broke `contingency`, `metamorphose` and `wisteria`. Without
`inline` the method compiles, as it does on every release before 3.10.0-RC3.

## The solution

`Inliner.paramBindingDef` builds a closure proxy's type from two annotations
Setup already understands, and upstream already uses for inline calls' type
arguments: a part annotated `@caps.internal.inferred` is given fresh capture-set
variables, as an inferred type, and inside it a part annotated
`@caps.internal.declared` is explicit again. The closure's parameter and result
types stay declared; its own capture set follows the parameter's function type:

| parameter | the closure proxy's own capture set |
| --------- | ----------------------------------- |
| `A => B`, `A ?=> B` | inferred: exactly what the closure captures |
| `A ->{x} B` | `{x}`, as declared |
| `A -> B` | empty, as declared |

```scala
def inferredFunction(t: Type): Type = t match
  case t @ RefinedType(parent, nme.apply, mt: MethodType) if defn.isFunctionType(t) =>
    inferred(t.derivedRefinedType(parent, nme.apply,
      mt.derivedLambdaType(mt.paramNames, mt.paramInfos.map(declared), part(mt.resType))))
  case t @ AppliedType(tycon, args) if defn.isFunctionType(t) =>
    inferred(t.derivedAppliedType(tycon, args.init.map(declared) :+ part(args.last)))
  case _ => NoType
```

The same rule applies to a function in the closure's result (`part`), as for
`Int ?=> A => Unit`. Inferring matters, rather than declaring the parameter's
`any`: separation checking sees a proxy declared with a fresh `any` as *hiding*
what the closure captures, and rejects any later use of it. And inferring only
where the parameter allows anything matters too: a closure that captures `io`,
passed for a parameter declared `() -> Unit`, is still rejected.

The patch's tests, `pos-custom-args/captures/proxycap.scala` (separation-checked)
and `neg-custom-args/captures/proxycap.scala`, cover each row in both
directions. Every error in upstream's `cc-inline1` is still reported, and the
outcome of every other test in `tests/{neg,pos}-custom-args/captures` is
unchanged.

## Not covered

Arguments other than closures have the same problem: their proxies are typed
with Typer's capture-free type, so `useOnly(io)(identity(o))` is rejected for a
parameter `x: Object^{io}` and an `o: Object^{io}`, and an array inside a
proxy's type is declared as a fresh capability (Soundness's `.to[List]` on
arrays, `.nn` on a nullable array). Inferring those proxies' types instead, as
before 3.10.0-RC3, reopens the hole #26989 closed; bounding them by the
parameter's declared type fails because that type's inferred type arguments
are not marked as inferred (a capture-set parameter arrives as `caps.CapSet`).
That needs a fix of its own.

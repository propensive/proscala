# Do not assert on an open type parameter reached through a term's info

Stops the compiler crashing when the implicit scope of a given search is collected from a type that reaches an uninstantiated type parameter through the info of a term in it.

Always on: it fixes a crash.

## Context

An implicit search looks for candidates in the implicit scope of the type it
searches for: the companions of every class that is part of that type. Before
the parts are collected (`ImplicitRunInfo.collectParts`), the type goes through
`wildApprox`, which replaces each type variable that is not yet instantiated by
a wildcard bounded as the variable is. The collector then asserts that it never
meets an uninstantiated type parameter:

```scala
case t: TypeParamRef =>
  assert(!ctx.typerState.constraint.contains(t), i"`wildApprox` failed to remove uninstantiated $t")
  traverse(t.underlying)
```

`wildApprox` works on the type, but the collector looks further: for a term
reference in the type it traverses the term's own info, which `wildApprox`
does not touch. If that info mentions a type parameter of the current
constraint, the assertion fails.

That happens with inline methods. An inline call binds its receiver to a
`this`-proxy, typed when the call is inlined. If the call is inlined while an
enclosing call's type variables are still open, the proxy's type mentions them.
A given search inside the inlined body, for instance the one an inline match
makes in `summonFrom`, can then have a type that refers to the proxy, and the
proxy's info refers to the open parameters.

## Reproducing it

The whole shape fits in a few lines (`repro/parts.scala`):

```scala
import scala.compiletime.summonFrom

inline def next[value](using items: List[value]): value = items.head

def fuse[value](lambda: List[value] ?=> Any): Any = lambda(using Nil)

trait Adm[t]
class Box[child]

transparent inline def box(child: Any): Box[child.type] =
  summonFrom:
    case given Adm[child.type] => (new Box).asInstanceOf[Box[child.type]]
    case _                     => (new Box).asInstanceOf[Box[child.type]]

def test: Any = fuse(box(next))
```

`fuse`'s type variable `value` is open while its context-function argument is
typed. Inside it, `box(next)` is inlined at once, as it is transparent, and its
result type mentions its argument, so the type variable of `next` cannot be
interpolated first: the proxy that inlining binds `child` to has that open
variable as its info. The `summonFrom` then searches for `Adm[child$proxy.type]`,
and collecting its implicit scope reaches the variable through the proxy.
Scala 3.10.0 crashes:

```
java.lang.AssertionError: assertion failed: `wildApprox` failed to remove uninstantiated value
```

Soundness reaches it in exoskeleton's `rig`, where a path is built with
serpentine's transparent `/` on a state value (`state/next`) inside a `fuse`
block: the `/` method's body resolves the path's type with `summonFrom`, its
result type depends on `child.type`, and `next` is typed while the type
variables of the enclosing `fuse` call are open. 3.9 compiles the module.

## The solution

The assertion is dropped, and an uninstantiated parameter met this way is
treated as an instantiated one is: its bound stands for it.

```scala
case t: TypeParamRef =>
  // `wildApprox` removes uninstantiated type parameters from the type itself,
  // but one can still be reached through the info of a term reference in it
  // (an inline `this`-proxy typed while an enclosing call's type variables are
  // open, for instance); its declared bound stands for it here, as it does for
  // an instantiated one.
  traverse(t.underlying)
```

The traversal after the assertion is upstream's own, unchanged: for every
type parameter it meets, the collector already goes on to `t.underlying`, the
parameter's declared bounds. Only the assertion is gone, so a parameter met
through a term's info contributes the companions of its bounds' classes to the
implicit scope, as one met in the type would once instantiated. The collector
only gathers companions, so nothing is inferred from the bound: at worst the
scope holds a few companions that the eventual instance would not have added.

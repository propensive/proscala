# anonascribe-shared

Gives each ascription of an anonymous class instance a type of its own, so that two expansions of a macro in one file do not share capture set variables.

## Context

When a program writes `new Spring { ... }`, the typer defines an anonymous class
and instantiates it, and ascribes the instance with the type it is known by
outside — the class's parent:

```scala
{ final class $anon() extends Object(), Spring { ... }; new $anon(): Spring }
```

The [anonascribe](../anonascribe/anonascribe.md) patch makes the capture checker
treat that ascription as an *inferred* type, which it is, even where it was read
back from TASTy as a plain type tree. For an inferred type the preparatory phase,
`Setup`, makes fresh **capture set variables**, to be filled in as the code is
checked, and records the resulting type against the tree: each type tree has
one slot for its new type.

That is one slot per tree *node*, and here a node can occur twice. The code a
macro generates comes from a quote, and a quote is unpickled once: each
expansion substitutes its own arguments for the splices, which rebuilds the
trees that contain a splice and **shares** the ones that do not. The ascription's
type tree, `Spring`, contains none. So when a macro is expanded twice in one
compilation unit, both expansions hold the same node. `Setup` gives it a type
with variables at the first expansion, finds it already has one at the second,
and leaves it — and the second expansion's anonymous instance is then checked
against variables which belong to the first.

A capture set variable has an owner, the definition it was made in, and may
only receive capabilities visible from there. A capability of the second
expansion is not:

```
Note that capability `postable$proxy2` cannot flow into capture set {any}
because (postable$proxy2 : Postable^{x$2}) in method second is not visible from any in value request.
```

where `value request` is the `val` of the *first* expansion.

## How to reproduce it

A macro (`macro.scala`):

```scala
inline def submit(payload: String)(using postable: Postable^): Request =
  ${Macros.submit('payload, 'postable)}

object Macros:
  def submit(payload: Expr[String], postable: Expr[Postable])(using Quotes): Expr[Request] =
    ' {
        given postable0: Postable = caps.unsafe.unsafeAssumePure($postable)

        val request =
          new Request
            ( caps.unsafe.unsafeAssumePure:
                new Spring:
                  def apply(): String = postable0.stream($payload) )

        request
      }
```

expanded twice, at different depths (`client.scala`):

```scala
def first(payload: String)(using Tactic): Request =
  val make: () => Request = () => submit(payload)
  make()

def second(payload: String)(using Tactic): Request = submit(payload)
```

This is telekinesis's `submit` in [Soundness](https://soundness.dev), which
wraps a request body in a `Spring` that produces its stream on demand, and
obligatory's JSON-RPC client, whose `request` and `notification` both post
through it. Either alone compiles; the two in one file did not.

## Solution

The type is made for each ascription, and kept on the `Typed` node — which
contains the instance, with that expansion's own class, and so is never shared
— not on its type tree:

```scala
case tree @ Typed(expr, tpt: TypeTree) if isAnonymousInstance(expr) =>
  traverse(expr)
  tree.putAttachment(Setup.AnonymousAscription,
    transformInferredType(tpt.tpe, NoSymbol, meetIntersections = true))
```

and the rechecker takes it from there:

```scala
override def recheckTyped(tree: Typed)(using Context): Type =
  ...
  tree.getAttachment(Setup.AnonymousAscription) match
    case Some(ascribed) =>
      recheck(tree.expr, ascribed)
      ascribed
    case None =>
      super.recheckTyped(tree)
```

Each expansion now has variables owned where it is, and what `anonascribe`
provides is unchanged: the ascription is still read as inferred.

The patch is always on, and depends on `anonascribe`, whose behaviour it
corrects. It is carried from scala/scala3 #27551 on; the earlier lines of
history keep `anonascribe` as it was.

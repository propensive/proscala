# inlinecomplete

Stops capture checking from rechecking a definition inside an inline method when something merely asks for its type.

## Context

Capture checking rechecks every definition of a compilation unit, working out
what each expression captures. One kind of definition it deliberately leaves
alone: the body of an **inline method**. That body is not code which runs where
it is written. It is a template, copied into each caller and checked there,
with the caller's types in place of its parameters; and until it is copied, the
calls it makes to *other* inline methods are not expanded either, so the body
contains applications which will never exist in that form.

```scala
def recheckDefDef(tree: DefDef, sym: Symbol)(using Context): Type =
  ...
  if tree.rhs.isEmpty || sym.isInlineMethod then resType   // the body is skipped
  else recheck(tree.rhs, resType)
```

There is a second way for a definition to be checked. A `val` or `def` whose
type was inferred gets a new type from capture checking, and since that type
may be needed before the checker reaches the definition in source order, the
symbol is given a *completer*: asking for its info runs the check there and
then. To do so the completer rebuilds the environment of the definition from
its owners, which asks for *their* capture sets, and so completes — rechecks —
each enclosing definition with an inferred type as well.

Nothing in that path knows about inline methods. So if anything asks for the
info of a symbol inside an inline method's body, the definition is rechecked
after all, out of order and outside the method, together with the closures
around it. The checker's final pass over the unit is one thing which asks: it
walks every tree, inline bodies included, and takes members as seen from their
prefixes, which reads the infos of the symbols those prefixes name.

What the recheck then finds is not an error in the program. In the case which
exposed this, the body passed a polymorphic lambda to another inline method —
a call still unexpanded — and the lambda, which captured a context parameter
of the enclosing closure, was compared with the parameter type of that method
as though the call were an ordinary one:

```
Found:    [field] -> (field: field) -> (...) ?=> jacinta.Json.Ast
Required: [field] -> field => (...) ?=> jacinta.Json.Ast^'s1

Note that capability `contextual$57` cannot flow into capture set {}.
```

## How to reproduce it

No self-contained reproduction is known yet; see `repro/FIXME.md`, which
records what does reproduce it and what was tried. The code is the `inline def
conjunction` of the JSON encoder's derivation in
[Soundness](https://soundness.dev):

```scala
object EncodableDerivation extends Derivable[Json.Encodable]:
  inline def conjunction[derivation <: Product: ProductReflection]
  :   derivation is Json.Encodable =
    ...
    value =>
      provide[Foci[Json.Focus]]:
        val labels: scala.Array[String] = new scala.Array[String](arity)
        ...
        fields(value): [field] =>
          field =>
            ...focus(...)...     // uses the `Foci` that `provide` supplies
```

`fields` is an inline method of wisteria's, expanded by a macro where
`conjunction` is itself expanded — for each case class a JSON encoder is derived
for — and the lambda is checked there, against the types of that expansion.

## Solution

A completer forced for a symbol which lies inside an inline method marks it
complete without rechecking it, as the rechecker itself skips the method's
body:

```scala
def completeDef(tree: ValOrDefDef, sym: Symbol, completer: LazyType)(using Context): Unit =
  val saved = curEnv
  if sym.owner.ownersIterator.exists(_.isInlineMethod) then
    completed += sym
  else try
    ...
```

The symbol keeps the type `Setup` gave it. Nothing depends on a more precise
one: the inline method's body is checked in full at each place it is expanded,
on a copy with symbols of its own, and that is where its capture sets are
worked out and its errors, if it has any, are reported.

The patch is always on: it removes a spurious error. It is bounded from
scala/scala3 #27551, the earliest commit the upstreams it has been seen on
share; where the behaviour began is not known.

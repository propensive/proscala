# Seal package-object prefixes on implicit candidate references

Gives every implicit search candidate an explicit package-object prefix, so
that extension methods and conversions provided by top-level givens no longer
leak the underlying type of a top-level opaque type in their results.

## Context

An opaque type alias is transparent only inside its defining scope. The
compiler implements this through the *prefix* of the type's `TypeRef`: the
alias is stored as a refinement of the enclosing module class's self type, so
`M.this.Lst` sees the underlying type while the external `M.Lst` sees only the
declared bounds. For top-level definitions, `M` is the synthetic package
object (`repro$package` below), and correctness depends on every
externally-visible reference carrying the explicit package-object prefix
`pkg.repro$package.member` — a bare-package prefix stops `asSeenFrom` from
rewriting `repro$package.this` in the member's type, leaving the opaque alias
transparent wherever that type flows.

Upstream hit this family in [scala/scala3#18097](https://github.com/scala/scala3/issues/18097)
and fixed it in 3.6.3 ([#21527](https://github.com/scala/scala3/pull/21527)) by
applying `makePackageObjPrefixExplicit` to references resolved through
`findRef` — i.e. identifiers written in source. But implicit search builds its
candidate references separately, in `Implicits.typedImplicit`, and that path
was missed. A given defined at the top level next to an opaque type — the
shape of every Soundness `given ... with extension ...` companion, such as
proscenium's `consConstructor` for its opaque `List` — is found with a
bare-package prefix, and any of its extension methods returning the opaque
type returns it *transparent*.

The result is [soundness#1809](https://github.com/propensive/soundness/issues/1809):
a single cons works, but chaining conses selects `::` as a *member* of the
underlying `scala.collection.immutable.List` on the intermediate result, so
`1 :: 2 :: Nil` is rejected with the baffling `Found: List[Int], Required:
List[Int]`, and with no expected type it silently *is* an `sci.List`,
re-exposing the stdlib surface the opaque design hides.

## Reproduction

With `Lst` standing in for proscenium's `List` (see `repro/`):

```scala
object Lst:
  def of[e](list: sci.List[e]): Lst[e] = list.asInstanceOf[Lst[e]]

val Nul: Lst[Nothing] = Lst.of(sci.Nil)

given consConstructor: Object with
  extension [element](head: element)
    infix def ::(tail: Lst[element]): Lst[element] =
      Lst.of(tail.asInstanceOf[sci.List[element]].::(head))

opaque type Lst[+element] = sci.List[element]
```

From any other package, `2 :: Nul` compiles but produces a transparent result:
`(2 :: Nul).length` compiles — `length` is a member of the *underlying* list —
and `1 :: 2 :: Nul` fails, because the outer cons resolves to the underlying
`sci.List.::` member instead of the extension. Writing the same call
explicitly, `consConstructor.::[Int](Nul)(2)`, stays correctly opaque: the
identifier goes through `findRef`, which seals the prefix. Only the
implicit-search route leaks. Chaining is not required to observe the bug, and
neither is right-associativity; they are just how proscenium trips over it.

## The solution

Seal the candidate reference in `typedImplicit` exactly as `findRef` does. In
`compiler/src/dotty/tools/dotc/typer/Implicits.scala`:

```scala
      record("typedImplicit")
      // Give the ref an explicit package-object prefix so that asSeenFrom
      // rewrites the package object's ThisType in its member types. Otherwise
      // an extension method or conversion defined in a package object and
      // returning an opaque type of that package object would have a result
      // type in which the opaque alias stays transparent. `findRef` does the
      // same for identifiers.
      val ref = cand.ref.makePackageObjPrefixExplicit match
        case ref: TermRef => ref
        case _ => cand.ref
```

`makePackageObjPrefixExplicit` is a no-op unless the reference's prefix refers
to a package and its symbol lives in a package object, so givens defined in
ordinary objects or classes are untouched. `cand.ref` itself is left alone —
it is still used afterwards for ranking and accessibility checks. The rewrite
covers both uses of the candidate: extension member selection and implicit
conversions, whose results had the same latent leak.

This is an upstream bug, present in stock Scala 3.7.4 and 3.8.3; the patch is
an upstream candidate, tracked in the upstream-report checklist
([proscala#33](https://github.com/propensive/proscala/issues/33)).

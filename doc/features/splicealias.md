# Give spliced type binders their spliced type as info

Fixes spurious "does not conform" and "object creation impossible" errors under capture checking when a macro-built anonymous class declares a type member equal to a spliced type, by making the type hole's binder symbol an alias of the actual spliced type rather than the pickled placeholder `TypeAlias(Any)`.

## Context

Scala 3 macros are written with **quotes and splices**: `'{ ... }` builds a code fragment, and `${ ... }` or a `Type[T]` context bound inserts caller-supplied code or types into it. The body of a quote is compiled once, **pickled** into TASTy, and shipped inside the macro's classfile. Positions where a type must be filled in later — every occurrence of a `T: Type` in the quote — cannot be pickled concretely, so the pickler replaces them with **type holes**.

Concretely, an unpickled quote with type holes looks like a block whose first statements are synthetic **binders**: `type T$1` definitions annotated `@SplicedType`, whose right-hand side is a hole and whose symbol carries the placeholder info `TypeAlias(Any)`. When the macro runs, `PickledQuotes.spliceTypes` learns the real type for each hole (e.g. `String` for `Type.of[String]`) and runs a `TreeTypeMap` over the quote's expansion, rewriting every reference to a binder symbol into the spliced type.

## The problem

`TreeTypeMap` only *copies* a symbol when the map visibly changes its info. For a class symbol, the info is a `ClassInfo`, and the map applied to a `ClassInfo` rewrites only its **parents**. So an anonymous class inside the quote whose *declarations* — but not parents — mention a binder is judged unchanged and is not copied; its members keep referring to the binder symbol, whose info is still the placeholder `TypeAlias(Any)`. Any later phase that dealises such a member sees `Any`.

Ordinarily nothing looks. But capture checking **rechecks** the tree, including refinement-member conformance of the macro's result. Minimal reproduction:

```scala
// Macro.scala — compiled separately
import scala.quoted.*

trait TC:
  type Self
  def get: Self

object Macro:
  inline def make[T]: TC { type Self = T } = ${ makeImpl[T] }

  def makeImpl[T: Type](using Quotes): Expr[TC { type Self = T }] =
    '{ new TC { type Self = T; def get: Self = null.asInstanceOf[Self] } }
```

```scala
// Use.scala
import language.experimental.captureChecking

val tc: TC { type Self = String } = Macro.make[String]
```

The anonymous class's parent is plain `TC` — no hole — so the class survives the map uncopied, and its `Self` member still aliases the binder, i.e. `Any`. Capture checking's recheck then compares `type Self = <binder>` against the expected `type Self = String` and fails with a baffling error of the form `Object with TC {...}^'s1 does not conform to TC { type Self = String }`, followed by "object creation impossible".

## The solution

Instead of relying solely on the substitution reaching every reference, `spliceTypes` now also fixes the source: each binder symbol's own info is set to `TypeAlias(<spliced type>)`. Any reference that survives the `TreeTypeMap` then dealises to the right type regardless of which phase consults it — the placeholder `Any` can no longer leak.

Two refinements make this safe:

- `@inferred` annotations are stripped from the spliced type first: carried into a member's alias they would make the member fail its own declared bounds during override checking.
- The change is gated on `Feature.ccEnabledSomewhere`. Without capture checking nothing rechecks these members, and downstream macros that reflect on types reaching surviving references currently observe (and depend on) the placeholder, so behaviour there is left untouched.

## Code

The single change, in `spliceTypes` in `compiler/src/dotty/tools/dotc/quoted/PickledQuotes.scala`, inside the loop that pairs each binder `tdef` with its spliced type `tree.tpe` before building the substitution map:

```scala
// Under capture checking, point the binder's own info at the spliced type. The
// tree map below substitutes occurrences in the expansion's types, but a symbol
// whose ClassInfo is unchanged by the map (e.g. an anonymous class whose
// declarations — not parents — mention the binder) is not copied, and its members
// keep referring to this symbol. Its pickled placeholder info is `TypeAlias(Any)`,
// so such survivors wrongly dealias to `Any` when capture checking's recheck
// consults the member.
if Feature.ccEnabledSomewhere then
  def stripInferred(tp: Type): Type = tp match
    case AnnotatedType(parent, annot) if annot.symbol == defn.InferredAnnot =>
      stripInferred(parent)
    case _ => tp
  tdef.symbol.info = TypeAlias(stripInferred(tree.tpe))
(tdef.symbol, tree.tpe)
```

The existing `ReplaceSplicedTyped` map and `TreeTypeMap` run unchanged afterwards; the new line only guarantees that whatever they miss still means the right thing.

## Relevance to Soundness

Soundness is built almost entirely on typeclasses of the shape `T is TC`, which expands to the refinement `TC { type Self = T }` — every `Typeclass` declares an abstract `type Self` (`lib/prepositional/src/core/prepositional.Typeclass.scala`), and macros routinely construct or summon instances of such refinements (e.g. the `Directive { type Self = keyType }` matches in `lib/telekinesis/src/core/telekinesis.internal.scala`). A macro-built instance whose parent typeclass takes no type parameter mentions the spliced `Self` type only in a declaration — exactly the uncopied-class case — so compiling Soundness under capture checking hit this error directly. The distilled reproduction lives in the Soundness repo at `rep/splicealias-repro/` (`Macro.scala`, `Use.scala`), and is the source of the snippet above.

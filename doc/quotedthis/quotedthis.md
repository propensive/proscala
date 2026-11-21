# Let quoted code refer to the members a class defined in the quote inherits

Makes a class defined in a quote able to use the members of its parent — directly, and from quotes nested in a splice — where the compiler crashed, rejected the macro's expansion, or produced a method that calls itself for ever.

Always on: every program it changes was a crash, a spurious error or a hang.

## Context

A macro often builds an anonymous subclass of a library class, so that the
generated code inherits the library's fields and fills in one method. Soundness's
`Map.fixed` does it for a perfect-hash map: the parent holds the displacement
table, and the generated `index` reads it.

```scala
abstract class Base(protected val table: Array[Int]):
  def index(key: Int): Int

def impl(using Quotes): Expr[Base] =
  '{
    new Base(Array(1, 2, 3)):
      def index(key: Int): Int = ${body('key, '{table})}
  }
```

`table` here means `this.table`, where `this` is the anonymous class: something
that exists only inside the outer quote. Two parts of the compiler have to know
that, and neither did for a member the class merely *inherits*.

## The problem

**Accessors.** Quoted code may be spliced anywhere, so a reference in it to a
protected member is redirected to a public accessor, `inline$table`. There is an
exception for a reference through the `this` of a class defined in the same
quote, which inherits the member wherever it lands. But the exception looked for
a selection, `this.table`, and a member written by its name alone is typed as an
identifier, so the exception never applied to one. With no nested splice at
all, the accessor was entered in the anonymous class after the class body had
been typed, and never defined:

```
undefined: this.inline$table.apply # -1: TermRef(TermRef(ThisType(TypeRef(NoPrefix,class $anon)),inline$table),apply)
```

With a nested quote, the accessor was made while the class body was still being
typed, so it got a definition, `def inline$table = table` — and that body, being
quoted code that mentions a protected member, was redirected to the accessor in
turn: `def inline$table = inline$table`. The macro compiled, its use site got a
bare "Infinite recursive call" warning, and the program hung.

**Capture.** A nested quote that refers to something defined in the enclosing
quote cannot be pickled with that reference in it. `Splicing` therefore passes
such references into the splice as arguments of its hole: `'key` above becomes a
parameter `key$1: Expr[Int]`. What counted as defined in the quote was decided
by the symbol. `table` is defined in `Base`, outside the quote, so with a public
`table` — no accessor to hide it — the nested quote kept `this.table`, and with
it the `this` of a class that does not exist where that quote is pickled:

```
java.lang.AssertionError: assertion failed: unresolved symbols: anonymous class Base {...}
```

[`repro/`](repro/) has the three forms. Upstream 3.9.0 and 3.10.0 fail in the same ways.

## The solution

The accessor exception now recognises an identifier too:

```scala
// inlines/PrepareInlineable.scala, in needsAccessor
case Select(qual, _) => qual.tpe.isInstanceOf[ThisType] && qual.symbol.isContainedIn(inlineSym)
case tree: Ident =>
  tree.tpe match
    case TermRef(prefix: ThisType, _) => prefix.cls.isContainedIn(inlineSym)
    case _ => false
```

and `Splicing` treats a reference through the `this` of a class of the quote as
captured, whoever defines the member:

```scala
// transform/Splicing.scala
private def capturedThisRef(tree: Tree)(using Context): Type = tree.tpe match
  case tpe @ TermRef(prefix: ThisType, _) if tree.isTerm && isCaptured(prefix.cls) => tpe
  case _ => NoType

private def isCapturedRef(tree: Tree)(using Context): Boolean =
  isCaptured(tree.symbol) || capturedThisRef(tree).exists
```

`isCapturedRef` replaces the test on the symbol wherever a term reference is
captured, so an inherited member is handled exactly as a member the class
defines itself already was: a value is passed into the splice as an `Expr`, a
method is applied through the reflection API, and an assignment to an inherited
`var` is rebuilt as one. The nested quote `'{table}` becomes `'{${table$1}}`,
and the hole evaluates `this.table` back in the outer quote, where `this`
exists.

Captured references are recorded so that two uses in one splice share a
parameter. They were keyed by symbol, which is not enough here: two classes of
the quote may inherit the same member, and `open(key) + outer.open(key)` must
not read one object twice. An inherited member is keyed by the whole reference,
`this.open`, instead.

With both changes the three reproductions compile and print `2`. A protected
member read from a nested quote still goes through an accessor — the nested
quote's own check cannot see that the class belongs to an enclosing quote — but
the accessor now reads the member. `tests/pos-macros/quoted-inherited-member`
covers values, methods and a `var`, protected and public, by name and through
`this`, and the two-class case.

The warning itself is unchanged: the compiler still reports a self-recursive
method of expanded code at the macro's use site, and carries on.

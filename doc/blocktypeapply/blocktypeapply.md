# Apply type arguments to a lifted application's expression, not its block

Stops 3.9's typer crashing ("unexpected tree for type application") on a call that uses a default argument in a clause followed by a type-parameter clause.

## Context

Scala 3 lets a method's type-parameter clauses be interleaved with its term
clauses:

```scala
def f(using tc: TC)(flags: List[String] = Nil)[C](g: Int => C): C
```

Here `C` is declared after `flags`, so it is inferred only once the first two
clauses have been applied. Typer handles such a call in steps: it types
`f(using tc0)(flags)` first, and when it finds that the result is still
polymorphic, it infers the type arguments and applies them to the tree it has
built so far, with `appliedToTypeTrees`.

Default arguments complicate what "the tree so far" is. A default is computed
by a synthetic method that takes the *earlier* arguments, because a default may
refer to them:

```scala
f(tc0)(f$default$2(tc0))
```

To pass an earlier argument twice without evaluating it twice, the compiler
*lifts* it: it binds the argument to a local value and puts the call after it
in a block.

```scala
{ val tc$1 = tc0; f(tc$1)(f$default$2(tc$1)) }
```

An argument that is a plain, pure reference need not be lifted; a `using`
argument that had to be resolved, or any argument with side effects, is.

So when the method goes on to a type-parameter clause, the tree typer holds is
a block, and the type arguments were applied to the block itself.
`tpd.TypeApply` expects a function there and asserts otherwise.

## Reproduction

[`repro/`](repro/) — one file, no flags:

```scala
trait TC
given tc0: TC = new TC {}

def f(using tc: TC)(flags: List[String] = Nil)[C](g: Int => C): C = g(0)

val r = f()(identity)
```

```
java.lang.AssertionError: assertion failed: unexpected tree for type application:
  Block(List(ValDef(tc$1,…)),Apply(Apply(Ident(f),…),List(Apply(Select(…,f$default$2),…))))
    at dotty.tools.dotc.ast.tpd$.TypeApply(tpd.scala:58)
    at dotty.tools.dotc.ast.tpd$TreeOps$.appliedToTypeTrees$extension(tpd.scala:1031)
```

Soundness met it with a signature of this shape for opening a resource,
`def open[form](using o: …)(mode: Mode = Read, flags: o.Operand*)[result](block: …)`:
the `using` clause, the default, and the result type declared after them are
each natural, and together they are the recipe.

## Solution

`appliedToTypeTrees` reaches into a block (`ast/tpd.scala`):

```scala
def appliedToTypeTrees(targs: List[Tree])(using Context): Tree =
  if targs.isEmpty then tree else tree match
    case Block(stmts, expr) if stmts.nonEmpty => Block(stmts, TypeApply(expr, targs))
    case _ => TypeApply(tree, targs)
```

The type arguments belong to the call, which is the block's expression; the
bindings before it are unaffected by them and stay where they are, so the
arguments are still evaluated once and in order.

## Upstream

This is upstream's own fix, 481fe77b7ef ("Allow `appliedToTypeTrees` to operate
on block expressions", [#26259](https://github.com/scala/scala3/pull/26259),
for #26238), taken unchanged. It is on `main` and in every 3.10 release but was
not backported to the 3.9 line, where 3.9.0 and `lts-3.9` still crash. The patch
is therefore `obsolete-from` that commit and applies only to 3.9 targets.

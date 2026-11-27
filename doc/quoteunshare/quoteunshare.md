# quoteunshare

Gives each expansion of a quote its own type tree nodes, so that capture checking does not carry the capture sets of one expansion of a macro into another.

## Context

A macro returns code by quoting it: `'{ safely(compute($value)) }`. The quote is
stored in the macro's class file as pickled TASTy, and turned back into a tree
when the macro runs. Unpickling is not cheap, so the compiler keeps the tree in
a cache, and each later use of the same quote in the run takes a **copy** of the
cached tree, so that the definitions inside it — a `val`, a closure, an
anonymous class — are distinct symbols in each expansion.

That copy is made by a map which rebuilds a node only where it has to. A node
which mentions nothing defined in the quote is left as it is, and a *type tree*
— the node holding the type of a `val`, a parameter or an ascription — is
usually one of those. So two expansions of a macro in the same compilation unit
have their own symbols but share many of their type trees.

To every phase but one that is harmless: a type tree is immutable, and its type
is the same for both. The exception is capture checking. It does not change
trees; it works out a *new* type for each type tree and records it against the
node. That type is made for the place the tree occurs: its capture set
variables are owned by the definition it belongs to, and a `^` in it becomes a
root capability of that definition. A node can hold one such type. At the
second expansion the checker finds the node already has one and keeps it — a
type made for the first expansion, whose capture sets may only receive what is
visible *there*.

## How to reproduce it

A macro (`macro.scala`), where `safely` takes a context function and the
compiler makes a closure for its argument:

```scala
class Tactic extends caps.Control

def safely[result](block: (tactic: Tactic^) ?=> result): result = block(using Tactic())
def compute(value: Int)(using Tactic): Int = value

inline def serve(value: Int): Int = ${Macros.serve('value)}

object Macros:
  def serve(value: Expr[Int])(using Quotes): Expr[Int] = '{safely(compute($value))}
```

expanded more than once, at different depths (`client.scala`):

```scala
def first(value: Int): Int =
  val make: () => Int = () => serve(value)
  make()

def second(value: Int): Int = serve(value)
def third(value: Int): Int = serve(value)
```

```
Note that capability `any²` cannot flow into capture set {any}
because any² is not visible from any in an enclosing function.
```

The closure's parameter `tactic` has the type tree `Tactic^`, shared by all
three expansions; its `^` was made a root capability of the first expansion's
parameter, inside `first`'s closure, and the parameter of `second`'s closure is
then compared with it.

This fails on stock scala/scala3 too. In [Soundness](https://soundness.dev) it
is the shape of obligatory's `JsonRpc.serve`, whose generated dispatcher wraps
each decoding step in `safely`, and which a language server expands once per
group of methods; and of telekinesis's `submit`, where the shared node was the
ascription of an anonymous class instance and the message named an inline
proxy (`postable$proxy2 … is not visible from any in value request`).

## Solution

The copy made of a cached quote is given a type tree node of its own for every
occurrence:

```scala
private def unshareTypeTrees(tree: Tree)(using Context): Tree =
  val unshare = new TreeMap:
    override def transform(tree: Tree)(using Context): Tree = tree match
      case tree: TypeTree =>
        TypeTree(tree.tpe, inferred = tree.isInferred).withSpan(tree.span)
      case _ =>
        super.transform(tree)
  unshare.transform(tree)
```

applied where `PickledQuotes.unpickle` returns a copy of the cached tree. The
new nodes have the same types and positions, and keep whether the type was
inferred, so nothing but their identity changes. The first use of a quote
returns the cached tree itself, and every later one a copy sharing no type tree
with it or with another copy.

The fix is made where the sharing arises, not in the capture checker, because
every place the checker records a type against a type tree is affected alike:
parameters, results, ascriptions, type arguments. The patch is always on; it
only turns rejected programs into accepted ones. It is carried from scala/scala3
#27551 on. Earlier upstreams have the defect as well — the reproduction fails on
stock 3.10.1 — and are not covered yet.

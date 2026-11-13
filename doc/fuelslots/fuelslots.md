# Give an uninitialized ContextBase the default fuel for recursive operations

Lets a compiler `ContextBase` that was never initialized — one made just to parse and traverse trees — recurse as deeply as a normal compiler run, rather than failing at the eleventh nested tree.

## Context

The compiler recurses deeply: over nested trees, nested types, chains of
symbol completions. It used to let the JVM stack be the limit, catching
`StackOverflowError` and trying to explain it. From 3.10 it counts instead
(upstream #25937, "Replace catching StackOverflowError with fuel"): each
recursive operation is entered through `handleRecursive`, which records it in
an array on the context base and throws `RecursionOverflow` when the array is
full. The array's length *is* the limit, so that the common case costs one
bounds check:

```scala
val ops = base.recursiveOperations
if depth >= ops.length then throw RecursionOverflow(…)
```

`ContextBase.initialize` allocates that array from `-Xmax-fuel`, 550 by
default. Until then the field held a stopgap:

```scala
// for now give it 10 slots so a few calls to handleRecursive work for trivial
// things before the compiler has really started
private[dotc] var recursiveOperations = Array.fill(10)(RecursiveOperation.blank())
```

Ten is enough for the compiler's own start-up. It is not enough for a program
that uses a context base *without* initializing it, which is a legitimate and
cheap thing to do: `initialize` loads the platform and the definitions from a
classpath, and parsing needs neither. `TreeAccumulator.foldOver` is one of the
recorded operations, so with ten slots any fold over a tree more than ten
levels deep fails.

Soundness's `harlequin` does exactly this to tokenize Scala source for syntax
highlighting: it makes a bare context, parses, and folds over the untyped tree.

## Reproduction

[`repro/`](repro/) — a program against the compiler's API:

```scala
given Context = ContextBase().initialCtx.fresh
val code = "val sum: Int = " + (1 to n).mkString(" + ")
val tree = Parsers.Parser(SourceFile.virtual("sum.scala", code)).parse()
val count = new untpd.UntypedTreeAccumulator[Int]:
  def apply(nodes: Int, tree: untpd.Tree)(using Context): Int = foldOver(nodes + 1, tree)
count(0, tree)
```

A sum is a left-nested chain of infix operations, one level per term. With five
terms it counts 17 nodes; with twelve it throws `RecursionOverflow`, which has
neither a message nor a stack trace, since the compiler means to catch it and
report the operations it recorded. Nothing about the source is unusual: twelve
terms is simply more than ten.

## Solution

The array starts at the setting's default instead (`core/Contexts.scala`):

```scala
private[dotc] var recursiveOperations: Array[RecursiveOperation] =
  Array.fill(ScalaSettings.XmaxFuel.valueIn(ScalaSettings.defaultState))(RecursiveOperation.blank())
```

A base that is never initialized therefore has exactly the room a compiler run
without `-Xmax-fuel` has, and `initialize` still replaces the array with one
sized from the configured value, so nothing changes for a compiler run. The
cost is 550 small objects per context base rather than ten, once.

The default is read from the setting rather than repeated, so the two cannot
drift apart. It is always on: it only makes programs work that failed.

## Bounds

The patch is `needed-from` upstream's introduction of fuel; 3.9 has no such
array and nothing to fix.

## Upstream

Upstream's own bug, reproducible on 3.10.0, 3.10.1 and `main`; worth reporting.
The original report also asked that `RecursionOverflow` say more about itself
when it does escape. That is a separate matter — what it knows is available
from `toMessage` — and is not changed here.

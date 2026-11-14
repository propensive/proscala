# Give the inline calls expanded in an inline trait's child their call traces

Lets a class which extends an inline trait be read back from its own TASTy, where the unpickler stopped with "owner discrepancy" whenever a method of the trait made an inline call on the result of another.

## Context

An **inline trait** (`-language:experimental.inlineTraits`) is a trait whose
definitions are copied into every class that extends it, specialised to that
class's type arguments. The copying is done by the phase
`SpecializeInlineTraits`, in the frontend: *after* PostTyper and *before* the
class is pickled. The copies have the inline calls in them expanded, so the
child's TASTy holds the expansions.

An expanded inline call is an `Inlined` node, with three parts: the *call* it
came from, the *bindings* made for its arguments, and the *expansion*. The call
is kept only to say where the code came from. For an inline call expanded
during typing (a `transparent inline` method), PostTyper replaces it by a **call
trace**: a bare reference to the top-level class of the method. An ordinary
inline call is expanded after pickling, and never reaches TASTy at all.

The calls expanded for an inline trait's child fall between the two: they are
made after PostTyper, so nothing reduces them to traces, and before pickling,
so they are written out in full. A full call holds its arguments as they were
written. If an argument is itself the expansion of an inline call, it holds
that expansion's definitions — and so does the binding the outer node makes for
the same argument. The definitions are then in the tree twice.

The pickler shares a tree it meets a second time, writing a back-reference in
its place, which is sound only for trees without definitions. Here it wrote the
definition of a proxy once, under the method, and a back-reference to it under
the binding. The unpickler, following the back-reference, met a definition it
had already read under a different owner, and its assertion failed.

Every Soundness parser built on `zephyrine.Cursor.Snapshot` is such a class, so
the `core` components of `jacinta`, `xylophone`, `honeycomb` and four more —
2,448 classes — could not be recompiled from TASTy at all; one such class ends
the whole run.

## Reproduction

[`repro/`](repro/) — a library and a class, compiled separately:

```scala
inline trait Snapshot[operand]:
  private def reconcile(): Unit =
    val end = pos
    (mark.z till end.z).each: index =>   // `each`, on the result of `till` and `z`
      count += index.n0

class Parser extends lib.Snapshot[Byte]
```

```
scalac $F -from-tasty -d b -classpath a:l a/app/Parser.tasty

java.lang.AssertionError: assertion failed: owner discrepancy for local value $proxy1 @ 512,
  expected: local value interval$proxy1 @ 875, found: local method lib$Snapshot$$reconcile @ 142
```

## Solution

`Inlines.inlineParentInlineTraits` (`inlines/Inlines.scala`) now gives the
definitions it has inlined from the trait what PostTyper would have given them:

```scala
private def withCallTraces(tree: Tree)(using Context): Tree =
  val traces = new TreeMap:
    override def transform(tree: Tree)(using Context): Tree = tree match
      case tree @ Inlined(call, bindings, expansion)
      if !tree.inlinedFromOuterScope && call.symbol.exists && !call.symbol.isClass =>
        val pos = call.sourcePos
        val trace = inlineCallTrace(call.symbol, pos)(using ctx.withSource(pos.source))
        super.transform(cpy.Inlined(tree)(trace, bindings, expansion))
      case _ =>
        super.transform(tree)
  traces.transform(tree)
```

A node whose call is already a class reference — a trace, or the node the
specialisation itself wraps each copied body in — is left alone. Nothing later
depends on the full call: a node inlined during typing has had only its trace
since PostTyper, and the phases after pickling treat both alike. The bytecode of
a class compiled from source is unchanged.

The patch changes what is *written*. TASTy from an unpatched compiler still
cannot be read, so the child classes must be recompiled once.

## Upstream

Upstream 3.10.0 and `main` crash identically. Inline traits arrived in
upstream #26156, so the patch applies from there on, and not to the 3.9 line.
It is always on, since it only makes a rejected input accepted. Worth reporting
upstream with the reproduction.

That the recompiled class also runs correctly needs
[tastyspecialize](../tastyspecialize/tastyspecialize.md).
`tests/pos/inline-trait-nested-inline` is the reproduction as a test.

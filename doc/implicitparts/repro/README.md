# Reproduction: implicitparts

One file, `parts.scala`, compiled with no flags:

```
scalac -d . parts.scala
```

Without the patch (stock Scala 3.10.0), the compiler crashes:

```
java.lang.AssertionError: assertion failed: `wildApprox` failed to remove uninstantiated value
  at dotty.tools.dotc.typer.ImplicitRunInfo$collectParts$2$.traverse(Implicits.scala:679)
```

With the patch, it compiles.

The shape, from the inside out:

- `box` is a `transparent inline` method whose **result type depends on its
  argument** (`Box[child.type]`), and whose body does a given search mentioning
  that argument: `summonFrom { case given Adm[child.type] => … }`. Inlining
  binds the argument to a proxy, `child$proxy`, so the search is for
  `Adm[child$proxy.type]`, and collecting its implicit scope traverses the
  proxy's **info** — the type of the argument expression.
- The argument is `next`, an inline method whose type parameter `value` is
  inferred from a context parameter, `List[value]`, supplied by the enclosing
  context function.
- The enclosing call, `fuse(box(next))`, takes a context function
  `List[value] ?=> Any` whose own `value` is unconstrained. The whole body is
  typed while `fuse`'s `value` is still an open type variable, and because
  `box`'s result type mentions its argument, the argument's type variable
  cannot be interpolated before `box` is inlined. The proxy's info is therefore
  the open variable; `wildApprox` never sees it, as it only rewrites the
  searched type itself; and the collector's assertion fails.

Each ingredient is needed: with `box`'s result type not depending on `child`
(`Box[Any]`), or `box` not `transparent`, or the type argument given explicitly
(`box(next[String])`), or an ordinary lambda instead of the context function
(`fuse(items => box(next(using items)))`), stock compiles it. The fallback case
of the `summonFrom` is needed too: with a blanket `given [t] => Adm[t]` in
scope and the first case alone, the search is satisfied lexically and its
implicit scope is never collected.

How it was found: by rebuilding, in plain Scala, the shape of Soundness's
`state/next` inside a `fuse` block (exoskeleton's `rig`): `next` is rudiments'
`inline def next[value](using value aka "next")`, `fuse` takes a
`(state aka "state", value aka "next") ?=> state` context function, and `/` is
serpentine's transparent inline method with a `summonFrom` over `child.type`
and the dependent result `Path of (child.type *: Topic)`. The `aka` opaque type,
the `fuse` state, the `Path` class and the `on Plane` refinement all turned out
to be incidental.

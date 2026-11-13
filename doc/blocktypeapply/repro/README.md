# Reproduction: blocktypeapply

One file, no flags and no experimental features:

```
scalac repro.scala
```

Without the patch, on the 3.9 line (3.9.0 and `lts-3.9`), typer crashes:

```
Exception in thread "main" java.lang.AssertionError: assertion failed:
  unexpected tree for type application: Block(List(ValDef(tc$1,…,Ident(tc0))),
    Apply(Apply(Ident(f),List(Ident(tc$1))),List(Apply(Select(…,f$default$2),List(Ident(tc$1))))))
    at dotty.tools.dotc.ast.tpd$.TypeApply(tpd.scala:58)
    at dotty.tools.dotc.ast.tpd$TreeOps$.appliedToTypeTrees$extension(tpd.scala:1031)
    at dotty.tools.dotc.typer.Typer.adapt1(Typer.scala:5227)
```

With the patch the file compiles, as it does on every 3.10 release.

Three things are needed together: a clause with a default argument followed by
a type-parameter clause; a call that uses the default; and an earlier argument
that has to be bound to a local value — here the `using` argument, and an
impure by-value argument (`h(new TC {})()(identity)` for a plain parameter)
does the same. Without the trailing `[C]`, or with `flags` given explicitly,
nothing crashes.

# Reproduction: parenarrow

One file, with capture checking enabled by its own language import:

```
scalac repro.scala
```

Without the patch, on the 3.9 line (3.9.0 and `lts-3.9`), the parser crashes
and no diagnostic is produced:

```
Exception in thread "main" java.lang.AssertionError: assertion failed
    at dotty.tools.dotc.ast.untpd$FunctionWithMods.<init>(untpd.scala:83)
    at dotty.tools.dotc.parsing.Parsers$Parser.functionRest$1(Parsers.scala:1781)
    at dotty.tools.dotc.parsing.Parsers$Parser.typeRest$1(Parsers.scala:1792)
    at dotty.tools.dotc.parsing.Parsers$Parser.typ(Parsers.scala:1848)
```

With the patch the file compiles, as it does on every 3.10 release.

The same crash follows `=>` and `->` in place of `?=>`, and outside a parameter
(`type F[T] = (A & B)^ ?=> T`). Writing the parameter type in parentheses of its
own, `((A & B)^) ?=> T`, avoided it. Without capture checking `^` is not part of
a type, and the source is an ordinary syntax error.

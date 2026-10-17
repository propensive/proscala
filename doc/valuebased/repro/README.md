# Reproduction: valuebased

Two files, compiled together for a Java release older than the JDK that runs
the compiler:

```
scalac -release 17 -d . Macro.scala Use.scala
```

`Macro.scala` defines a macro and boxes an `Int`. `Use.scala` calls the macro
and boxes an `Int` of its own.

Without the patch (upstream `main` from #27318, `67b2e87994`, on), the
compiler crashes while generating code for `Use.scala`:

```
dotty.tools.dotc.core.Denotations$StaleSymbolException: stale symbol;
  trait ValueBased#10220 in module class internal,
  defined in Period(2.1-68), is referred to in run Period(3.97)
```

With the patch, both files compile.

What happens:

- `-release 17` makes the compiler read the platform classes from the JDK's
  `ct.sym`, where `jdk.internal.ValueBased` does not exist and the JDK's
  value-based classes (`java.lang.Integer` among them) refer to it as
  `jdk.internal.ValueBased+Annotation`. `Definitions.JdkInternalValueBasedAnnot`
  synthesizes a class symbol for it when the parser first meets that name,
  in the first run.
- `Use.scala` calls a macro defined in the same compilation, so it is
  suspended and compiled again in a second run of the same compiler
  instance.
- Boxing in `Macro.scala` has the backend read `Integer`'s annotations in
  the first run, attaching the synthesized symbol to them. Boxing in
  `Use.scala` reads them again in the second run; the symbol is from the
  first run, is not `Permanent` and is not entered in any scope, so bringing
  it forward fails.

The test needs a JDK newer than 17 (the fork's workflows use 21): with
`-release` equal to the running JDK's version, the compiler reads the real
runtime image, in which `jdk.internal.ValueBased` exists, and nothing is
synthesized. Likewise, without `-release`, or with `Use.scala` compiled on its
own (one run), nothing goes wrong; the patch changes nothing in those cases.

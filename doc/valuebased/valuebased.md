# Keep the synthetic `jdk.internal.ValueBased` class valid across runs

Marks the class symbol that `Definitions` makes up for `jdk.internal.ValueBased` under `-release` as `Permanent`, so that a compilation whose second run looks at a JDK class's annotations no longer crashes with a `StaleSymbolException`.

Always on: it only turns a compiler crash into a compilation.

## Context

JEP 390 (JDK 16) annotates the JDK's value-based classes — `java.lang.Integer` and the other boxes, `Optional`, `LocalDate`, … — with `@jdk.internal.ValueBased`, and the compiler uses the annotation to warn about `synchronized` on such a value. Under `-release N` (`-java-output-version N` is the same setting) with a newer JDK running, the compiler reads the platform classes from the JDK's `ct.sym`, which holds only exported API: there is no `jdk.internal.ValueBased` class in it, and the classfiles refer to the annotation by the stand-in name `jdk.internal.ValueBased+Annotation`. Upstream #27318 (16 October 2026) teaches the classfile parser that name and, since there is no class to resolve it to, has `Definitions.JdkInternalValueBasedAnnot` synthesize one, as javac does:

```scala
@tu lazy val JdkInternalValueBasedAnnot: Symbol = getClassIfDefined("jdk.internal.ValueBased").orElse {
  val pkg = getPackageClassIfDefined("jdk.internal")
  if pkg.exists then
    val flags = JavaDefined | JavaAnnotation | PureInterfaceCreationFlags | Abstract
    completeClass(newCompleteClassSymbol(pkg, "ValueBased".toTypeName, flags, List(ObjectType, JavaAnnotationClass.typeRef), newScope))
  else NoSymbol
}
```

`Definitions` belongs to the compiler instance (the `ContextBase`), not to a run, and a `@tu lazy val` is computed once. Every other class `Definitions` creates is flagged `Permanent`, through `newPermanentClassSymbol` or `enterCompleteClassSymbol`; `SymDenotations.stillValid` accepts a `Permanent` symbol in any run without looking further. This one is created with plain `newCompleteClassSymbol`, and is not entered in `jdk.internal`'s scope either, so it is valid for exactly the run that created it. When a later run of the same compiler instance meets it, `bringForward` asks `stillValid`, which finds it neither permanent nor among its owner's declarations, and compilation dies:

```
dotty.tools.dotc.core.Denotations$StaleSymbolException: stale symbol;
  trait ValueBased#15976 in module class internal,
  defined in Period(2.1-69), is referred to in run Period(3.97)
```

A second run is not exotic. `Driver.finish` compiles the units that were *suspended* — a unit that calls a macro defined in the same compilation waits for the macro's classes and is compiled again in a fresh run — and every line of the REPL is a run. And the annotation sits on classes nearly every program touches: the backend reads it whenever it boxes a primitive (`boxedClassOfPrimitive` → `javaFlags` → `isScalaStatic` → `hasAnnotation`), at which point `LazyAnnotation.symbol` sees a symbol from an earlier run and refreshes it through `sym.denot`.

Building the fork itself is where this showed up. The `scala3-repl` module is compiled with `-java-output-version 17`; it contains the `sourcecode` macros, and `Fansi.scala` uses them, so Fansi is suspended and compiled in a second run, whose `genBCode` crashed exactly as above on the first boxed `Int`. From #27318 on, upstream `main` could not be built with the patches, by `make` or by the release workflow.

## Reproduction

`repro/` holds two files. `Macro.scala` defines a macro and boxes an `Int`; `Use.scala` calls the macro — which gets it suspended — and boxes an `Int` of its own:

```scala
// Macro.scala
import scala.quoted.*

object Macro:
  inline def greeting: String = ${ impl }
  def impl(using Quotes): Expr[String] = Expr("hello")
  val boxed: Any = 1

// Use.scala
object Use:
  val s: String = Macro.greeting
  val boxed: Any = 2
```

Compiled together for a release older than the running JDK:

```
scalac -release 17 -d . Macro.scala Use.scala
```

Without the patch, on upstream `main` from #27318 on, the compiler crashes with the `StaleSymbolException` above while generating code for `Use.scala` in the second run. With it, both files compile.

Each ingredient is needed. Without `-release`, the real `jdk.internal.ValueBased` is on the classpath and nothing is synthesized. Without the macro, there is one run and nothing is stale. The boxing in `Macro.scala` is what first attaches the annotation to `java.lang.Integer` in the first run, so that the second finds it there.

## The solution

The patch adds the flag the other synthesized classes carry:

```scala
val flags = JavaDefined | JavaAnnotation | PureInterfaceCreationFlags | Abstract | Permanent
```

`Permanent` is one of `ValidForeverFlags`, so `stillValid` is true for the symbol in every run and `bringForward` simply extends its validity. Its constructor, created by `completeClass`, is entered in the class's own scope, so it is valid whenever the class is. Nothing else changes: the warning on `synchronized` still fires, the class is still not entered in `jdk.internal`, and when the real class is on the classpath it is still preferred.

The patch is needed only from #27318 (`67b2e87994`), which neither release line carries at the time of writing; its `meta` says so. Upstream candidate.

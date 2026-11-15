# Singleton arguments spliced by a macro

Lets a macro pass a value as the argument for a parameter of that value's own singleton type under capture checking, which was rejected when the value's type has a capture set.

Always on: this accepts programs that were rejected with a spurious error, and changes nothing for a program that compiled.

## Context

Under capture checking (`-language:experimental.captureChecking`), the checker compares each expression's type with the type expected of it. First it *adapts* the expression's type (`CheckCaptures.adapt`). A reference `x` usually has the singleton type `x.type`, and adaptation widens it to `x`'s declared type, narrowing the capture set to `{x}`. That is what lets `x` be passed where an ordinary type is expected.

If the expected type is itself a singleton, widening would lose the one fact that matters, so adaptation keeps `x.type` (`noWiden`). And if the expected type is a *boxed* singleton, `box x.type^{x}`, as a type argument is, adaptation boxes `x.type` to match.

When a macro splices an expression into its result (`'{calc[T]($x)}`), the spliced expression is wrapped in an `Inlined` node. The checker adapts the reference inside the node, and then the node itself, whose type is the type of what it contains.

## The problem

```scala
// Macro_1.scala
import scala.quoted.*

class Path

def calc[T <: Path^](x: T): Int = 1
inline def go[T <: Path^](x: T): Int = ${goImpl[T]('x)}
def goImpl[T <: Path^](x: Expr[T])(using Type[T], Quotes): Expr[Int] = '{calc[T]($x)}

// Test_2.scala
def f(io: Object^, xs: List[Path^{io}]) = xs.map: path =>
  go[path.type](path)
```

The expansion is `calc[path.type](path)`. The parameter of `calc` then has type `box path.type^{path}`, and the argument fails to conform to it:

```
Found:    Path^{io}
Required: (path : Path^{io})^{path}
```

The reference `path` is adapted correctly, to `box path.type^{path}`. Then the `Inlined` node around it is adapted, starting from that type. `noWiden` asked whether it was a singleton by `isSingleton`, which is false for a capturing type. It stripped the capture set from the *expected* type before asking, but not from the actual one. So the already-adapted singleton was widened to `path`'s declared type `Path^{io}`, which is no subtype of `path.type`.

Without the macro there is no `Inlined` node and nothing is adapted twice. When `path` is a method parameter, rather than a lambda's, the call happens to compile too. Stock 3.10.0 rejects the reproduction.

## The solution

`noWiden` now strips the capture set from the actual type as it does from the expected one:

```scala
private def noWiden(actual: Type, expected: Type)(using Context): Boolean =
  actual.stripCapturing.isSingleton
  && expected.match
      case expected: PathSelectionProto => !expected.selector.isOneOf(UnstableValueFlags)
      case _ => expected.stripCapturing.isSingleton || expected == LhsProto
```

A singleton that has already been adapted stays a singleton, and adapting it again changes nothing. The comparison that follows is upstream's, unchanged: a spliced value whose captures exceed what the type parameter allows (`path: Path^{io}` for `T <: Path`) is still rejected; the reproduction checks this too.

## Relevance to Soundness

Serpentine's `toward` and `conjunction` are transparent inline extensions whose type parameters are meant to be `Precise`. That way a path argument is inferred as its singleton type, and the macro can read the path's structure from it:

```scala
extension [path <: Path: Precise](left: path)
  transparent inline def toward[target <: Path: Precise](target: target): Optional[Relative] =
    ${serpentine.internal.toward[path, target]('left, 'target)}
```

The macro splices the arguments into calls such as `'{$left.calculate($right)}`. With the bound in force, `workingDirectory.toward(path)` in `exoskeleton.Pathname`, where `path` is a lambda parameter, failed exactly as above. That is why serpentine dropped the bound (soundness#1811). With the patch, the module compiles with the bound restored.

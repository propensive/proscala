# Unify the capture variables of an overriding method's parameters

Lets a class in the expansion of an inline method override a method whose parameter type comes from an inferred type argument of the call, which capture checking rejected — on Scala.js, for any typeclass instance written as a lambda there.

Always on: this accepts programs that were rejected with a spurious error, and changes nothing for a program that compiled.

## Context

Under capture checking (`-language:experimental.captureChecking`) a type carries a *capture set*, and where a type was inferred rather than written, the phase `cc.Setup` adds a capture set *variable* to it, `Point^'s1`, for the checker to fill in. A variable is *solved* — fixed at what it holds — once the definition it belongs to has been checked; for a class member that means the variables of its inferred result type. Parameter types are written out, so they have none.

An inline method is the exception. A type argument that was *inferred* for an inline call is marked `@inferred` (by `PostTyper`), and the mark travels with it into the expansion, so that `Setup` treats every occurrence of the argument there as an inferred type. Each occurrence gets a variable of its own.

Finally, overrides are checked last, by `RefChecks`' rules with frozen constraints (`frozen_<:<`): nothing may be inferred while checking them. For capture sets that means an unsolved variable is a subset of nothing but itself. And an overriding method's parameter types must be *the same* as those it overrides.

## The problem

```scala
import language.experimental.captureChecking

class Point

trait Inspectable:
  type Self
  def text(value: Self): String

inline def derived[value](x: value): Inspectable { type Self = value } =
  new Inspectable:
    type Self = value
    def text(arg: value): String = "x"

def test(point: Point) = derived(point)
```

`value` is inferred as `Point`, a class that may capture, so in the expansion the class reads `type Self = Point^'s2` and `def text(arg: Point^'s1)`. The method it overrides takes a `Self`, that is `Point^'s2`. Nothing ever related `'s1` to `'s2`, neither is solved, and the frozen check fails:

```
error overriding method text in trait Inspectable of type (value: Self): String;
  method text of type (arg: Point^'s1): String has incompatible type
```

Written `derived[Point](point)`, the same call compiles, since an explicit argument gets no variables. Upstream 3.9.0, 3.10.0 and `main` all reject the inferred one.

The class need not be in the source. A lambda converted to a SAM type stays a closure on the JVM, typed as the expected type, and no members are compared. But `SJSPlatform.isSam` accepts only function types, so under `-scalajs` the phase `ExpandSAMs`, which runs before capture checking, makes an anonymous class of the lambda — the class above. So

```scala
inline def derived[value](x: value): Inspectable { type Self = value } = arg => "x"
```

compiles on the JVM and fails when cross-compiled to Scala.js ([repro-sam](repro-sam/README.md)), however the instance is spelt.

## The solution

Before the overrides of a class are checked, `CheckCaptures` now goes through its overriding pairs and compares the parameter types of each pair *without* freezing, which makes their capture set variables include each other; then it solves the variables it unified:

```scala
def sameWhenUnified(tp1: Type, tp2: Type): Boolean =
  !TypeComparer.isSameTypeWhenFrozen(tp1, tp2)
  && withAtomicIncludes(TypeComparer.atomicOp(TypeComparer.isSameType(tp1, tp2)))
...
if sameWhenUnified(formal1, formal2a) then unified += formal1 += formal2a
...
unified.foreach(solveVars.traverse)
```

Three details matter:

- **Every pair is unified before any variable is solved**, so the result does not depend on the order of the members.
- **Solving is what lets the frozen check succeed.** Each time a member's type is taken as seen from the class, an unsolved variable is mapped to a new variable derived from it, so the check never sees the same two variables twice. A solved variable maps to a constant. It can be solved here because overrides are checked after everything that could add to it.
- **The attempt must leave nothing behind when it fails.** A variable that could not take an element withdrew it from itself, but not from the sets depending on it that had already accepted it; the comparer, trying the comparison another way, then found the element there and succeeded. Elsewhere a failed comparison is an error and this goes unnoticed. While unifying, an inclusion is atomic (`CCState.withAtomicIncludes`), and nowhere else.

The check that follows is upstream's, unchanged. A method that needs its parameter pure still cannot implement one that is passed a capability: unifying fails, and the override is reported as before.

One case remains rejected under `-scalajs` though accepted on the JVM: a lambda for a trait which takes the inferred argument as a *type parameter* (`F[value]`, not `{ type Self = value }`), when a capability is later passed to the method. It compiles when nothing is.

## Relevance to Soundness

Soundness writes typeclasses as SAM traits with a `Self` member, and instances as lambdas. `Inspectable.derived` in `lib/spectacular` is an inline given which chooses by the givens available for `value`; for an `Optional` it is

```scala
case mandatable: (`value` is Mandatable) =>
  val inspectable = compiletime.summonInline[mandatable.Result is Inspectable]

  optional =>
    optional.let: present =>
      s"｢${inspectable.text(present.asInstanceOf[mandatable.Result])}｣".tt

    . or("○".tt)
```

Calling `.inspect` on an `Optional[Point]` infers the type argument, so the JavaScript builds of `savagery` and `archimedes` failed with the error above, while their JVM builds were clean; both had rendered the value by hand instead.

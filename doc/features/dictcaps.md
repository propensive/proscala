# Infer the capture set of recursive-implicit dictionary instances

Stops the capture checker from rejecting a memoized recursive/by-name implicit when one of the memoized entries is capability-typed, by giving the synthetic dictionary instance an inferred capture set instead of the bare dictionary class type.

## Context

Scala 3's experimental capture checking (`-language:experimental.captureChecking`, with strict mutability under `-Ycc-new`) tracks which *capabilities* a value captures. A value whose type carries no capabilities is *pure*; a value that retains a capability is typed `T^{...}`.

When an implicit search resolves a **recursive** or **by-name** implicit — the pattern behind typeclass derivation for recursive or mutually-referential types — the compiler cannot expand the resolution inline (it would diverge). Instead `SearchRoot.emitDictionary` (`compiler/src/dotty/tools/dotc/typer/Implicits.scala`) memoizes the resolved instances into a synthetic *dictionary* class whose fields are `lazy`-style vals holding each entry, and emits a block:

```scala
{
  class <dictionary> { val $_lazy_implicit_$0 = ...; ...; val $_lazy_implicit_$n = ... }
  val $_lazy_implicit_$nn = new <dictionary>
  result   // with dictionary references substituted in
}
```

The result term refers to entries through the single `$_lazy_implicit_$nn` instance, so the recursion is tied off by field self-reference rather than by re-resolving.

## The problem

The memoizing instance val was created with the **bare** dictionary class type:

```scala
val valSym = newLazyImplicit(classSym.typeRef, span)
val inst = ValDef(valSym, New(classSym.typeRef, Nil))
```

Under capture checking, if any dictionary entry is capability-typed — for example a derived codec that retains a `Tactic`, or any instance whose result is `T^{c}` — then constructing the dictionary (`new <dictionary>`) captures those capabilities, so `new <dictionary>` has type `<dictionary>^{...}`. But `valSym` was declared with the pure `classSym.typeRef`, so the capturing constructor no longer conforms to the val's own declared type, and capture checking reports:

```
Found:    $_lazy_implicit_$3^{c, any}
Required: $_lazy_implicit_$3
```

This blocked, for instance, deriving a JSON/codec decoder for a product type that shares a sub-type (so the shared decoder is memoized) whose leaf decoders are honest capability-typed instances.

Minimal reproduction (previously errored on the `new <dictionary>` instance; now compiles) is the new test at `tests/pos-custom-args/captures/dictcaps.scala`:

```scala
import language.experimental.captureChecking

class Cap
trait Foo[T]

object Foo:
  implicit def intFoo(implicit c: Cap^): Foo[Int]^{c} = new Foo[Int] {}
  implicit def pair[T, U]
      (implicit fe: => Foo[Int]^, fooT: => Foo[(T, U)]^, fooU: => Foo[(U, T)]^): Foo[(T, U)] =
    new Foo[(T, U)] {}
  implicit def string: Foo[String] = new Foo[String] {}

def test(implicit c: Cap^): Foo[(Int, String)] = implicitly[Foo[(Int, String)]]
```

## The solution

The dictionary instance is a private implementation detail of the memoization: its captures are exactly those of the entries it holds, and the *escaping* value is the substituted result term, whose type is unchanged. So the instance val's type should simply be **inferred** from its right-hand side rather than fixed to the bare class type. Passing `inferred = true` to the synthesized `ValDef` marks its type tree as an `InferredTypeTree`, which is precisely the signal the capture-checking `Setup` phase uses to attach a capture-set variable and solve it against the constructor:

```scala
val inst = ValDef(valSym, New(classSym.typeRef, Nil), inferred = true)
```

For a dictionary whose entries are all pure the inferred set solves to empty, so the emitted code is unchanged from before; only the capability-carrying case, which previously did not type-check at all, is affected. The change is gated implicitly by capture checking: when capture checking is off, an inferred vs. explicit type tree for this synthetic val makes no observable difference.

## Code

`compiler/src/dotty/tools/dotc/typer/Implicits.scala`, in `SearchRoot.emitDictionary`:

```scala
val valSym = newLazyImplicit(classSym.typeRef, span)
val inst = ValDef(valSym, New(classSym.typeRef, Nil), inferred = true)
```

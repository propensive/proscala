# structuralarg

Fixes a compiler crash on a structural call whose argument's type has no class symbol.

## Context

A member selected through a structural refinement is not a member of any class
the compiler knows, so the call is rewritten into a dynamic one. With
`scala.reflect.Selectable.reflectiveSelectable` in scope,

```scala
def test(crypto: Crypto { def ecdsa(digest: Text): Int }, digest: Text): Int =
  crypto.ecdsa(digest)
```

becomes `crypto.applyDynamic("ecdsa", classOf[...])(digest)`, which finds the
method by reflection.

Reflection passes arguments as objects, so an argument which is a *value class*
— a class whose instances are represented at run time by the single field they
wrap — must be unwrapped first, or the method receives the wrapper where it
expects the field. scala/scala3 #17564 added that: for each argument of a
structural call it asks whether the argument's class is a value class, and if
so selects its underlying field.

It finds the class with `argument.tpe.resultType.classSymbol.asClass`. Not
every type has a class symbol. An intersection of two unrelated classes has
none, and nor does an abstract or opaque type whose upper bound is such an
intersection. For those `classSymbol` is `NoSymbol`, and `asClass` on it throws:

```
java.lang.ClassCastException: NoSymbol cannot be cast to ClassSymbol
  at dotty.tools.dotc.typer.Dynamic.handleRepeated
```

The compiler crashes on a program which is well typed, from 3.10.2-RC1 on.

## How to reproduce it

No options are needed:

```scala
import scala.reflect.Selectable.reflectiveSelectable

object types:
  opaque type Text <: Matchable & Serializable = String
  def text(string: String): Text = string

class Crypto

def test(crypto: Crypto { def ecdsa(digest: types.Text): Int }, digest: types.Text): Int =
  crypto.ecdsa(digest)
```

The opaque alias `Text` is bounded by `Matchable & Serializable`, two classes
neither of which extends the other, so outside `types` it has no class symbol.

[Soundness](https://soundness.dev) meets exactly this. Its `Text` is

```scala
into opaque type Text <: Matchable & caps.Pure = String & caps.Pure
```

and enigmatic reaches the algorithms a cryptographic provider may or may not
offer through structural refinements, so that a provider without one is a
compile error where it is asked for, not a failure at run time:

```scala
given value: [bits <: 256 | 384 | 521: ValueOf]
=>  ( digest: Signature.Digest,
      crypto: Crypto { def ecdsa(digest: Text): Crypto.SignatureScheme } )
=>  Ecdsa[bits] =
  Ecdsa(crypto.ecdsa(digest.token))
```

Every such call crashed the compiler.

## Solution

A type without a class symbol is not a value class, so there is nothing to
unwrap, and the argument is passed as it is. The patch asks whether there is a
class before treating the symbol as one:

```scala
val clzSym = t.tpe.resultType.classSymbol
if clzSym.isClass && clzSym.isDerivedValueClass && isReflectSelectable then
  val underlying = ValueClasses.valueClassUnbox(clzSym.asClass).asTerm
  tpd.Select(t, underlying.name)
else
  t
```

Arguments which are value classes are unwrapped exactly as upstream unwraps
them; only the case which crashed is different.

The patch is always on, as a crash fix. It applies from #17564 on, which is in
3.10.2-RC1 and later but not in 3.10.0 or 3.10.1.

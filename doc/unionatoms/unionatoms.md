# Singletons in unions under capture checking

Makes a singleton type conform to a union containing it under capture checking, which failed for the members of any object.

Always on: this accepts programs that were rejected with a spurious error, and changes nothing for a program that compiled.

## Context

The compiler decides many subtype tests against a union of singletons without looking at the union's structure, through *atoms*. The atoms of a singleton type are the values it can denote, and the atoms of a union are the atoms of its members. `x.type <: a.type | b.type` holds if `x`'s atoms are among the union's, and fails outright if one is not. This shortcut is `TypeComparer.compareAtoms`, and it answers without trying each member of the union.

For two atoms to compare equal, they are *normalized*. A singleton whose underlying type is another singleton stands for the same value, so `Type.atoms` follows such chains. It also rewrites prefixes the same way: `this` in object `P` has the underlying type `P.type`, so the atom `P.this.k1` is normalized to `P.k1`.

A union computes its atoms once per run and caches them (`OrType.atoms`). So the atoms of a union in the source are usually found while typing, and reused by every later phase, capture checking included.

## The problem

```scala
import language.experimental.captureChecking

class Kind

object P:
  val k1 = Kind()
  val k2 = Kind()
  val e: k1.type = k1
  val f: k1.type | k2.type = e
```

Under capture checking, this fails:

```
Found:    (P.e : (P.k1 : Kind^{}))
Required: (P.k1 : Kind^{}) | (P.k2 : Kind^{})
```

`val f: k1.type | k2.type = k1` fails too, as do `def m(x: k1.type): k1.type | k2.type = x` and unions of objects nested in an object or a method. It is upstream's behaviour: stock 3.9.0 and 3.10.0 reject the file.

The cause is a difference between the atoms found while typing and those found while capture checking. Capture checking's `Setup` phase gives the class of an object an inferred self type with a capture set variable, so during capture checking `this` in `P` has the underlying type `P.type^{'s}`. That is a capturing type, not a singleton, so normalization stops there:

| | atom of `k1` |
| - | - |
| the union, cached while typing | `P.k1` |
| `e`, found while capture checking | `P.this.k1` |

The atom of `e` is not among the union's, so `compareAtoms` answers false. The comparison never reaches the ordinary rule that would show `k1.type <: k1.type`.

An object directly in a package is unaffected: its prefix is the package, which keeps its own type.

## The solution

When normalizing an atom, `Type.atoms` now strips any capture set from the singleton's underlying type before testing whether it is a singleton:

```scala
def normalize(tp: Type): Type = tp match
  case tp: SingletonType =>
    tp.underlying.dealias.stripCapturing match
      case tp1: SingletonType => normalize(tp1)
      ...
```

A capture set says what a value may capture, not which value it is, so it has no place in an atom. Normalization now gives the same atom in every phase, and the cached atoms of a union agree with those found later. Atoms of different values still differ, so `k3.type <: k1.type | k2.type` is rejected as before.

## Relevance to Soundness

Soundness accumulates a union of singleton types through a contravariant capability. `raises` does this for errors, and exoskeleton for exit statuses:

```scala
trait Registry[-status]
class Status(val code: Int) extends caps.Pure:
  def exit(using Registry[this.type]): Int = code

object A extends Status(1)
object B extends Status(2)
def ab(using Registry[A.type | B.type]): Int = if cond then A.exit else B.exit
```

A `Registry[A.type | B.type]` serves as a `Registry[A.type]` only if `A.type <: A.type | B.type`. So under capture checking this worked only for top-level objects, and exoskeleton's `Status` API documents that statuses must be declared at the top level. With the patch, statuses can be nested in an object or a method.

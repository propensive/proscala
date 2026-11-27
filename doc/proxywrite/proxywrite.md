# proxywrite

Lets the reference decide whether a value typed as an intersection with that reference may be written through, so that a write through an inline method on an opaque alias of an array is not refused.

## Context

Under capture checking with separation checking, an array is a *stateful*
value: its `update` method may be called only through a reference which holds
the array **exclusively**. Whether it does is read from the reference's capture
set. `Array[String]^` is exclusive; `Array[String]^{}`, a frozen array, is
read-only, and writing through it is an error:

```
Cannot call update method update of frozen
since its capture set {} of value frozen is read-only.
```

An **opaque type alias** hides its right-hand side outside the scope which
defines it. When an `inline` method defined inside that scope is expanded
outside it, the expansion must still see through the alias, or the body would
not typecheck. The inliner arranges this with a *proxy*: a value standing for
the alias's prefix, typed with a refinement that reveals the alias, and a cast
of the receiver to an intersection type:

```scala
val $proxy1: p.type{type Arr[element] = Array[element]} = p.asInstanceOf[...]
arr.asInstanceOf[(arr : p.Arr[String]^) & $proxy1.Arr[String]].update(1, "")
```

The left operand is the receiver's own singleton type. The right operand,
`$proxy1.Arr[String]`, is `Array[String]` to anything which looks: it is what
tells the compiler the receiver is an array at all, and so stateful. But it has
no capture set, because the proxy stands for the object `p`, not for the array.

The capture set of an intersection is the *meet* of its operands' sets: a value
of type `A & B` captures only what both types allow. Here that is `{arr}`
meeting `{}`, which is empty. The check for exclusive access reads the capture
set of the whole receiver type, finds it empty, and concludes that `arr` is
read-only, however it is held. From scala/scala3 3.10.2-RC1 on, every such
write is refused; 3.10.0 and 3.10.1 accept it.

## How to reproduce it

Compiled with `-experimental`:

```scala
import scala.language.experimental.captureChecking
import scala.language.experimental.separationChecking

object p:
  object Arr:
    def allocate[element](size: Int): Arr[element]^ =
      new scala.Array[AnyRef](size).asInstanceOf[scala.Array[element]]

    extension [element](inline buffer: Arr[element]^)
      inline def update(index: Int, value: element): Unit = buffer(index) = value

  opaque type Arr[element] = scala.Array[element]

def test(): Unit =
  val arr: p.Arr[String]^ = p.Arr.allocate[String](3)
  arr(1) = ""
```

```
Cannot call update method update of (arr : p.Arr[String]^) & $proxy1.Arr[String]
since its capture set {} of value $proxy1 is read-only.
```

This is the shape of `proscenium.Array` in [Soundness](https://soundness.dev),
an opaque alias of `scala.Array` whose `apply` and `update` are inline so that
a write with a concrete element type compiles to the JVM's own array store.
Every `array(index) = value` outside `proscenium` was refused.

## Solution

A value of type `x.type & T` *is* `x`: the singleton operand names the very
reference, and `T` can only add knowledge of what kind of value it is. So the
two questions the check asks are answered from different places. Whether the
value is stateful is asked of the whole intersection, as before, since it may
be `T` alone which shows that. Whether it may be written through is asked of
`x`:

```scala
private def exclusivityInContext(required: Boolean = false, classified: Type = NoType)(using Context): Exclusivity =
  def stateful = classified.orElse(tp)

  def ofSingleton(ref: SingletonType) =
    ref.exclusivityInContext(required, stateful) match
      case Exclusivity.ReadOnly(_) => Exclusivity.ReadOnly(tp)
      case ex => ex

  tp match
    ...
    case AndType(tp1: SingletonType, _) => ofSingleton(tp1)
    case AndType(_, tp2: SingletonType) => ofSingleton(tp2)
    case _ => tp.exclusivity(required, stateful)
```

`classified` carries the intersection down to where the reference's own
capture set is examined, so that `arr`, whose type `p.Arr[String]` is opaque
there and is not known to be stateful, is still checked as the array the
intersection shows it to be.

That last point is what keeps the change sound, and makes it slightly stricter
than upstream in one place. A reference which is read-only is still refused:

```scala
val frozen: p.Arr[String]^{} = caps.unsafe.unsafeAssumePure(arr)
frozen(1) = ""   // error: its capture set {} is read-only
```

The patch is always on: it turns a spurious error back into the accepted
program it was on 3.10.0 and 3.10.1. An intersection of two types neither of
which is a singleton is checked as upstream checks it.

# inferredmeet

Pulls the capture sets out of the intersection type inferred for an instance of an anonymous class or for a closure parameter, so that the value has one capture set.

## Context

Under capture checking a type may carry a capture set, `T^{c}`. For an
intersection there are two ways to write the same thing: a capture set on each
operand, `A^{c1} & B^{c2}`, or one on the whole, `(A & B)^{c}`, where `c` is the
*meet* of `c1` and `c2` — what both allow. The second is the form everything
else in the checker expects: a value's capture set is read from the outside of
its type, and operations which adapt or strip it look there.

Until scala/scala3 #27539 the phase which prepares types for checking, `Setup`,
rewrote the first form to the second. #27539 removed the rewrite, for a sound
reason: during `Setup` the elements of some capture sets are not known yet, and
the meet of two such sets can come out too small.

That reason does not hold for the type the compiler infers for an instance of
an anonymous class with more than one parent, which is the intersection of the
parents. There `Setup` has just put a fresh **capture set variable** on each
operand, to be filled in by the checking which follows, and both variables
describe the one object: their meet decides nothing early, being itself a
variable tied to both. But without the rewrite the instance keeps one variable
per parent, and from 3.10.2-RC1 on it stopped working in two ways.

## How to reproduce it

Compiled with `-experimental`:

```scala
import scala.language.experimental.captureChecking

trait Handle extends caps.ExclusiveCapability:
  type Under

trait Granting[+grants]

def open[filesystem, result](block: (Handle { type Under = filesystem } & Granting[Int]) ?=> result): result =
  val handle =
    new Handle with Granting[Int]:
      type Under = filesystem

  block(using handle)
```

```
Found:    (handle : (Handle & Granting[Int]^){type Under = filesystem^{}})
Required: ((Handle{type Under = filesystem}^{any}) & Granting[Int])^{any²}
Note that capability `any²` cannot flow into capture set {any}.
```

The instance does not conform to its own intersection type. And
`caps.unsafe.unsafeAssumePure`, which strips the capture set from the outside
of its argument's type, finds none there to strip:

```scala
def daemon(using monitor: Monitor^): Daemon =
  caps.unsafe.unsafeAssumePure:
    new Worker(monitor) with Daemon:
      type Result = Unit
      def name: String = ""
```

```
Found:    ((Worker{val parent: Monitor^}^{monitor}) & (Daemon^{monitor})){type Result = Unit}
Required: Daemon
```

Both are from [Soundness](https://soundness.dev): galilei's handle on an open
directory is `new Handle with Granting[grants]`, a capability which also
records what it grants, and parasite's daemons and tasks are
`new Worker(...) with Daemon`, a supervised worker handed out as a pure handle.

## Solution

The patch makes the rewrite again, in the map which handles inferred types,
in two places — for the type of an anonymous class instance (the ascription the
typer gives `new A with B { ... }`, and the type of a definition it is the
right-hand side of), and for the type of a parameter of a closure, which takes
an intersection from the function type the closure is expected to have and
failed in the same way (`open(...)(block)` in Soundness's aperture, whose block
receives `(Result & Granting[Grants])^`) — and only where both sets are
variables:

```scala
def meetCaptures(tp: Type): Type = tp match
  case AndType(tp1 @ CapturingType(parent1, refs1), tp2 @ CapturingType(parent2, refs2))
  if meetIntersections && tp1.isBoxed == tp2.isBoxed && !refs1.isConst && !refs2.isConst =>
    CapturingType(AndType(parent1, parent2), refs1 ** refs2, tp1.isBoxed)
  case _ => tp
```

`refs1 ** refs2` is the meet. Of two variables it is a variable which receives
whatever is added to both, so nothing is settled before the sets are known:
the hazard #27539 avoided does not arise.

Every other intersection is left as upstream leaves it, and one case shows why
the rewrite must not be general. A variable bound by a typed pattern,
`case typeclass: T => typeclass`, has the scrutinee's type meeting `T`, and the
two operands are checked separately: the value may be used as a pure `T`
whatever the scrutinee captured. Merging the two capture sets there carries the
scrutinee's capabilities into `T`, and rejects code which relies on the pattern
— as an earlier form of this patch did to every derived typeclass instance in
Soundness.

The patch is always on: it restores what 3.10.0 and 3.10.1 accept. It applies
from #27539 on.

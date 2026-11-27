# inferredmeet

Pulls the capture sets of an inferred intersection type out of it again, so that an instance of an anonymous class with several parents has one capture set.

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

That reason does not hold for a type the compiler *inferred*. There `Setup` has
just put a fresh **capture set variable** on each part, to be filled in by the
checking which follows, and the meet of two variables decides nothing early: it
is itself a variable, tied to both. But without the rewrite, inferred
intersections keep one variable per operand, and the commonest source of an
inferred intersection — the instance of an anonymous class with more than one
parent — stopped working in two ways from 3.10.2-RC1 on.

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

The patch makes the rewrite again in the one map which handles inferred types,
and only where at least one of the two sets is a variable:

```scala
def meetCaptures(tp: Type): Type = tp match
  case AndType(tp1 @ CapturingType(parent1, refs1), tp2 @ CapturingType(parent2, refs2))
  if tp1.isBoxed == tp2.isBoxed && (!refs1.isConst || !refs2.isConst) =>
    CapturingType(AndType(parent1, parent2), refs1 ** refs2, tp1.isBoxed)
  case _ => tp

def addVar(tp1: Type, orig: Type) =
  decorate(
    addCaptureRefinements(normalizeCaptures(meetCaptures(normalizeFunctions(tp1, orig)))),
    ...)
```

`refs1 ** refs2` is the meet. With a variable among its operands it is a
variable which receives whatever is added to both, so nothing is settled
before the sets are known: the hazard #27539 avoided does not arise. An
intersection whose two capture sets are both constants — one written in the
source — is left as upstream leaves it, as is every type which was not
inferred.

The patch is always on: it restores what 3.10.0 and 3.10.1 accept. It applies
from #27539 on.

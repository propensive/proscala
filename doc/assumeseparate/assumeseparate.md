# Keep an unsafeAssumeSeparate operand's own type

Stops `caps.unsafe.unsafeAssumeSeparate` from turning an exclusive capability into a read-only one, so the block it wraps keeps its type.

Always on: it only turns programs that upstream rejects into accepted ones.

## Context

Separation checking rejects two uses of a capability that might overlap. Where
the programmer knows better, `caps.unsafe.unsafeAssumeSeparate` lifts the check
for one expression:

```scala
def unsafeAssumeSeparate(op: Any): op.type = op
```

Its documentation says the operand is "returned as-is", and the separation
checker recognises the call by its symbol. The capture checker, though, treats
it as an ordinary call: the operand is passed for a parameter of type `Any`.
Under separation checking, passing an exclusive capability to a parameter whose
type is not stateful only reads it, so the result — `op.type`, widened — can be
read-only. A block wrapped in `unsafeAssumeSeparate` can then no longer be
returned or passed where an exclusive capability is required.

## Reproducing it

```scala
trait Sink extends caps.ExclusiveCapability, caps.Stateful:
  update def put(i: Int): Unit

def pass(consume sink: Sink^): Sink^ = scala.caps.unsafe.unsafeAssumeSeparate(sink)
```

Scala 3.10.0 rejects it:

```
Found:    Sink^{any.rd}
Required: Sink^{any²}
Note that {any²} is an exclusive capture set of the stateful type Sink^{any²},
it cannot subsume a read-only capture set of the stateful type Sink^{any.rd}.
```

3.9 accepts that one, but not the same thing for an element of a collection
(`repro-element/`), which both 3.9 and 3.10 reject:

```scala
def sinks(): IndexedSeq[Sink^] = IndexedSeq()
def drain(consume sink: Sink^): Unit = sink.put(0)

def write(): Unit =
  val all = sinks()
  val second = scala.caps.unsafe.unsafeAssumeSeparate(all(1))
  drain(second)
```

```
Found:    (second : Sink^{all*.rd})
Required: Sink^{any}
```

Soundness hit the first form where a stream is built through a duct that
shares an ambient tactic with the consumed stream, which separation checking
cannot see is not an aliased writer (`enigmatic.BlockCipher.decryptStream`,
`ypsiloid`'s cursor over a pull endpoint):

```scala
scala.caps.unsafe.unsafeAssumeSeparate:
  stream.viaDuct(DecipherDuct(start, ivSize, tactic))
```

and the second in turbulence's tests of a divergence, whose subscribers are rings
of their own though they are reached through one collection.

## The solution

`CheckCaptures.recheckApply` already rechecks two other `caps.unsafe` methods
specially. `unsafeAssumeSeparate` joins them: the call is rechecked as its
operand, against the expected type, as `unsafeDiscardUses` is:

```scala
else if meth == defn.Caps_unsafeAssumeSeparate then
  val arg :: Nil = tree.args: @unchecked
  super.recheckFinish(recheck(arg, pt), tree, pt)
```

The separation checker still recognises the call, and still lifts its checks for
the operand, exactly as before; only the result's type changes, to the operand's
own. The patch's test is `pos-custom-args/captures/assumeseparate.scala`, and the
outcome of every other test in `tests/{neg,pos}-custom-args/captures` is
unchanged.

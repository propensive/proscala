# Check a refinement against the tracked value itself, not its widened type

Lets a tracked value be used where a refinement of its type that mentions the value itself is expected — `reader` as a `(Reader { type Topic = reader.Topic })^{reader}` — which capture checking rejected though the conformance holds.

## Context

A value branded by a path-dependent type is naturally asked for as a
refinement: "a reader whose `Topic` is *this* reader's". Without capture
checking that is unremarkable. `reader.type` conforms to
`Reader { type Topic = reader.Topic }` because the comparer looks up `Topic` in
the singleton `reader.type` itself and finds `reader.Topic`.

Under capture checking the expected type is a **capturing type**: the
refinement, with a capture set on it. The comparer handles the two halves in
turn. First the captures: the capture set of `reader.type` is `{reader}`, which
the expected set must account for. Then what remains is compared with the
*parent* of the capturing type — the refinement alone, which as a type is pure.

For a singleton on the left, upstream tries two forms of "what remains":

```scala
compareCaptures(tp1, refs1, tp2)
  && (recur(tp1.widen.stripOneCapturing, parent2)
    || tp1.isInstanceOf[SingletonType] && recur(tp1, parent2))
```

Neither can succeed here.

- `tp1.widen.stripOneCapturing` is `Reader`: the widened type, with its capture
  set removed. That is the right thing to compare with a pure type, but it has
  forgotten *which* reader it is. Its `Topic` is merely abstract, and
  `Topic = reader.Topic` cannot be shown.
- `tp1` is the singleton as it stands. It still knows it is `reader`, but it is
  not a subtype of the pure class under the refinement, because its capture set
  — the one just accounted for — is not empty.

So the comparison fails, and the message blames the capture set: "capability
`any` cannot flow into capture set {reader}".

Soundness met this in RaTEL, whose rows and records are branded by their
reader's `Topic`. Each read had to be written around it: a row's methods take
`(using reader: Reader^)(using reader.Topic =:= Topic)`, an unrefined reader and
separate evidence, in place of `(using (Reader of Topic)^)`, which also loses
resolution by brand when two readers are in scope.

## Reproduction

[`repro/`](repro/) — one file, with `-experimental`:

```scala
import language.experimental.captureChecking

class Terrain
abstract class Reader(val view: Terrain^) { type Topic }

def same(reader: Reader^): (Reader { type Topic = reader.Topic })^{reader} = reader
```

```
-- [E007] Type Mismatch Error: repro.scala:8:77
  |        Found:    (reader : app.Reader^{any})
  |        Required: app.Reader{type Topic = reader.Topic}^{reader}
  |        Note that capability `any` cannot flow into capture set {reader}.
```

The same rejects `reader` as an argument where the parameter is such a
refinement with a fresh capture set, `(Reader { type Topic = reader.Topic })^`.

## Solution

Where the parent is a refined type, the comparer (`core/TypeComparer.scala`) now
also compares a singleton in two parts, each against the form of it that can
answer:

```scala
def refinedOK(tp1: SingletonType, parent2: Type): Boolean = parent2 match
  case parent2: RefinedType if !defn.isRefinedFunction(parent2) =>
    refinedOK(tp1, parent2.parent)
    && hasMatchingMember(parent2.refinedName, tp1, parent2)
  case _ =>
    recur(tp1.widen.stripOneCapturing, parent2)
```

What lies *beneath* the refinements is compared with the widened, stripped
type, as before. Each *refinement* is compared with the member of the singleton
itself, by `hasMatchingMember`, the same test the comparer applies to a refined
type when no captures are involved.

It is a third alternative, tried after upstream's two, and only once
`compareCaptures` has accepted the capture sets, so nothing that was rejected
for its captures is accepted now: `reader` is still not a pure
`Reader { type Topic = reader.Topic }`, nor one capturing only some other value.
A refinement's own captures are checked by `hasMatchingMember` as they always
were, so a member declared `val terrain: Terrain` is not met by a tracked one. A
refined *function* type is left to upstream's handling.

On the 3.9 line the stripped type is spelt `stripCapturing`; the patch has a
version for it.

## Upstream

Upstream 3.10.0 rejects the reproduction with the same message. The patch is
always on, since it only makes rejected programs accepted. Worth reporting
upstream with the reproduction.

`tests/pos-custom-args/captures/refined-singleton.scala` covers a type member, a
term member with a capture set and a function value;
`tests/neg-custom-args/captures/refined-singleton.scala` the three rejections
above.

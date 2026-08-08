# Keep Boolean results of nullary case-class unapplies under capture checking

Stops the capture-checking augmentation of synthesized case-class unapplies
from rewriting a Boolean result to the scrutinee singleton, so that `case C() =>`
patterns on nullary case classes typecheck again.

## Context

A case class's `unapply` is synthesized, and its result shape depends on its
arity. A case class with parameters gets an unapply returning the scrutinee
itself (the pattern then selects `_1`, `_2`, … from it); a **nullary** case
class — `case class C()` — gets an unapply returning **`Boolean`**, because an
empty pattern has nothing to extract and only needs to answer whether the
scrutinee matched.

Under capture checking, synthesized members do not go through normal type
inference; `cc/Synthetics.scala` rewrites their types directly. Upstream
e954236aaf ("Two different versions of unapply types depending on consume",
Odersky, 2026-07-19) taught `transformUnapplyCaptures` to distinguish consumed
scrutinees: an unapply `(x: C): D` is augmented to `(x: C^{any}): x.type`, and
a consume unapply `(consume x: C): D` to `(consume x: C^{any}): D^{any}`.

The non-consume arm replaces the declared result with the scrutinee singleton
`x.type` **unconditionally** — correct for the parameterful shape, where the
result really is the scrutinee, but wrong for the nullary one, whose result is
`Boolean`. Every `case C() =>` pattern on a nullary case class then types the
unapply call at the scrutinee singleton where the pattern matcher requires
`Boolean`, and compilation fails with a type mismatch. The 3.9 stream is
unaffected: its version of the augmentation wraps the declared result in a
capturing type rather than replacing it, so the `Boolean` survives.

## Reproduction

Six lines ([repro/repro.scala](repro/repro.scala)), no compiler flags — the
language import is the entire configuration, and no macro or inline machinery
is involved:

```scala
import language.experimental.captureChecking

case class C()

def check(x: C): Boolean = x match
  case C() => true
```

An unpatched compiler rejects the pattern:

```
-- [E007] Type Mismatch Error: repro.scala:6:7 ---------------------------------
6 |  case C() => true
  |       ^
  |       Found:    (x5 : (x : C))
  |       Required: Boolean
```

— the unapply's result has become the scrutinee singleton. Giving `C` a
parameter makes the unpatched compiler accept the file: the nullary case class
is the discriminating trigger. With the patch, the file compiles as written.

## Solution

One guard in `transformUnapplyCaptures`
(`compiler/src/dotty/tools/dotc/cc/Synthetics.scala`), in the non-consume arm
of the result rewrite:

```scala
if paramInfo.hasAnnotation(defn.ConsumeAnnot)
then CapturingType(tp, CaptureSet.universal)
// A nullary case class's synthesized unapply returns Boolean, not the
// scrutinee; substituting `x.type` retypes `case C() =>` patterns to the
// scrutinee singleton where Boolean is required.
else if tp.widenDealias.isRef(defn.BooleanClass) then tp
else trackedParam
```

A Boolean result is left exactly as declared. The widening is load-bearing: a
nullary case class's unapply is desugared with the *constant* result type
`(true : Boolean)` (`unapplyResTp = Literal(Constant(true))` in
`ast/Desugar.scala`), and `Type.isRef` matches only class references, never
singletons — a bare `tp.isRef(defn.BooleanClass)` guard compiles but never
fires. Leaving the result alone is also capture-correct: `Boolean` is pure, so
there is no capture information to add, and the singleton substitution existed
only to give the parameterful shape a precise scrutinee type — a purpose a
Boolean-returning unapply never had.

## Relevance to Soundness

Nullary case classes are common in Soundness wherever a parameterless variant
must still be a class — usually because it is generic or carries context.
Mandible's `Opcode` hierarchy is the largest example: `Wide()` is a case class,
and `mandible.Bytecode`'s stack-effect interpreter matches it in an
alternation:

```scala
case Wide() | Breakpoint | Impdep1 | Impdep2 => stack
```

Every such pattern failed on the 3.10 stream. Anthology hit the same bug one
level removed: its `case CompilerError() =>` handlers (in the javac, kotlinc
and scalac edges) sit inside contingency's `mitigate` macro, so the failure
surfaced from the re-spliced match as `Found: C^{x} Required: Boolean` — the
form in which the bug was first observed, though as the reproduction shows, a
plain `match` is enough to trigger it.

Worth reporting upstream, with the reproduction: upstream's own
`tests/pos-custom-args/captures/patmat.scala` gained patterns in e954236aaf,
but none of them covers a nullary case class.

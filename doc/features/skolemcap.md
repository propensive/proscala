# Widen skolems in retains sets to the top capability

Stops the capture checker from rejecting `@retains` annotations that contain a
`SkolemType`, by widening the skolem to `caps.any` — the standard sound
over-approximation for a capability that cannot be named.

## Context

A dependent result type can retain one of its parameters:

```scala
given text: (tactic: Tactic[JsonError]) => (Text is Decodable in Json)^{tactic, caps.any}
```

When such a given is applied — for instance during `summonInline` resolution inside an
inline method — and the argument for the retained parameter is not a stable path, the
substitution places a *skolem* (`?n : T`) in the result's capture set: the skolem stands
for "the particular, unnameable value of that argument". The inliner then binds the
resolved evidence to a proxy val (`contextual$n`) whose declared type carries the
skolem-bearing `@retains` annotation.

`RetainingAnnotation.sanitize` already anticipates these skolems: it maps them to
`SkolemType(Any)` to prevent a compile-time blowup from their infos (see i24556), with
the stated assumption that a skolem in a retains set is illegal anyway and will be
reported.

## The problem

That assumption only holds for *inferred* types, where `Setup` discards the annotation
and re-infers the capture set (which is why the i24556 tests pass). The inline proxy's
type is *explicit*, so `Setup` interprets the annotation as written: `toCapability`
reached its fallthrough and threw `IllegalCaptureRef`, reported as:

```
Illegal capture reference: (?1 : Any)
```

The user can neither cause nor avoid this in source — skolems cannot be written — and
whether the substitution produces a skolem at all depends on symbol-completion order:
the same file compiled under zinc (sbt/mill) and under batch `dotc` gave *opposite*
verdicts, and the verdicts flipped between toolchain builds. In the Soundness tree this
broke `ethereal.test`/`profanity.test`/`exoskeleton.test` (evidence chains reaching
capability-typed `Decodable` givens through `summonInline` under staging quotes),
blocking the attested build.

## The solution

In `toCapability`, map a `SkolemType` to `GlobalAny` (`caps.any`). Widening an
unnameable capability to the top capability is the standard sound approximation in
capture checking: consumers must assume the value may capture anything, so the
approximation can only make checking more conservative, never less. The skolem's
underlying captures cannot be recovered at this point anyway — `sanitize` has already
erased its info to `Any`.

In the motivating cases the retained set is `{?n, caps.any}` (capability-typed
evidence in the Soundness codebase always includes `caps.any` alongside the tactic),
so the widening does not even change the set's meaning.

No self-contained reproduction is known: the skolem only arises in a sufficiently deep
inline/summonInline chain (small models with nested `provide`-style inlining and
dependent capability results compile cleanly), so the regression test for this patch is
the Soundness build itself (`ethereal.test` et al.).

## Code

`compiler/src/dotty/tools/dotc/cc/CaptureOps.scala` — one new case in `toCapability`:

```scala
case _: SkolemType =>
  GlobalAny
case _ =>
  throw IllegalCaptureRef(tp)
```

## Relevance to Soundness

Soundness's honest codec capabilities type tactic-requiring `Decodable`/`Encodable`
instances as capabilities (`^{tactic, caps.any}`). Any test or downstream module that
reaches such evidence through `summonInline` with an unstable tactic argument — the
`superlunary`/`exoskeleton` staging rigs are the first — failed to compile depending on
compilation order, which made `make attest` (zinc) fail while spot checks (batch)
passed, and vice versa.

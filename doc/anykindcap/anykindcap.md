# Do not constrain type arguments by an `AnyKind` bound's capture set

Stops capture checking from requiring a type argument to be pure when the type parameter's only bound is `AnyKind` — which is what `quoted.Type` and `TypeRepr.of` use, so without it no capture-checked macro can mention a function type reflectively.

## Context

Capture checking propagates a type parameter's *bound* capture set onto the
*argument*. That is what makes this rejection right:

```scala
def mkAbs[A <: Any^{}](consume x: A^, consume y: A^): Abs[A]^ = Abs[A](x, y)

mkAbs[Ref^{r6}](r6, r7)   // error: Reference `r6` is not included in
                          // the allowed capture set {} of the type
                          // parameter bound Any^{}
```

The bound `Any^{}` genuinely says "no captures", so an argument that captures
`r6` does not conform.

Some bounds, though, say nothing about captures at all, and the check exempts
them — `Any`, and `Singleton`. `AnyKind` belongs in that list and was left out.
Its capture set is empty for exactly the reason `Any`'s is: it is the top of the
kind lattice, not a claim about capabilities. Left in the check, an empty
capture set reads as "must be pure", and every capturing type argument fails:

```scala
def anyKindBound[T <: AnyKind]: Unit = ()
def anyBound[T]: Unit = ()

anyKindBound[Int => Int]   // error, before this patch
anyBound[Int => Int]       // always fine
```

The asymmetry is the whole bug. An impure function type captures the root
capability, so it is rejected under the `AnyKind` bound and accepted under `Any`.

This matters because `quoted.Type` and `quotes.reflect.TypeRepr.of` are declared
`[T <: AnyKind]` — they have to be, since they range over types of any kind. So
any capture-checked macro that mentions a function type reflectively fails.
Soundness's `mercator` hits it four times, building a `MethodType` for `map`:

```scala
val methodType = MethodType(List("v", "l"))(
  _ => List(TypeRepr.of[functor[value]], TypeRepr.of[value => value2]),
  _ => TypeRepr.of[functor[value2]])
```

## Reproduction

[`repro/repro.scala`](repro/repro.scala) — compile with
`-language:experimental.captureChecking`. Unpatched, the `anyKindBound` call and
the `TypeRepr.of[Int => Int]` both fail with

```
-- [E223] CaptureChecking Error:
   Reference `any` is not included in the allowed capture set {}
   of the type parameter bound scala.AnyKind.
```

while the `anyBound` call beside them compiles. With the patch the file compiles.

## Solution

One line in `recheckTypeArg` (`cc/CheckCaptures.scala`), adding `AnyKind` to the
bounds that carry no capture information:

```scala
val canCheck =
  !hiBound.isExactlyAny && !hiBound.isRef(defn.AnyKindClass)
  && !hiBound.isRef(defn.SingletonClass)
  && !boundRefs.elems.exists:
    case ref: TypeParamRef => ref.binder == binder   // F-bounded
    case ref => ref.isTerminalCapability             // GlobalCaps cannot constrain arguments
```

The check is otherwise untouched, so a bound that really does constrain still
does: `tests/neg-custom-args/captures/capset-bounds.scala` — added by the commit
that introduced this check — still reports both of its expected errors, with the
same messages, under the patch. No capture-checking test in the tree mentions
`AnyKind`, so nothing else can change behaviour: the patch only alters
`canCheck` when the bound *is* `AnyKind`.

## Upstream

Introduced by 196eada95d, *"Propagate capsets of type parameter bounds into
argument capsets"* (Odersky, 2026-07-14), which landed with the note *"One
failing test, to be checked"* — the area was still settling. The 3.10 stream
tracks `main` and so carries it; 3.9 predates the check and is unaffected, which
is why this patch exists only for 3.10.

Worth reporting upstream: the fix is small and the breakage is broad, since it
silently rules out `TypeRepr.of` on any function type under capture checking.

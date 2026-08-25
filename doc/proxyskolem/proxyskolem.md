# No skolem-typed inline argument proxies under capture checking

Restores the pre-3.9.0-RC5 widened type for the proxy `val` an inline call
binds an unstable argument to, in capture-checked units, where the
skolem-typed proxy introduced by upstream #26563 leaks unavoidable skolems and
local capture sets into expansion types.

## Context

When a call to an inline method passes an *unstable* argument (an expression
rather than a stable path), the inliner binds it to a local proxy `val`
(`x$proxy1`) and substitutes the proxy through the expansion. If the method's
result type depends on the parameter, the typer has already minted a
`SkolemType` (`?1 : T`) to stand for the argument's particular value.

Historically the proxy was typed with the argument type **widened**. Upstream
#26563 (first released in 3.9.0-RC5, fixing #26153/#26031) changed this: the
proxy is now typed with the *same skolem* the call's result type mentions, and
the expansion is cast to the skolem-mentioning type, so dependent inline
results stay precise.

Under capture checking that precision is doubly wrong:

- **Captures.** The skolem-typed binding bakes the local proxy's capture set
  into the expansion's type, where it can never be *avoided* into the
  method's declared (pure) result. Typeclass derivation that summons its
  result via `summonFrom`/`asMatchable` matches now fails with
  "capability `typeclass` cannot flow into capture set {}" — the derived
  instance's declared type has an empty capture set, but the expansion's type
  mentions the skolem-typed local.
- **Identity.** A skolem is equal only to itself. When a `transparent inline`
  macro *resplices* an argument that was already inlined — retyping the same
  call a second time — the retype mints a *fresh* skolem, and the two never
  unify: "Found: (?1 : X) Required: (?2 : X)".

## Reproductions

Two, one per failure mode.

**Resplice** (`repro/`, two-run compile, no flags). A macro library whose
transparent inline `id` macro re-quotes its (already-inlined) argument, where
`get` is a dependent inline extension method:

```scala
extension (value: String)(using tc: TC)
  transparent inline def get: Option[tc.Result] = Some(tc.result)

object MiniMacro:
  def id(expr: Expr[Any])(using Quotes): Expr[Any] =
    expr match
      case '{$v: t} => '{$v: t}

transparent inline def id(inline any: Any): Any = ${MiniMacro.id('any)}
```

Using it — `def check(s: String): Any = id(s.get)` — fails on an unpatched
RC5-line compiler with the never-unifiable skolem pair:

```
Found:    (?1 : ...)
Required: (?2 : ...)
```

**Capture flow** (`repro2/`, single file, `-Ycc-new
-language:experimental.captureChecking`). A Wisteria-shaped deriver whose
`derivedOne` matches a summoned, capability-typed instance back to a pure
declared result:

```scala
inline def derivedOne[T]: Decodable { type Self = T } =
  conjunction[T & Product].asMatchable match
    case typeclass: (Decodable { type Self = T }) => typeclass
```

fails with:

```
capability `typeclass` cannot flow into capture set {}
```

With the patch, both compile.

## The solution

Keep the skolem out of the *proxy's* type in cc-enabled units, exactly as
every cc unit behaved before RC5. In
`compiler/src/dotty/tools/dotc/inlines/Inliner.scala`:

```scala
// If the call result type used a skolem for this argument, use the same skolem
// as the proxy type. `?1` has `argtpe.widen` as its underlying type.
// Under capture checking, keep the pre-RC5 widened proxy type: cc has its own
// healing of inline-proxy captures, and a skolem-typed proxy bakes the local
// binding's capture (and skolem identity) into the expansion type, where it can
// neither be avoided into a pure declared result nor unified across a macro
// resplice retype (upstream #26563 casualties).
val proxySkolem = if argIsBottom || config.Feature.ccEnabled then None else skolem
```

The #26153/#26031 fix stays active everywhere else — upstream's own
regression tests for it still pass — and causation was established by
reverse-applying the upstream commit alone against the failing builds.

## Superseded on 3.10 by upstream #26872

Upstream #26872 (`f896113fd2`, on `main` as of 2026-08-24, not backported to
`release-3.9.0`) removes the skolem-typed proxy mechanism entirely: the proxy
`val` is again typed with the argument type widened — for every unit, not just
cc ones — and the call's skolem is instead recovered during type avoidance via
an attachment on the proxy binding (`TypeAssigner.InlineProxySkolem`), so the
same skolem never appears at two tree sites. That fixes both failure modes at
source (#26810 is the resplice mode), so the 3.10 stream dropped this patch on
2026-08-25. The 3.9 stream still carries it, since `release-3.9.0` retains the
#26563 proxy typing.

## Relevance to Soundness

This regression was the widest of the RC5 breakages: `exoskeleton.Argument`
(dependent inline `suggest`/`select` calls), embarcadero, `caduceus.resend`
and every Wisteria `derivedOne` derivation across the tree failed in one of
the two modes above. Since Soundness compiles everything with capture
checking, restricting the fix to cc units restores all of them without
disturbing upstream's dependent-inline improvements for ordinary code.

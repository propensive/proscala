# Memoized local roots across inline expansions (upstream, no patch)

An upstream 3.10 behaviour — not patched in this fork — where the second
expansion of the same inline definition in a compilation unit fails capture
checking against root capabilities memoized by the first expansion.

## Context

Upstream #26547 ("Better handling of nested capture sets", commit `2782a51f13`
"Refine any adoption in closure parameter types", first in the 2026-07-17
nightlies) changed how local root capabilities (`LocalCap`) are created and
adopted. The instances are memoized and owned by the context of their first
creation; whether a later occurrence may adopt one is decided by *ownership
containment*. Types produced by inline expansion share these memoized roots,
so when the same inline definition is expanded a second time in one unit — a
second typeclass derivation, a second `raises`-sugared call, a second closure
against the same expected type — the new expansion's fresh root and the first
expansion's memoized root fail the visibility check:

    Note that capability `any²` cannot flow into capture set {any}
    because any² is not visible from any in an enclosing function.

Whether a definition typechecks therefore depends on how many times an
unrelated inline was expanded earlier in the same file. The first expansion
always succeeds; only the second and later ones fail.

## Reproduction

Two minimal shapes, both failing on the 3.10 stream and compiling on 3.9
(`repro/` and `repro2/`). The first models a wisteria-style derivation whose
`Join` class takes a pure function; the second, two levels of context-function
results (`raises` sugar):

```scala
private inline def expect(count: Int): Tactic^ ?=> Unit = ()
private inline def inner(): Tactic^ ?=> Int = { expect(2); 42 }
private inline def outer(length: Long): Tactic^ ?=> Int = { expect(length.toInt); length.toInt }
def test()(using Tactic^): Int = outer(inner())   // second expansion of `expect` fails
```

## Why there is no patch

Every Soundness site was fixable honestly at source, and each fix states
something true that inference previously left implicit. The recurring
patterns, in the order they were established:

- **Ascribe the closure parameter** in the shared inline or macro
  implementation, so its type is not inferred from an expected type carrying a
  memoized root: polaris (`(sextant: Sextant) =>`), locomotion
  (`(printer: ProtobufPrinter^) =>`), enigmatic (an explicit type argument).
- **Bind an inline result to a typed `val`** before chaining another inline
  onto it: facsimile's `safely(...)` / `.or` chains.
- **Replace `raises`/`logs` sugar with explicit `using` clauses** on inline
  helpers, avoiding the synthesized per-expansion closure: breviloquence's
  CBOR parser, ethereal's installer, mandible's host contracts.
- **Construct the tactic explicitly** where a macro generates the block:
  obligatory's RPC client passes a `ThrowTactic()` instead of wrapping in
  `unsafely`.

A compiler-side relaxation was sketched during the campaign (globalize
sibling-owned roots in `localCapToGlobal`, or key the memoization on the
enclosing anonymous function) but never needed. If future upstream work does
not resolve this, that sketch is the starting point for a patch; the shape of
the fix in each Soundness module is recorded in the commit messages on the
relevant `proscala-compat` commits.

This page exists so the mechanism is recognisable when it next appears: the
diagnostic's signature is a `Found:`/`Required:` pair differing only in
`any`-numbering, with "not visible from" in the explanation, at the second
occurrence of something inline in the file.

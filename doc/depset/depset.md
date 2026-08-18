# Add a mutable IdentitySet to optimize variable dependencies in CC

Backports upstream #26720 to the 3.9 stream, replacing the copy-on-add
dependent-set representation of capture-set variables with a growable,
insertion-ordered identity set, which turns a quadratic allocation pattern in
capture checking into a linear one.

## Context

During capture checking, every capture-set variable keeps `deps`, the set of
derived sets that depend on it, so that elements added to the variable later
can be propagated forward. `deps` was a `SimpleIdentitySet` — an immutable
array-backed set whose `+` copies the whole backing array on every addition.

A variable's dependent set ordinarily stays small, so the copying is harmless.
But `CheckCaptures.markFree` filters a definition's *use set* through the
visibility predicate of each environment on the environment stack, and every
one of those filters constructs a fresh `Filtered` derived set and registers
it as a new dependent of the use set. A method that is referenced N times
therefore leaves its use-set variable with O(N) dependents, at a cumulative
array-copying cost of O(N²) bytes.

Inline-heavy generic derivation produces exactly this shape. Soundness's
Exegesis module (an LSP implementation, 12 source files) expands several
hundred Wisteria derivation graphs whose generated code references the same
small set of methods tens of thousands of times. Profiling the compile with
JFR attributed **178 GB of 194 GB of total allocation** to a single site —
`CaptureSet.Var.includeDep` growing `deps` arrays — making the cc phase 78%
of an approximately twelve-minute compile. Upstream met the same pattern
independently: compiling the standard library under capture checking grows
dependency sets to ~9,000 elements (#26720's commit message), and fixed it on
the way to 3.10. The 3.9 release branch predates the fix.

## Reproduction

This is a performance defect, not a miscompilation, so there is no `repro/`
directory. It is observable on any derivation-heavy, capture-checked module;
the measured case is Soundness's `exegesis.core` compiled with
`-language:experimental.captureChecking` and separation checking. Under
`-Yprofile-enabled`, the unpatched compiler reports a cc phase of ~60 s user
time and ~190 GB allocated; JFR (`jdk.ObjectAllocationSample`) shows the
`includeDep` stacks. A minimal synthetic trigger is any single method
referenced many times from capture-checked code:

```scala
import language.experimental.captureChecking
def use(io: Object^): Unit = ()
def caller(io: Object^): Unit =
  use(io); use(io); use(io) // … thousands of references, e.g. inlined
```

Each reference marks `use`'s use set free in the caller's environments,
registering a fresh filtered dependent per reference.

## Solution

The backported upstream commit (`24b203ee0e`, PR #26720) introduces
`util.MutableIdentitySet`: an open-addressing identity hash table over an
append-only element array. Additions and membership tests are amortized
O(1); iteration follows insertion order, so propagation order and diagnostics
stay deterministic (a plain identity hash set would vary between JVM runs,
because `System.identityHashCode` does); removal — used only by the
`TypeComparer` undo log, which removes recent additions — is O(1) with
occasional compaction. `CaptureSet.Var.deps` becomes a `MutableIdentitySet`,
and the handful of `deps` call sites move from functional update to mutation.
The commit applies to the 3.9 stream without conflicts and carries its own
unit test (`MutableIdentitySetTest`).

Measured on `exegesis.core` (same machine, load-resistant metrics): cc-phase
allocation falls from 190 GB to 3.2 GB and cc user time from ~60 s to ~4.5 s;
wall-clock compile time falls from roughly twelve minutes to under a minute,
and the full Soundness dependency chain of the module (5,194 build targets)
drops from ~308 s to ~94 s. An earlier fork-local variant that instead
memoized `markFree`'s filtered sets per (set, environment) recovered only a
third of the allocation — the memo keys fragment across the thousands of
synthetic lambda owners in derived code — and was discarded in favour of this
backport, which fixes the cost at the data-structure level for every caller.

The 3.10 stream needs no patch: it inherits #26720 from upstream directly.

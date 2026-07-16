# FIXME: no reproduction found yet (differentially verified absent from current Soundness)

Extensive differential testing (2026-07-17) failed to find code that needs
this patch:

- A **trunk-minus-receiver** compiler (trunk/3.9 without this patch's 9-line
  `InlineProxy` case) compiles **all of Soundness** at `211be67b5` — every
  library module and all test sources — cleanly.
- Soundness at `1d5317ef6` (#1562, the commit that moved the toolchain to
  `3.9.0-RC1-p3`, the first release containing this fix) also compiles
  cleanly on trunk-minus-receiver, including `breviloquence.test`.
- Hand-constructed shapes (inline `update` methods with stable, unstable and
  `asInstanceOf`-cast receivers; direct state and forwarders to stateful
  fields; `Mutable` and `ExclusiveCapability, Stateful` parents) all compile
  without the fix: for a *stable* receiver the exclusivity check follows the
  proxy's singleton info to the underlying reference, and for the tried
  unstable receivers the proxy's inferred fresh capture set is already
  exclusive.

The fix was verified "both directions with a minimal repro" during
development (commit ec141fb257, 2026-07-15), but that repro was not
preserved, and the CBOR direct-parsing code it accompanied (#1562/#1575) was
merged in a restructured form ("generated code binds the parser once per
record" rather than calling the per-item inline forwarders). The discriminant
per the patch: a receiver proxy whose own capability judges non-exclusive
while its declared info's capture set is exclusive. If the "cannot call
update method ... through a read-only reference"-class error reappears on an
inline forwarder call, distil it here; `trunk-minus-receiver` (trunk before
merge `647dc95d32`, i.e. `d571711bb8`) is the oracle.

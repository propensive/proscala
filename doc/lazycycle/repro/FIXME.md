# FIXME: no reproduction found yet (differentially verified absent from current Soundness)

Extensive differential testing (2026-07-17) failed to find code that needs
this patch:

- A **trunk-minus-lazycycle** compiler (trunk/3.9 with only this patch's
  13-line guard reverted) compiles **all of Soundness** at `211be67b5` —
  every library module (`./mill soundness.all`) *and* all test sources
  (`./mill test.compile`) — cleanly.
- The feature doc's cited shape (`enum Tree derives Presentation, Eq` from
  `wisteria_test.scala`, extracted with its typeclasses) plus a
  same-compilation macro forcing a suspension/re-run also compiles cleanly on
  trunk-minus-lazycycle.
- Simple F-bounded + macro-suspension toys (per the doc) do not trigger it
  either; suspension was confirmed occurring via `-Xprint-suspension`.
- Compiling the pre-p1-era Soundness (`8e10c3043`, when the patch was
  authored) was attempted but is blocked by old-toolchain wiring
  incompatibilities in that era's `build.mill`.

So the cyclic-LazyRef condition needs an ingredient beyond the documented
shape — likely a specific multi-unit suspension pattern from the July 2026 CC
rollout that has since been restructured. The guard is cheap and clearly
sound (re-entrancy protection), but a reproduction will probably have to be
caught in the wild: if a StackOverflow in `SetupTypeMap` ever reappears,
distil it here. The `trunk-minus-lazycycle` recipe (merge all 3.9 feature
branches except this one onto make) is the oracle to verify against.

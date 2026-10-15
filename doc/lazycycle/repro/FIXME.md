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

## 2026-10-15: a second, short attempt

With a new oracle to hand — stock Scala 3.10.0 against the 1.0.1 release,
run on `Macro.scala` + `Use.scala` compiled together under `-Ycc-new` so that
`Use.scala` suspends on the same-run macro and is re-run, the layout of
`doc/staleread/repro` — these shapes all compile on both, so none reaches
the cycle:

- an F-bounded `Ordered[T <: Ordered[T]]` with a derived typeclass whose
  given summons the macro, as the feature doc's example;
- the same with an F-bounded graph (`Graph[G <: Graph[G]]` with a `Node <: G`
  member), and with the recursion encoded through abstract type members
  (`Graph { type N <: Node; type E <: Edge }`) and an object instantiating
  them;
- a capability-typed recursive structure (`Tree[T <: Tree[T]]` holding
  `List[T^]`) walked by a derived typeclass;
- an opaque type bounded by its parameter's F-bound and an `Elem` member
  defined through a recursive match type.

The July conclusion stands: no shape made of ordinary source reaches a live
`LazyRef` cycle in Setup, and the trigger will have to be caught in the wild.

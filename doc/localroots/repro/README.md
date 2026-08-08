# Reproduction: localroots (derivation shape)

The first of two reproductions (see also [`repro2/`](../repro2/README.md)): a
wisteria-style inline derivation whose `Join` class takes a pure function from
an exclusive capability. The first expansion (`direct`) compiles; the second
(`direct2`) fails.

Compile on a 3.10-stream compiler with:

```
scalac -experimental repro.scala
```

Expected failure (the in-source `captureChecking` import is the only
configuration; a 3.9-stream compiler accepts the file):

```
-- [E007] Type Mismatch Error: repro.scala:27:36
27 |def direct2: Pair = unpackFrom[Pair](1)
   |                    ^^^^^^^^^^^^^^^^^^^
   |Found:    (sextant: Sextant^{any}) ->{repro$package} Int
   |Required: Sextant^{any²} -> Int
   |
   |Note that capability `any²` cannot flow into capture set {any} of parameter sextant.
```

Deleting either of `direct`/`direct2` makes the file compile: only the second
expansion of the derivation in the unit fails. Derived by reduction from
polaris's `Debufferable` derivation as exercised by phoenicia's TTF tables.

No fork patch exists for this behaviour; see the feature doc for the
source-level fix patterns.

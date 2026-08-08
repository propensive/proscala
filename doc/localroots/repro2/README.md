# Reproduction: localroots (context-function shape)

The second of two reproductions (see also [`repro/`](../repro/README.md)):
class-member inlines with context-function results (the shape `raises` sugar
expands to), where one inline's body expands another that the argument
expression also expanded.

Compile on a 3.10-stream compiler with:

```
scalac -experimental repro.scala
```

Expected failure (a 3.9-stream compiler accepts the file):

```
-- [E007] Type Mismatch Error: repro.scala:22:9
22 |    outer(inner())
   |    ^^^^^^^^^^^^^^
   |Found:    (contextual$1: Tactic^{any}) ?->'s1 Unit
   |Required: (Tactic^{any²}) ?=> Unit
   |
   |Note that capability `any²` cannot flow into capture set {any} of parameter contextual$1.
```

Trigger conditions, each verified by a passing counter-variant during
reduction: the inlines must be class members (the identical top-level program
compiles), and the same leaf inline must be expanded twice in one enclosing
method. Derived by reduction from breviloquence's CBOR parser.

No fork patch exists for this behaviour; see the feature doc for the
source-level fix patterns.

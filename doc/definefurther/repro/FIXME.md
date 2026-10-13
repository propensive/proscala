# No self-contained reproduction yet

The error needs `canDefineFurther` to instantiate a type variable whose
constraint adjustment recurses without end, during an adaptation that fails
first. In Soundness that happens while the first `read[X in Protobuf]` of a
compilation unit resolves its given. The in-tree reproductions are the test
modules of locomotion and embarcadero, on an unpatched 3.10 tree:

    mill locomotion.test.compile embarcadero.test.compile

which fail with "Recursion limit exceeded" (at `locomotion_test.scala:169` and
`embarcadero_test.scala:748`), where 3.9 compiles both. Extracting a case
without Soundness's typeclasses is still to do.

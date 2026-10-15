# Reproduction: definefurther

One file, `read.scala`, compiled with no flags:

```
scalac -d . read.scala
```

Without the patch (stock Scala 3.10.0), the compiler reports a fatal error:

```
-- Error: read.scala:28:4 ------------------------------------------------------
28 |def test = read[Chain, Sample in Protobuf](Chain())
   |^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |Recursion limit exceeded.
   |Maybe there is an illegal cyclic reference?
   ...
   |A recurring operation is (inner to outer):
   |
   |  adjust value{type Form = Protobuf}
   |  adjust value{type Form = Protobuf; type Form = Protobuf}
   |  adjust value
   ...
```

With the patch, it compiles.

The file models Soundness's `read[X in Protobuf]`: typeclass traits refined by
infix aliases (`value is Readable to result`, `value in Protobuf` is
`value { type Form = Protobuf }`), and a chain of three givens, each resolved
while searching for the previous one's context parameter:

- `chainReadable[value]` matches the searched type, so `value in Protobuf`
  is unified with `Sample in Protobuf`: `Sample { type Form = Protobuf }`
  becomes `value`'s lower bound.
- Its parameter `(value in Protobuf) is Aggregable` is found by
  `aggregableIn[value']`, unifying `value' in Protobuf` with
  `value in Protobuf`: now each variable's lower bound is the other, refined.
- Its parameter `value' is Decodable in Protobuf` has two candidates. The
  more specific one, `generic[value'']: value'' is Decodable in value''`, is
  tried first, and its result does not fit (`Form` would have to be both
  `value''` and `Protobuf`). Before giving up on it, the adapter asks
  `canDefineFurther`, which instantiates every open variable it can reach,
  each to its lower bound: `value'` becomes `value { type Form = Protobuf }`,
  and `value` becomes that, refined again. Recording the instantiation in the
  constraint (`OrderingConstraint.adjustDeps`) follows the entries of the
  variables it mentions, which now lead back to each other, without end.

Stock 3.10 bounds the recursion with fuel and reports it as the error above.
With the patch, `canDefineFurther` answers that nothing more can be defined,
the candidate fails as it should, and the next, `decodable`, is taken.

Each ingredient is needed: without `generic` (or with it declared where it is
tried after `decodable`), no candidate fails, so `canDefineFurther` is never
asked; without `aggregableIn`'s own type variable (`value is Aggregable` in
place of `(value in Protobuf) is Aggregable`), the bounds do not form a cycle;
without the refinement on `chainReadable`'s result, the first unification
instantiates `value` outright.

How it was found: by compiling locomotion's tests with stock 3.10.0 against
Soundness's jars with an unlimited JVM stack-trace depth
(`-XX:MaxJavaStackTraceDepth=0 … -Xno-enrich-error-messages`), which showed the
overflow under `canDefineFurther` → `isFullyDefined` → `TypeVar.instantiate` →
`adjustDeps` during a nested implicit search; then by copying the signatures of
every given that search touches (the `Readable`, `Aggregable` and `Decodable`
instances of turbulence, distillate and locomotion) with `???` bodies, and
removing them one at a time.

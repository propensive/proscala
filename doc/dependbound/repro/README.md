# Reproduction: dependbound

Compile the single file with:

```
scalac -Ycc-new -experimental repro.scala
```

Without the patch, on an upstream which has scala/scala3 #27551, compilation
fails at the call of the extension method, when the type arguments of the given
`Sized.coll` are checked against their bounds:

```
-- [E057] Type Mismatch Error: repro.scala:18:12 -------------------------------
18 |  boxes.size
   |            ^
   |Type argument Coll[Box{val cap: Cap^}^{cap²}] does not conform to upper bound Coll[Box{val cap: Cap^'s1}^'s2]
   |
   |where:    ^    refers to a root capability classified as SharedCapability in the type of value cap
   |          cap  is a value in class Box
   |          cap² is a parameter in method test
1 error found
```

With the patch, the file compiles.

The trigger is a type parameter bounded by a type which names an earlier type
parameter of the same clause (`[element, coll <: Coll[element]]`), where both
arguments are inferred and the argument for the later one has a capture set
inside it. With the given written `[element] => Sized[Coll[element], element]`
the file compiles unpatched.

Reduced from Soundness's `Traversable` and `Mappable` instances, given for
`[element, list <: List[element]]` (Proscala issue 62).

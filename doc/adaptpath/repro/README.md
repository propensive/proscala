# Reproduction: adaptpath

Compile the single file with:

```
scalac -experimental repro.scala
```

Without the patch, on scala/scala3 3.10.2-RC1 or later, the first case of the
match is rejected:

```
-- [E007] Type Mismatch Error: repro.scala:13:70 -------------------------------
13 |  case gathering: Gathering => keep[gathering.Self](gathering.gathered(Nil))
   |                                                    ^^^^^^^^^^^^^^^^^^^^^^^
   |                                    Found:    (Parsing & Gathering)#Self
   |                                    Required: gathering.Self
```

With the patch, the file compiles. Scala 3.10.0 and 3.10.1 compile it unpatched.

The trigger is a stable reference whose type is an intersection of two types
which each get a capture set — here a variable bound by a typed pattern, typed
with the scrutinee's type meeting the pattern's — used where a type that depends
on it is expected.

Reduced from Soundness's xylophone and stratiform, whose parsers match a field's
decoder against a `Gathering` refinement and use `gathering.Self`.

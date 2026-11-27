# Reproduction: inferredmeet

Compile the single file with:

```
scalac -experimental repro.scala
```

Without the patch, on scala/scala3 3.10.2-RC1 or later, both methods are
rejected:

```
-- [E007] Type Mismatch Error: repro.scala:13:14 -------------------------------
13 |  block(using handle)
   |              ^^^^^^
   |Found:    (handle : (Handle & Granting[Int]^){type Under = filesystem^{}})
   |Required: ((Handle{type Under = filesystem}^{any}) & Granting[Int])^{any²}
   |
   |Note that capability `any²` cannot flow into capture set {any}.
-- [E007] Type Mismatch Error: repro.scala:24:4 --------------------------------
24 |    new Worker(monitor) with Daemon:
   |    ^
   |Found:    ((Worker{val parent: Monitor^}^{monitor}) & (Daemon^{monitor})){type Result = Unit}
   |Required: Daemon
   |
   |Note that capability `monitor` cannot flow into capture set {}.
```

With the patch, the file compiles. Scala 3.10.0 and 3.10.1 compile it unpatched.

The trigger is an instance of an anonymous class with more than one parent,
whose inferred type is an intersection: passed where the same intersection is
expected with a single capture set, or to `caps.unsafe.unsafeAssumePure`.

Reduced from Soundness's galilei (`new Handle with Granting[grants]`) and
parasite (`new Worker(...) with Daemon`).

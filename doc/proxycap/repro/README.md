# Reproduction: proxycap

One file, compiled alone:

```
scalac -d . repro.scala
```

Without the patch (Scala 3.10.0, or upstream `main` since scala/scala3#26989):

```
-- [E007] Type Mismatch Error: repro.scala:12:40 -------------------------------
12 |  (0 until errors.length).fuse(initial)(lambda(summon[Int], summon[acc])(errors(summon[Int])))
   |                                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |        Found:    (contextual$1: acc, contextual$2: Int) ?->{lambda} acc
   |        Required: (contextual$1: acc, contextual$2: Int) ?-> acc
   |
   |        Note that capability `lambda` cannot flow into capture set {}.
```

With the patch the file compiles. Scala 3.10.0-RC2 and every 3.9 release compile
it too; the error first appears in 3.10.0-RC3, with the backport of #26989.

# Reproduction: tastynocc

One file, with capture checking and separation checking: an enum, and a method
which fills a local array.

```
F="-experimental -Ycc-new -language:experimental.captureChecking -language:experimental.separationChecking"
scalac $F -d a Loop.scala                                              # compiles
scalac $F -from-tasty -d b -classpath a a/app/State.tasty a/app/Sorting.tasty
scalac $F -Yskip:cc -from-tasty -d c -classpath a a/app/State.tasty
```

Without the patch the second command reports three errors on code the first
accepted:

```
-- Error: Loop.scala:3:5
3 |enum State:
  |     ^
  |object State needs to extend Capability since it has a field `$values` with `any` in its type.
-- [E007] Type Mismatch Error: Loop.scala:4:15
4 |  case Active, Stopped
  |Found:    (app.State & scala.runtime.EnumValue)^{app.State}
  |Required: app.State
-- Error: Loop.scala:12:6
12 |      boxed(index) = raw(index).asInstanceOf[AnyRef]
   |      ^^^^^
   |      Cannot call update method update of boxed
   |      since its capture set {boxed} is read-only.
```

and the third crashes:

```
unhandled exception while running MegaPhase{elimOpaque, explicitOuter, explicitSelf, interpolators, dropBreaks} on a/app/State.tasty
java.lang.ClassCastException: class dotty.tools.dotc.core.Phases$NoPhase$ cannot be cast to class dotty.tools.dotc.cc.CheckCaptures
```

Upstream 3.10.0 reports the two errors on the enum and crashes the same way; the
error on the array is the fork's stricter reading of a bare array type.

With the patch both commands compile, to the classes the source compilation gave,
and so does `scalac $F -Yskip:cc -d d Loop.scala`, from source.

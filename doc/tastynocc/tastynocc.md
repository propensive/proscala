# Do not check captures in a run which reads its units from TASTy

Lets a unit compiled with capture or separation checking be recompiled from its TASTy with the same options, where the checker rejected the unpickled trees, and stops `-Yskip:cc` from crashing the compiler.

## Context

Capture checking does not look at trees the way Typer left them. Its setup
phase first rewrites the types in them, and it treats two kinds of type
differently:

- an **inferred** type — the type of `val boxed = new Array[AnyRef](n)`, which
  the programmer did not write — is given a capture-set *variable* for each of
  its parts, for the checker to solve;
- a type that was **written** is taken to say all there is to say: a part with
  no capture set has none.

Which kind a type is, is a property of the tree: an inferred type is an
`InferredTypeTree`. TASTy does not record it. In a tree read from TASTy every
type is one that was written, so the checker holds each definition to the exact
type Typer once inferred for it, with no room to add what it would have found.

Under **separation checking** that is fatal for ordinary code. A local
`val boxed: Array[AnyRef]`, as it now reads, declares an array with an empty
capture set, which is a read-only one, so the next line's `boxed(index) = …` is
an update of a read-only array. The members the compiler synthesizes for an
`enum` are held to types they were never meant to be checked against. The unit
was accepted when it was compiled, and is rejected when it is recompiled.

258 of Soundness's 305 components are separation-checked, so hardly any
recompiled with the options it was built with.

There was no way round it from the command line:

- **Leaving the options out** changes the output. Later phases go by the same
  settings — `UncacheGivenAliases`, the pattern matcher, the inliner — so, for
  instance, a `private given` that was a lazy val becomes a `def`.
- **`-Yskip:cc`** crashed. It removes the checker, but the setup phase stays, as
  a phase and as a symbol transformer, and asks the checker's phase for its
  state.

## Reproduction

[`repro/`](repro/) — one file, with `-experimental -Ycc-new` and the two
language imports as options (`$F`):

```scala
enum State:
  case Active, Stopped

object Sorting:
  def boxed(raw: Array[Int]): Int =
    val boxed = new Array[AnyRef](raw.length)
    var index = 0
    while index < raw.length do
      boxed(index) = raw(index).asInstanceOf[AnyRef]
      index += 1
    boxed.length
```

```
scalac $F -d a Loop.scala                                                  # compiles
scalac $F -from-tasty -d b -classpath a a/app/State.tasty a/app/Sorting.tasty

-- Error: Loop.scala:12:6
   |      Cannot call update method update of boxed
   |      since its capture set {boxed} is read-only.

scalac $F -Yskip:cc -from-tasty -d c -classpath a a/app/State.tasty
java.lang.ClassCastException: class dotty.tools.dotc.core.Phases$NoPhase$ cannot be cast to class dotty.tools.dotc.cc.CheckCaptures
```

## Solution

Since the check cannot be repeated from what TASTy holds, and the unit passed it
when it was compiled, a run which reads its units from TASTy no longer makes it.
One condition (`cc/Setup.scala`) now governs the setup phase, its symbol
transformer and the checker:

```scala
def isActive(using Context): Boolean =
  Feature.ccEnabledSomewhere
  && !ctx.settings.fromTasty.value
  && Phases.checkCapturesPhase.exists
```

The second line is the run from TASTy. The third is the run without the
checker's phase, which makes `-Yskip:cc` work, from source too: the setup phase
stands down with it.

The *options* are untouched, so the phases that go by them emit the same code:
the reproduction recompiles to the classes the source compilation gave.

This is not a gate with an off state worth keeping: the check it removes could
only give wrong answers. Capture checking from source is unchanged.

## Upstream

Upstream 3.10.0 reports the two errors on the enum and crashes under
`-Yskip:cc` in the same way; the error on the array is the fork's stricter
reading of a bare array type under separation checking. The patch is always on,
since it only makes rejected input accepted. Worth reporting upstream with the
reproduction.

`tests/pos-custom-args/captures/from-tasty-separation.scala` holds the
reproduction; as an ordinary test it only shows that the file compiles.

# Compile a unit read from TASTy with the language settings it was compiled with

Makes a unit compiled with capture checking or pure functions, enabled by an option, recompile from its TASTy to the code it was compiled to, whether or not the option is given again.

## Context

Capture checking and pure functions are language features, and a unit can have
them in one of two ways: by an import in the file,

```scala
import language.experimental.captureChecking
```

or by a command-line option, `-language:experimental.captureChecking`, which
enables them for every file of a compilation. Soundness uses the option: 258 of
its 305 components are compiled with it, and 47 without.

The setting matters after the checker too. Several later phases ask whether
capture checking is on — `UncacheGivenAliases`, the pattern matcher, the
inliner — and generate different code when it is. For instance, the fork keeps a
given alias as a cached lazy val when capture checking is on anywhere in the run
(the `givencache` patch), where otherwise it becomes a plain method.

When a unit is recompiled from its TASTy, an import is still in its trees and is
found again. An option is not: the run that reads the TASTy goes by its own
options. Since `tastynocc`, such a run *can* be given the capture-checking
options, and then generates what the source compilation did. But a tool which
recompiles from TASTy does not always know the options a unit was compiled with,
and one which reads a whole classpath in one run cannot give one set of them
that suits units compiled with the option and units compiled without it.

Yet the TASTy says. Every unit's TASTy carries **attributes**, written from the
settings in force when it was pickled, and two of them are `captureChecked` and
`withPureFuns`. Nothing read them back.

## Reproduction

[`repro/`](repro/):

```scala
package app

class Box(val label: String):
  given alias: String = label
```

```
scalac -experimental -language:experimental.captureChecking -d a Box.scala
scalac -experimental -from-tasty -d b -classpath a a/app/Box.tasty
javap -p -cp a app.Box
javap -p -cp b app.Box
```

From source, `Box` has `alias$lzy1`, its `VarHandle` and `alias$lzyINIT1`:
the alias is cached. Recompiled from TASTy without the option it had none of
them: `alias()` was a plain method. With the option given again, it had them.

## Solution

`ReadTasty`, which makes a compilation unit of each class read from TASTy, now
restores the two settings on the unit from its attributes
(`fromtasty/ReadTasty.scala`):

```scala
if attributes.captureChecked then
  unit.needsCaptureChecking = true
  ctx.run.nn.ccEnabledSomewhere = true
if attributes.withPureFuns then unit.knowsPureFuns = true
```

These are the same flags that an import of the feature sets, so every phase which
asks `Feature.ccEnabled` or `Feature.pureFunsEnabled` for the unit gets the
answer it got from source, as does the pickler, which writes the attributes of
the TASTy it makes anew.

One question is asked of the run rather than of the unit. `givencache` keeps
aliases cached when capture checking is on *anywhere*, since a checked unit can
name a given alias of another unit in its capture sets. A run from TASTy checks
no captures (`tastynocc`), so there the reason does not arise, and the only aim
is to give each unit the code it had. `UncacheGivenAliases` therefore goes by
the unit itself in a run from TASTy:

```scala
&& !(if ctx.settings.fromTasty.value then Feature.ccEnabled else Feature.ccEnabledSomewhere)
```

so a unit compiled without capture checking keeps its plain method even when it
is recompiled in the same run as one compiled with it. That is exact for a
classpath of components each compiled wholly with or without the option, as
Soundness's are. A unit compiled *without* capture checking in the same source
run as one *with* it cannot be told apart from its TASTy, and gets the plain
method.

The patch is always on: it makes a recompilation give the code of the original
compilation, which is the only thing a recompilation is for.

## Upstream

The difference shown in the reproduction comes from `givencache`, so stock
Scala does not show it with this file. But upstream's pattern matcher, inliner,
`HoistSuperArgs` and `FirstTransform` also go by `Feature.ccEnabled`, and
upstream does not restore it from the attributes either.

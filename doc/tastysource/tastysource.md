# Compile a unit read from TASTy in the source its trees were written in

Makes a class recompiled from TASTy name its original source file and keep its line numbers, where its `SourceFile` attribute named the `.tasty` file and inlined code was placed on line 1.

## Context

A compilation unit has a **source**: the file it was read from. For a unit read
from TASTy that is the `.tasty` file. Its *trees*, though, are not positioned in
that file. TASTy records the path of the source each tree was written in, and
the length of every line of it, and the unpickler gives each tree that source —
which is how an error in a unit read from TASTy can still be reported at
`Trace.scala:4`, with no `Trace.scala` to hand.

So a unit read from TASTy has two sources, the unit's and its trees', and code
that asks for "the source of this unit" gets the first where it nearly always
means the second. Three places did:

- **The backend** writes the unit's source as the `SourceFile` attribute of
  every class, so a stack trace through a recompiled class reads `Trace.tasty`.
- **The inliner**, when it drops an `Inlined` node, has to decide where the
  inlined code now is. A class file names one source, so code inlined from
  *another* file is moved to the position of the call, and code from the unit's
  own file keeps its position. It decides by comparing each tree's source with
  the unit's. In a unit read from TASTy *no* tree is in the unit's source, so
  all inlined code was moved — and moved into the TASTy file, where the call's
  offset falls on line 1.
- **Every phase** makes its new trees in the source of its context, which is set
  from the unit. Code synthesized while a unit read from TASTy is compiled was
  placed in the TASTy file, and got no line at all.

The effect is on what users see, not on what the code does: stack traces, and a
debugger's view. For a tool that ships classes regenerated from TASTy — coverage
instrumentation, a shrinker — it is also most of the difference between a class
and its recompilation: in Soundness's `vacuous`, all 26 classes differed from
their source-compiled originals, almost entirely in this attribute and the line
tables.

## Reproduction

[`repro/`](repro/) — one file, no flags:

```scala
object Trace:
  inline def fail(): Nothing = throw new RuntimeException("here")

  def main(args: Array[String]): Unit =
    try fail()
    catch case error: RuntimeException => println(error.getStackTrace.nn.head)
```

```
scalac -d a Trace.scala
scalac -from-tasty -d b -classpath a a/app/Trace.tasty
scala -classpath a app.Trace     # app.Trace$.main(Trace.scala:4)
scala -classpath b app.Trace     # app.Trace$.main(Trace.tasty:1)  without the patch
```

## Solution

A unit gains a second accessor (`CompilationUnit.scala`):

```scala
/** The source file the trees of this unit were written in. */
def treeSource: SourceFile =
  if source.file != null && source.file.ext.isTasty && tpdTree.source.exists
  then tpdTree.source
  else source
```

For a unit compiled from source it is `source`. The three places above use it:
the backend names `treeSource` in the `SourceFile` attribute (and in the
`-Zinline-source-maps` debug extension); `Inlines.reposition` compares against
it and moves code to it; and `FreshContext.setCompilationUnit` gives the context
`treeSource` as its source.

The unit's own `source` is deliberately left as the TASTy file. It is what
`Run.files` is made of, and so what decides whether a symbol is defined in the
current run; changing it would change which units a `-from-tasty` run considers
its own.

With the patch the reproduction prints `Trace.scala:4` from both class files,
and `javap -c -l` gives the same output for them, line tables included.

One difference is known to remain: where code is inlined into a class from an
inline trait declared in another file, the lines of the recompiled class are
those of the call, while the source compilation mixes in line numbers of the
other file. Neither is exact.

## Upstream

Upstream 3.10.0 prints `Trace.tasty:1` too. The patch is always on; it changes
only the debug information of a class compiled from TASTy. Worth reporting
upstream with the reproduction.

# Do not suspend a unit read from TASTy for a macro with bytecode beside it

Compiles a set of TASTy files which includes both a macro and its callers in one run, where the callers were suspended and then failed with "Conflicting definitions".

## Context

A macro is run by the compiler, from its bytecode. When a macro and a call to
it are compiled together from source, that bytecode does not exist yet, so the
compiler **suspends** the calling unit: it finishes the others, then starts a
second run for the suspended ones, by which time the macro's class has been
written.

Whether a macro is "being compiled now" is decided by asking whether its symbol
is *defined in the current run*:

```scala
final def isDefinedInCurrentRun(using Context): Boolean =
  span.exists && defRunId == ctx.runId && associatedFileMatches(ctx.run.nn.files.contains)
```

and the files of a run are those of its units. Under `-from-tasty` the units are
the TASTy files given on the command line, so a macro among them counts, and its
callers are suspended — although, unlike a source file, a TASTy file comes with
its bytecode: `Macro.class` lies beside `Macro.tasty`, and the macro runs from
it.

The suspension is not merely wasted. A unit compiled from source is suspended
during Typer or inlining and *re-parsed* in the second run, from nothing. A
unit read from TASTy is not read again: the second run starts from the tree the
first run had already taken through PostTyper, and puts it through PostTyper
once more, which adds the synthetic members of its case classes and enums a
second time. If any other unit of the first run has referred to those members,
so that their symbols are complete, the two sets collide.

Recompiling a component, or a whole classpath, from TASTy always has macros
among its inputs. Soundness's `aviation` failed this way, with six errors in the
two units that use the `tz""` interpolator defined beside them; and a phase
that needs to see every unit of a run at once sees an incomplete set in the
first.

## Reproduction

[`repro/`](repro/) — three files, no flags:

```scala
object Macro:
  inline def twice(inline value: Int): Int = ${ impl('value) }

object Use:
  enum Issue:
    case Expect(char: Char)
    case Missing
  def four: Int = Macro.twice(2)

object Other:
  def issue: Use.Issue = Use.Issue.Expect('x')
```

```
scalac -d a Macro.scala Use.scala Other.scala
scalac -from-tasty -Xprint-suspension -d b -classpath a a/app/Macro.tasty a/app/Use.tasty a/app/Other.tasty

-- [E120] Naming Error: Use.scala:5:9
  |Conflicting definitions:
  |def fromProduct(p: Product): Object in object Expect and
  |def fromProduct(p: Product): Object in object Expect
compiling suspended a/app/Use.tasty
```

## Solution

The inliner collects the symbols a macro call depends on which still await their
bytecode (`macroDependencies`, in `inlines/Inliner.scala`), and suspends if there
are any. A symbol read from a TASTy file with a class file beside it is no longer
one of them:

```scala
private def awaitsBytecode(sym: Symbol)(using Context): Boolean =
  sym.isDefinedInCurrentRun && !(ctx.settings.fromTasty.value && hasClassFile(sym))

private def hasClassFile(sym: Symbol)(using Context): Boolean =
  val file = sym.associatedFile
  file != null && file.ext.isTasty
  && file.resolveSiblingWithExtension(dotty.tools.io.FileExtension.Class) != null
```

The test is narrow on purpose. `isDefinedInCurrentRun` itself is unchanged, and
with it everything else that asks the question. A TASTy file *without* a class
file beside it — one copied out on its own — is treated as before: its callers
are suspended, since there is nothing to run the macro from until the first run
has written it.

With the patch the reproduction compiles in one run with no suspension, to the
classes the source compilation gave.

## Upstream

Upstream 3.10.0 gives the same two errors. The patch is always on: it only makes
a rejected input accepted. Worth reporting upstream with the reproduction.

`tests/pos-macros/from-tasty-macro-in-inputs` holds the three files; as an
ordinary test it only shows that they compile.

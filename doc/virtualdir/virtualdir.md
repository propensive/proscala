# Backport the `io.virtualDirectory` factory from the 3.10 stream

Backports the package-level factory `dotty.tools.io.virtualDirectory(name)` —
introduced upstream on the 3.10 line as the sanctioned way to obtain an
in-memory directory — so tools that drive the compiler can use one API on both
streams.

## Context

`dotty.tools.io.AbstractFile` is the compiler's file abstraction: source
files, classfiles, jar entries and purely in-memory files all appear behind
it. One subclass, `VirtualDirectory`, is a directory that exists only in
memory — the standard way to compile code without touching the filesystem.
A tool embedding the compiler sets it as the output directory
(`-d`, or `Settings.outputDir`), runs a compilation, and reads the generated
classfiles back out of memory.

Upstream's "Improve IO package encapsulation" (`da99eb87b0`, PR
[#26398](https://github.com/scala/scala3/pull/26398), on `main` and therefore
in our 3.10 stream) tightened this hierarchy: `AbstractFile` subclasses are no
longer meant to be constructed or special-cased directly. As part of that
change the `VirtualDirectory` constructor became `private[io]`, and a
package-level factory took its place as the one public way to obtain an
in-memory directory:

```scala
package object io {
  ...
  def virtualDirectory(name: String): AbstractFile =
    new VirtualDirectory(name)
}
```

The 3.9 stream tracks `release-3.9.0`, which predates the refactoring: there
the constructor is still public and no factory exists. So the *sanctioned* API
exists only on 3.10, and the *only available* API on 3.9 is the one 3.10 has
closed off — a tool supporting both streams would need version-conditional
source, for one line.

## What the patch does

This is an **API backport, not a bug fix** — nothing misbehaves on 3.9; it
merely lacks the entry point. The patch adds the same factory, with the same
signature and semantics, to `compiler/src/dotty/tools/io/package.scala` on the
3.9 stream:

```scala
def virtualDirectory(name: String): AbstractFile =
  new VirtualDirectory(name)
```

`name` is a label used in diagnostics and `toString`; the returned
`AbstractFile` is a fresh, empty in-memory directory. The 3.9
`VirtualDirectory` constructor is left public — 3.9 is a stable release line,
and restricting it would break any existing caller for no gain. The patch
only *adds* the forward-compatible spelling; adopting it is the caller's
choice.

Since 3.10 has the factory from upstream, the patch is carried by the 3.9
stream only. It becomes obsolete when a future stream's upstream base includes
`da99eb87b0` — at that point the branch is simply dropped rather than
rebased forward.

## Relevance to Soundness

[Soundness](https://soundness.dev)'s *anthology* module embeds the compiler to
compile user-supplied code at runtime, entirely in memory:

```scala
val out = dotty.tools.io.virtualDirectory("(memory)")
val driver = new dotc.Driver()
val context = driver.initCtx.fresh
context.settings.outputDir.update(out)(using context)
// ... run the compilation, then walk `out` for the classfiles
```

Anthology builds against both Proscala streams from the same sources. Against
3.10 it *must* use the factory (the constructor is `private[io]`); against an
unpatched 3.9 it *must* use the constructor (the factory does not exist). With
this patch, `virtualDirectory("(memory)")` compiles identically on both, and
anthology is already written against the API every future stream will have —
rather than leaning on a constructor that happens, for now, to still be
public.

# Pickle sourceless positions as their empty path, not an assertion

Restores TASTy position pickling for trees whose source has no underlying
file, which upstream's source-path encapsulation turned into a crash.

## Context

When TASTy pickling walks a tree, `PositionPickler.pickleSource` records the
tree's source file whenever it differs from the compilation unit's own —
inlined and synthesized trees carry the source they originally came from. That
original source can be `NoSource`, the sentinel whose `file` is `null`: a tree
manufactured by a macro or an inline expansion with no position at all still
flows through pickling.

Upstream #26795 ("Encapsulate source paths more", `b3b33d4198`, after
3.10.0-dev-p13's base) replaced the `SourceFile.relativePath` call here with
the new `SourceFile.pathRelativeToSourceRoot`, which *asserts* when the file
is missing:

    java.lang.AssertionError: pathRelativeToSourceRoot called on a missing file
      at dotty.tools.dotc.util.SourceFile.pathRelativeToSourceRoot
      at dotty.tools.dotc.core.tasty.PositionPickler$.pickleSource$1

The old `relativePath` pickled such sources as their path — the empty string —
without complaint, so this is a behavioural regression for any codebase whose
macros produce sourceless trees. Upstream had already met the adjacent case:
#26825 ("Allow in-memory files through SourceFile.pathRelativeToSourceRoot")
relaxed the assertion for *virtual* files, but a `null` file still throws.

## How to reproduce

Compiling Soundness's `proscenium.core` (whose sources are processed by the
beneficence compiler plugin and macro machinery) with the unpatched stream
crashes in the pickler with the assertion above. No self-contained
reproduction has been extracted yet — it needs a macro that splices a tree
carrying `NoSource` spans into a pickled definition (see `repro/FIXME.md`).

## Solution

`pickleSource` falls back to the source's `path` — the empty string — when
`file eq null`, exactly what the replaced `relativePath` produced:

```scala
val path =
  if source.file eq null then source.path
  else source.pathRelativeToSourceRoot
buf.writeInt(pickler.nameBuffer.nameIndex(path.toTermName).index)
```

The alternative of relaxing the assertion inside
`pathRelativeToSourceRoot` itself was rejected as a wider behavioural change:
other callers may rely on the assertion to catch genuinely missing files, and
the pickler is the one place with a defined legacy behaviour to restore.

Only the 3.10 stream carries #26795, so 3.9 needs no patch. Upstream
candidate, as the natural completion of #26825.

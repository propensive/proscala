# No self-contained reproduction yet

Needs a macro that splices a tree carrying `NoSource` spans into a definition
that gets pickled: the pickler then records the tree's source, whose `file` is
null, and the unpatched `pathRelativeToSourceRoot` asserts. The in-tree
reproduction is compiling Soundness's `proscenium.core` module against the
unpatched stream, which crashes with

    AssertionError: pathRelativeToSourceRoot called on a missing file

during `Pickler`. Extracting a standalone macro case is still to do.

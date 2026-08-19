# No self-contained reproduction yet

The failure needs three ingredients in one compilation: a macro (or inline
method) whose dependency resolves to a symbol loaded on demand via
`-sourcepath`, so the unit suspends and restarts in a second run; a class
completed lazily enough that its completer still runs in that second run; and
an implicit search in that completer that walks an imported scope containing a
module from the first run. The in-tree reproduction is the distribution
build's `sjs-scalalib-aux` step (see the feature doc): on an unpatched tree,

    make STREAM=3.10 release

fails there with `StaleSymbolException` on `scala.annotation.compileTimeOnly$`,
and the same invocation passes with `-Yskip:pruneInlinedMethods,pruneInlineTraits`.
Extracting a standalone sourcepath+suspension case is still to do.

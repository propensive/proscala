# The Makefile-based default build

FIXME: this feature is not documented yet.

The simplified Makefile-based build replaces upstream's sbt build. It is the
build, not a patch: it lives on `main` (the `Makefile`, `mk/<stream>.mk`, the
vendored Scala.js IR and the other build inputs) and `bin/proscala-overlay`
drops it into a generated tree as untracked files when `bin/proscala-tree`
makes it, so no patch carries it. It therefore has no patch file and no entry in
the per-stream series. (Earlier it *was* a patch, the base of every other patch
in the stream; that base slot is now occupied by
[`zflags`](../zflags/zflags.md), the `-Z` flag infrastructure, on which every
patch sits.)

What it builds: the modules upstream's sbt build publishes — the compiler,
`scala-library`, `tasty-core`, the REPL, staging, tasty-inspector, sbt-bridge,
the presentation compiler and the Scala.js libraries — plus, on a tree carrying
`library-proscala/src`, the supplementary `proscala-library` jar (and its
Scala.js variant) holding the fork's standard-library additions, so that
`scala-library` itself is what upstream would build from the same sources. See
[compatibility.md](../compatibility.md) for what that means to consumers.

The rationale for replacing the sbt build, what the Makefile covers (and
deliberately does not), and how it relates to the release process deserve a
written explanation here.

# The Makefile-based default build

FIXME: this feature is not documented yet.

The simplified Makefile-based build replaces upstream's sbt build. It is the
build, not a patch: it lives on `main` (the `Makefile`, `mk/<stream>.mk`, the
vendored Scala.js IR and the other build inputs) and `bin/proscala-overlay`
drops it into a code-branch worktree as untracked files at build time, so no
code branch carries it. It therefore has no `feature/<stream>/make` branch and
no entry in the per-stream patch lists; every patch sits directly on
`upstream/<stream>`. (Earlier it *was* such a branch, the base of every other
patch branch in the stream — hence the references you may still find to
`feature/<stream>/make`.)

The rationale for replacing the sbt build, what the Makefile covers (and
deliberately does not), and how it relates to the release process deserve a
written explanation here.

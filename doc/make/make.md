# The Makefile-based default build

FIXME: this feature is not documented yet.

`feature/<stream>/make` is the default build — the base of every other patch
branch — and carries the simplified Makefile-based build. It is the build, not
a patch, so it never had a `doc/features` file; but the rationale for
replacing the sbt build, what the Makefile covers (and deliberately does not),
and how it relates to the release process deserve a written explanation here.

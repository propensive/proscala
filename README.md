Proscala
========

Proscala is the Propensive fork of the [Scala 3](https://www.scala-lang.org)
compiler, standard library and language spec. It maintains a small set of
patches on top of upstream `scala/scala3`.

This repository does not store the Scala compiler's source. It holds Proscala's
**patches**, as `git format-patch` files under [`patches/`](patches), together
with the documentation (this README, the licence and attribution notices, the
policies and process documentation, and the per-feature documentation under
[`doc/`](doc/README.md)) **and the build** (the `Makefile`, per-stream config,
vendored Scala.js sources and helper scripts). A complete source tree is
generated on demand, for any `scala/scala3` commit from the 3.9 era on — a
release, a nightly, a branch head, or one of our pinned development streams — with
the patches that apply there — see *Building* below.

Versions
--------

Proscala has its own version number, independent of the Scala it patches: a
Proscala version is a set of features, each adapted to whichever Scala it is
applied to (or left out, where that Scala already behaves as the feature
promises). Each release is published for every Scala release from 3.9.0 on, and
for a snapshot of upstream `main`, under versions that name both:

```scala
scalaOrganization := "dev.propensive"
scalaVersion      := "3.10.0-proscala-1.0.0"   // Proscala 1.0.0 on Scala 3.10.0
```

Version numbers follow semantic versioning, as [AGENTS.md](AGENTS.md) defines
it for Proscala.

Development happens against two **streams**, pinned upstream commits on the
release lines:

| Stream | Tracks upstream                |
| ------ | ------------------------------ |
| `3.9`  | `scala/scala3` `lts-3.9`       |
| `3.10` | `scala/scala3` `main`          |

The Patches
-----------

- **`patches/series`** lists every patch in the order they are applied. The
  first, `zflags`, is the **stream base**: it adds the `-Z` setting through which
  the fork's opt-in behaviours are enabled by name
  ([`doc/zflags/`](doc/zflags/zflags.md)).
- **`patches/<patch>/`** holds a patch: each is a single, self-contained change
  (e.g. `aliascap`, `unboxedpure`, `wasm`), documented under
  [`doc/<patch>/`](doc/README.md). Its `meta` file says where upstream needs it
  (from the commit that introduced a problem, until the one that fixed it), and
  lists its **versions** — the same change, adapted to different upstream code,
  each with the upstream commits it is known to apply to. For any target, the
  tools apply each patch in range, in its best-fitting version.
- **`mk/<s>.mk`** defines a development **stream**: `UPSTREAM_SHA`, the
  `scala/scala3` commit we develop against (taken from the branch named by
  `UPSTREAM_REF`), and its tested build config.

A patch that genuinely depends on another is named `<dependency>-<patch>` (e.g.
`wasm-witcall`) and follows it in the series.

Everything is on the one `main` branch, and nothing is ever force-pushed: a
changed patch, a newly supported upstream and a release are each an ordinary
commit or tag.
The patch rules, the tooling and the release process are documented in
[AGENTS.md](AGENTS.md). (Until October 2026 each patch was a branch; those
branches are kept as `archive/*` tags.)

Building
--------

Proscala builds with a plain `Makefile` — a simplified, non-bootstrapped build
that compiles every module with a downloaded reference compiler. You need GNU
`make`, a JDK (17 or newer), and `curl`, `javac` and `jar` on your `PATH`.

Generate a source tree, then build it:

```
bin/proscala-tree 3.10        # the 3.10 stream -> worktrees/3.10
cd worktrees/3.10
make
```

The target can equally be a `scala/scala3` release tag (`3.10.0`), a branch
(`main`, `lts-3.9`), a nightly version or a commit id; `bin/proscala-tree
<target> --plan` shows which patch versions it would apply, and
`bin/proscala-coverage` which upstreams lack a version of some patch.

`bin/proscala-tree` fetches the one `scala/scala3` commit it needs (so a plain
clone of this repository is enough), applies the patches as one commit each, and
copies the Makefile and build inputs in as untracked, git-excluded files, picking
the right vendored Scala.js IR for the tree. `make` then downloads the reference
compiler and third-party dependencies from Maven Central (cached under
`.build/`), compiles all the modules, and writes the result to `release/3.10/`:

- `release/3.10/lib/` — the published jars: everything Proscala builds
  (compiler, standard library, `tasty-core`, REPL, staging, tasty-inspector,
  sbt-bridge, presentation compiler, the Scala.js libraries, and
  `proscala-library`, the supplementary jar of the fork's standard-library
  additions for the JVM and Scala.js) plus the Scala.js / scala-wasm runtime
- `release/3.10/deps/` — the remaining third-party runtime jars
- `release/3.10/bin/` — `scalac` and `scala` launchers, ready to run

`make deps` downloads dependencies only, `make tarball` bundles the published jars
into a single `release/3.10/proscala-<version>.tar.gz`, `make release-jars` copies
each of them to `release/3.10/jars/<artifactId>-<version>.jar` under its Maven
name, and `make clean` removes the build.

Releases
--------

Releases are published automatically to
[GitHub Releases](https://github.com/propensive/proscala/releases) and Maven
Central. A release is a tag `v<x.y.z>` on `main`, pushed by
`bin/proscala-release <x.y.z>`, which records the exact upstream commits it is
for. A GitHub Actions workflow then builds every target — each Scala release
from 3.9.0 on, and upstream `main` as it was when the tag was cut — and, only
once all have built, attaches each target's `proscala-<version>.tar.gz` (a
top-level `lib/` of everything Proscala builds plus the Scala.js / scala-wasm
runtime) and each published jar under its Maven name to the GitHub release, and
publishes the same jars to Maven Central.

Contributing
------------

Work happens in a generated tree (`worktrees/<stream>`): each patch is one
commit there, and `bin/proscala-export` writes the tree back to the patch files,
which are committed to `main` with their documentation. The patch rules, build
system and release process are documented in [AGENTS.md](AGENTS.md).

License
-------

Scala 3 is licensed under the
[Apache License Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

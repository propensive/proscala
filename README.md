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
vendored Scala.js sources and helper scripts). A stream's complete source tree is
generated on demand: upstream `scala/scala3` at a pinned commit, with the
stream's patches applied — see *Building* below.

Streams
-------

Proscala's work is organised into **streams**. A stream corresponds to one
major Scala 3 release line, and its name omits the minor/patch number:

| Stream | Tracks upstream                | Release versions   |
| ------ | ------------------------------ | ------------------ |
| `3.9`  | `scala/scala3` `lts-3.9`       | `3.9.1-dev-p<n>`   |
| `3.10` | `scala/scala3` `main`          | `3.10.1-dev-p<n>`  |

The Patches
-----------

For a given stream `<s>`:

- **`mk/<s>.mk`** pins `UPSTREAM_SHA`, the `scala/scala3` commit the stream is
  built on (taken from the branch named by `UPSTREAM_REF`).
- **`patches/<s>/series`** lists the stream's patches in the order they are
  applied. The first, `zflags`, is the **stream base**: it adds the `-Z` setting
  through which the fork's opt-in behaviours are enabled by name
  ([`doc/zflags/`](doc/zflags/zflags.md)).
- **`patches/<s>/<patch>.patch`** holds a patch as that stream carries it, and
  **`patches/common/<patch>.patch`** one that applies unchanged to every stream
  listing it. Each is a single, self-contained change (e.g. `aliascap`,
  `unboxedpure`, `wasm`), documented under [`doc/<patch>/`](doc/README.md). A
  patch that genuinely depends on another is named `<dependency>-<patch>` (e.g.
  `wasm-witcall`) and follows it in the series.

Everything is on the one `main` branch, and nothing is ever force-pushed: an
upstream bump, a changed patch and a release are each an ordinary commit or tag.
The patch rules, the tooling and the release process are documented in
[AGENTS.md](AGENTS.md). (Until October 2026 each patch was a branch; those
branches are kept as `archive/*` tags.)

Building
--------

Proscala builds with a plain `Makefile` — a simplified, non-bootstrapped build
that compiles every module with a downloaded reference compiler. You need GNU
`make`, a JDK (17 or newer), and `curl`, `javac` and `jar` on your `PATH`.

Generate a stream's source tree, then build it:

```
bin/proscala-tree 3.10        # upstream at UPSTREAM_SHA + patches/3.10/series -> worktrees/3.10
cd worktrees/3.10
make
```

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
Central. A release is a tag on `main`, pushed by `bin/proscala-release <stream>`
with the next version (`<upstream-version>-p<n>`, incrementing `<n>` from the
stream's previous release; `-dev-p<n>` for streams that track a non-final
upstream). The tag triggers a GitHub Actions workflow that builds the stream from
the tagged commit and attaches `proscala-<version>.tar.gz` — a top-level `lib/` of
everything Proscala builds plus the Scala.js / scala-wasm runtime — together with
each published jar under its Maven name (`<artifactId>-<version>.jar`), so the
release assets match the artefacts on Maven Central byte for byte.

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

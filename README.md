Proscala
========

Proscala is the Propensive fork of the [Scala 3](https://www.scala-lang.org)
compiler, standard library and language spec. It maintains a small set of
patches on top of upstream `scala/scala3`.

This `main` branch is deliberately empty of code. It holds **only
documentation and repository-wide files** — this README, the licence and
attribution notices, and the policies and process documentation that apply to
the fork as a whole. Every variation of the actual Scala source lives on its
own branch, described below. If you have just cloned the repository and are
wondering where the compiler is, check out one of the branches below (for a
complete, buildable tree, use a `trunk/<stream>` or `release/<stream>` branch).

Streams
-------

Proscala's work is organised into **streams**. A stream corresponds to one
major Scala 3 release line, and its name omits the minor/patch number:

| Stream | Tracks upstream                | Release versions   |
| ------ | ------------------------------ | ------------------ |
| `3.8`  | `scala/scala3` `release-3.8.4` | `3.8.4-p<n>`       |
| `3.9`  | `scala/scala3` `release-3.9.0` | `3.9.0-RC1-p<n>`   |
| `3.10` | `scala/scala3` `main`          | `3.10.0-dev-p<n>`  |

The Branches
------------

Every branch name is prefixed by its role. For a given stream `<s>`:

- **`upstream/<s>`** — a pristine mirror of the matching branch of
  `scala/scala3`, fast-forwarded periodically. Everything else in the stream is
  rebased onto it. Nothing of ours is committed here.

- **`feature/<s>/make`** — the **default build**: the base of every other branch
  in the stream. It sits directly on `upstream/<s>` and carries the simplified
  `Makefile`-based build (see *Building*). Because it is universal, `make` is
  never written into other patch names.

- **`feature/<s>/<patch>`** — one branch per patch, based on
  `feature/<s>/make`. Each holds a single, self-contained change (e.g.
  `aliascap`, `unboxedpure`, `wasm`) plus its feature documentation. A stream
  only carries the patches it needs, so the set differs between streams. A patch
  that genuinely depends on another is named `<dependency>-<patch>` (e.g.
  `wasm-witcall`) and built on that branch.

- **`trunk/<s>`** — the aggregation of *all* of a stream's patches (and
  therefore `make`). It always contains every patch, and is the branch to build
  if you want everything.

- **`scratch/<feature>`** — a throwaway branch for work in progress, usually
  branched off a `trunk/<s>` or `release/<s>`. It is **not** part of the
  published structure: once the work is ready it is split into a clean
  `feature/<s>/<patch>` branch and merged into `trunk/<s>`, and the scratch
  branch is discarded.

- **`release/<s>`** — the published release line, created from `trunk/<s>`. It
  is **protected** (pull-request-only): merging a PR into it triggers a GitHub
  Actions build that tags and publishes a versioned release to
  [GitHub Releases](https://github.com/propensive/proscala/releases).

- **`main`** — this branch. Documentation and repository-wide files only; no
  Scala source.

The full branch model, patch rules, the cross-branch rebase tooling and the
release process are documented in [AGENTS.md](AGENTS.md).

Building
--------

Proscala builds with a plain `Makefile` — a simplified, non-bootstrapped build
that compiles every module with a downloaded reference compiler. You need GNU
`make`, a JDK (17 or newer), and `curl`, `javac` and `jar` on your `PATH`.

From a checkout of any code branch (`feature/*`, `trunk/*` or `release/*`):

```
make
```

This downloads the reference compiler and third-party dependencies from Maven
Central (cached under `.build/`), compiles all the modules, and writes the
result to `release/<branch>/`:

- `release/<branch>/lib/` — the published jars: everything Proscala builds
  (compiler, standard library, `tasty-core`, REPL, staging, tasty-inspector,
  sbt-bridge, presentation compiler and the Scala.js libraries) plus the
  Scala.js / scala-wasm runtime
- `release/<branch>/deps/` — the remaining third-party runtime jars
- `release/<branch>/bin/` — `scalac` and `scala` launchers, ready to run

`make deps` downloads dependencies only, and `make clean` removes the current
branch's build. Both `release/` and `.build/` are git-ignored.

Releases
--------

Releases are published automatically to
[GitHub Releases](https://github.com/propensive/proscala/releases). When a pull
request is merged into a `release/<stream>` branch, a GitHub Actions workflow
performs a clean build, tags it with the next version (`<upstream-version>-p<n>`,
incrementing `<n>` from the previous release; `-dev-p<n>` for streams that track
a non-final upstream), and attaches the published jars — everything Proscala
builds plus the Scala.js / scala-wasm runtime.

Contributing
------------

Development happens on `scratch/<feature>` branches; finished work is isolated
into single-purpose `feature/<stream>/<patch>` branches and merged into
`trunk/<stream>`, then cut into a release via a pull request to
`release/<stream>`. The full branch model, build system and release process are
documented in [AGENTS.md](AGENTS.md).

License
-------

Scala 3 is licensed under the
[Apache License Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

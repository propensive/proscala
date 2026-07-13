# AGENTS.md

This file documents how the Proscala repository is organised — its branch
model, patch rules, cross-branch tooling and release process. It applies to the
repository as a whole and is the same on every branch.

**Important**: all AI-assisted contributions, including code, PR/issue descriptions, comments, and code reviews, must comply with the [LLM usage policy](LLM_POLICY.md) — state LLM usage clearly in descriptions, commit messages, etc.

## Project Overview

Proscala is the Propensive fork of the Scala 3 compiler (`dotc`), standard
library and language spec. It maintains a small set of patches on top of
upstream `scala/scala3`, organised into streams (see below). We care about
maintainability. "The tests pass" is not enough to justify that a change is good.

The Scala source itself lives on the code branches; this `main` branch holds
only documentation and repository-wide files.

## Branch Structure

Proscala maintains a set of patches on top of upstream Scala 3, organised into
**streams**. A stream corresponds to one major Scala 3 release, and its name omits
the minor/patch number: `3.8`, `3.9`, `3.10`.

### Branch naming

- **`upstream/<stream>`** — tracks the matching branch of `scala/scala3` and is
  fast-forwarded periodically. Everything else in the stream is rebased onto it.
  Current mapping:
  - `upstream/3.8` → `scala/scala3` `release-3.8.4`
  - `upstream/3.9` → `scala/scala3` `release-3.9.0`
  - `upstream/3.10` → `scala/scala3` `main`
- **`feature/<stream>/make`** — the **default build**. It carries the simplified
  Makefile-based build and is the base for every other patch in the stream. It sits
  directly on `upstream/<stream>`.
- **`feature/<stream>/<patch>`** — one branch per patch per stream, based on
  `feature/<stream>/make`. `<patch>` is a short alphanumeric identifier (e.g.
  `aliascap`, `unboxedpure`, `wasm`). A stream only carries the patches it needs, so
  the set differs between streams.
- **`trunk/<stream>`** — the aggregation of *all* of a stream's patches (which
  therefore includes `make`). It must always contain every patch. (Formerly
  `all/<stream>`.)
- **`scratch/<feature>`** — a throwaway branch for work in progress, usually
  branched off a `trunk/<stream>` or `release/<stream>`. It is not part of the
  published structure: once the work is ready it is split into a clean
  `feature/<stream>/<patch>` branch and merged into `trunk/<stream>`, and the
  scratch branch is discarded.
- **`release/<stream>`** — the published release line for a stream, created from
  `trunk/<stream>`. It is **protected** (pull-request-only): merging a PR into it
  triggers a GitHub Actions build that tags and publishes a versioned release.
- **`main`** — documentation and repository-wide files only; no Scala source.

### Patch rules

- Every patch is built on `feature/<stream>/make`, the default build. `make` is
  universal, so it is **not** written into patch names — a bare id like `aliascap`
  already means "`make` + that change".
- A patch is a single self-contained change (one or a few commits) on top of `make`.
- **Keep patches independent.** Do not stack a patch on another merely because they
  were developed together. Each branch should hold only its own change on top of
  `make`.
- **Genuine dependencies only.** If a patch cannot work — or cannot even make sense —
  without another patch (beyond `make`), build it on that patch's branch and name it
  `<dependency>-<patch>`, hyphen-separated. Example: `wasm-witcall` — the `witcall`
  intrinsic builds on `wasm`, which itself builds on `make`.
- Prefer the shortest name that captures the real dependency. Long chains of many
  patch ids (`a-b-c-d-…`) are a smell — they are almost always an aggregation
  masquerading as a dependency and should be collapsed back to independent patches
  plus `trunk`.

### Feature documentation

Every patch branch must carry a documentation file, `doc/features/<patch>.md`,
committed on the branch itself so it travels with the patch (and so
`trunk/<stream>` aggregates the full catalogue of feature docs). Writing this
file is part of developing a patch, not an afterthought — add it before the
patch is merged into `trunk`.

Requirements for the file:

- A short `#` title, followed by a **single-sentence description** of the
  feature or bugfix on its own line at the top.
- Sections covering the **context** of the issue, **how to reproduce it**, and
  the **solution** — explained clearly enough for a reader who does not already
  understand the topic, focusing on the relevant details.
- A 2–4 minute read (roughly 400–800 words).
- **Code samples** that are understandable without external context — a minimal
  reproduction, and the key compiler change.
- Where it helps to explain the issue, an example of relevant
  [Soundness](https://soundness.dev) code, since most patches exist because
  Soundness exercises the compiler in ways upstream does not.

The same file (identical content) is used on every stream that carries the
patch. The `make` branch carries no feature doc — it is the build, not a patch.

### Building a distribution

Any build is produced by cherry-picking the wanted patches — all from the **same
stream** — onto `feature/<stream>/make`. `trunk/<stream>` is simply the aggregate of
everything, kept up to date as patches are added or changed.

Builds go through the `make` branch's `Makefile` — a plain `make` (GNU make, plus
`curl`, `javac`, `jar` and a JDK ≥ 17). From a checkout of any code branch:

    make            # equivalently `make release`: a clean, non-bootstrapped
                    # build of every module jar

It downloads the reference compiler and third-party jars from Maven Central,
compiles each module with that reference compiler, and lays out its artefacts
**per branch** under `release/<branch>/`:

- `release/<branch>/lib/`  — **the published jars**: everything we build (compiler,
  stdlib, tasty-core, repl, staging, tasty-inspector, sbt-bridge,
  presentation-compiler, our Scala.js libraries, …) plus the Scala.js / scala-wasm
  runtime jars, so a downloaded release can run Scala.js / WASM output
- `release/<branch>/deps/` — the remaining third-party runtime jars (jline, guava,
  lsp4j, …), needed to run the compiler locally but not published
- `release/<branch>/bin/`  — `scalac` / `scala` launchers whose classpath spans
  both `lib/` and `deps/`, so the local distribution runs as-is

Intermediate classes go under `.build/<branch>/`; downloaded Maven jars are shared
across branches under `.build/jars`. Both `release/` and `.build/` are git-ignored,
so a branch's output is never committed and survives switching branches. Useful
targets: `make deps` (fetch dependencies only), `make clean` / `make distclean`
(remove a branch's output). Override the output path with `make BRANCH=<name>`.

### Keeping up with upstream

We track `scala/scala3` closely and re-base the whole tree onto it frequently, so
patches never drift far from the code they modify. Do this per stream with:

    bin/proscala-rebase-tree <stream> <upstream-ref>
    # e.g. bin/proscala-rebase-tree 3.9 upstream/release-3.9.0
    #      bin/proscala-rebase-tree 3.10 upstream/main

The script (bash 4+) fetches `upstream`, fast-forwards `upstream/<stream>` to the
ref, then rebases `feature/<stream>/make` onto it, every patch onto its parent (in
dependency order — `wasm` before `wasm-witcall`), and finally rebuilds
`trunk/<stream>` as the merge of all patches. It works out each branch's current
base as `merge-base(branch, parent)` so only that branch's own commits are
replayed, and it rebases branches in place when they are checked out in a worktree
so your working copies are left alone.

A branch whose commits clash with upstream is left **unchanged** (its rebase is
aborted) and listed at the end; branches depending on it are skipped. Resolve each
by hand — `git rebase --onto feature/<stream>/make <old-make> feature/<stream>/<patch>`,
fix the conflict, `git rebase --continue` — then re-run the script (it is
idempotent: already-updated branches are no-ops) to finish the tree and rebuild
`trunk`. Review, build-test the affected branches, then push renamed history with
`git push --force-with-lease`. Nothing is pushed by the script.

### Cascading a build change

The `make` branch is the base of every other branch, so a change to the build
(the `Makefile`, vendored sources, `.gitignore`) reaches all branches by
re-basing the tree. Commit the change to `feature/<stream>/make`, then run the
**same** script with no upstream ref:

    bin/proscala-rebase-tree <stream>

With no ref it leaves `upstream/<stream>` (and therefore `make`'s base) alone and
just replays every patch onto the updated `make`, then rebuilds `trunk`. Apply the
change to each stream's `make` (cherry-pick it across) and cascade each stream.

The script never touches `upstream/*`, `main`, or `release/*`. `upstream/*` are
pristine mirrors; `release/*` are protected and move only through pull requests, so
a `make` change (or an upstream update) reaches a release line when the next
`trunk/<stream> → release/<stream>` PR is merged.

### Everyday workflow

1. **Develop.** Branch a `scratch/<feature>` off the relevant `trunk/<stream>`
   (or `release/<stream>`) and do the work there.
2. **Isolate.** When it's ready, split the change onto its own clean
   `feature/<stream>/<patch>` branch — a single-purpose patch on
   `feature/<stream>/make`, following the patch rules above — **and** merge it into
   `trunk/<stream>`. Now the change exists both as a reusable patch and in the
   aggregate.
3. **Accumulate.** Repeat for further changes; `trunk/<stream>` gathers them all.
4. **Release.** When you want to publish, open a pull request from
   `trunk/<stream>` to `release/<stream>`. As release branches are protected, this
   PR is the only route in.
5. **Publish.** Merging the PR triggers the release workflow (below).

Keep the streams in step with upstream out-of-band with `bin/proscala-rebase-tree`
(see *Keeping up with upstream*), which flows into the release lines via step 4.

### Releases

Merging into a `release/<stream>` branch runs `.github/workflows/release.yml`,
which:

1. **Versions** the build as `<upstream-base>-p<n>`. The base is the `Makefile`'s
   `VERSION` with the `-propensive` suffix stripped; `<n>` is one greater than the
   highest existing `-p` tag for that base (starting at `1`). A stream that tracks
   a non-final upstream carries a `-dev` marker in its `VERSION`, so it releases as
   `<base>-dev-p<n>`.
2. **Builds** everything cleanly with `make`.
3. **Tags** the commit with the version and creates a **GitHub release**, attaching
   the published jars (`release/<branch>/lib/*.jar`) — the jars we build plus the
   Scala.js / scala-wasm runtime; the other third-party dependencies are not
   published.

Current streams and their release versions:

| Stream | Tracks | Version |
| ------ | --------------------------- | ------------------- |
| `3.8`  | `scala/scala3 release-3.8.4` | `3.8.4-p<n>`        |
| `3.9`  | `scala/scala3 release-3.9.0` | `3.9.0-RC1-p<n>`    |
| `3.10` | `scala/scala3 main`          | `3.10.0-dev-p<n>`   |

The GitHub token needs `contents: write` (declared in the workflow); the inherited
scala/scala3 CI workflows have been removed, so `Release` is the only workflow that
runs on the fork.

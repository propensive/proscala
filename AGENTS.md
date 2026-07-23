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

The Scala source lives on the code branches; the `main` branch holds the
documentation, repository-wide files **and the build itself** (the Makefile,
per-stream config, vendored Scala.js sources and helper scripts). The build is
overlaid onto a code branch at build time, so the code branches stay pure-source
deviations from upstream.

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
- **`feature/<stream>/<patch>`** — one branch per patch per stream, a **pure-source
  deviation based directly on `upstream/<stream>`**. It carries only its own change —
  no build files (those live on `main` and are overlaid at build time). `<patch>` is
  a short alphanumeric identifier (e.g. `aliascap`, `unboxedpure`, `wasm`). A stream
  only carries the patches it needs, so the set differs between streams.
- **`trunk/<stream>`** — the aggregation of *all* of a stream's patches, merged onto
  `upstream/<stream>`. It must always contain every patch. (Formerly `all/<stream>`.)
- **`scratch/<feature>`** — a throwaway branch for work in progress, usually
  branched off a `trunk/<stream>` or `release/<stream>`. It is not part of the
  published structure: once the work is ready it is split into a clean
  `feature/<stream>/<patch>` branch and merged into `trunk/<stream>`, and the
  scratch branch is discarded.
- **`release/<stream>`** — the published release line for a stream, created from
  `trunk/<stream>`. It is **protected** (pull-request-only): merging a PR into it
  triggers a GitHub Actions build that tags and publishes a versioned release.
- **`main`** — documentation, repository-wide files, **and the build**: the
  `Makefile`, per-stream config (`mk/<stream>.mk`), the vendored Scala.js IR
  (`mk/scalajs-ir/`), the Scala.js scalalib support sources (`library-js-aux/`),
  `project/ScalaLibraryFilesToCopy.scala`, and `bin/` (the overlay and rebase
  tooling). No Scala compiler/library source of its own.

### Patch rules

- Every patch is a pure-source deviation on `upstream/<stream>` — just its own
  change, with **no build files** (the build lives on `main` and is overlaid at
  build time). A bare id like `aliascap` means exactly that change on upstream.
- A patch is a single self-contained change (one or a few commits) on upstream.
- **Keep patches independent.** Do not stack a patch on another merely because they
  were developed together. Each branch should hold only its own change on upstream.
- **Genuine dependencies only.** If a patch cannot work — or cannot even make sense —
  without another patch, build it on that patch's branch and name it
  `<dependency>-<patch>`, hyphen-separated. Example: `wasm-witcall` — the `witcall`
  intrinsic builds on `wasm`, which itself builds on `upstream/<stream>`.
- Prefer the shortest name that captures the real dependency. Long chains of many
  patch ids (`a-b-c-d-…`) are a smell — they are almost always an aggregation
  masquerading as a dependency and should be collapsed back to independent patches
  plus `trunk`.

### Feature documentation

Every patch has a documentation directory on the **`main` branch**,
`doc/<patch>/`, containing `doc/<patch>/<patch>.md` (the feature doc) and, for
bug fixes, `doc/<patch>/repro/` with a minimal reproduction (standalone source
files plus a `README.md` giving the compiler flags and expected failure, or a
`FIXME.md` while no self-contained reproduction is known). `doc/README.md`
indexes all features. Patch branches themselves carry **only code** — no
documentation files. Writing the doc is part of developing a patch, not an
afterthought — add it to `main` before the patch is merged into `trunk`.

Requirements for the doc file:

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

One doc covers every stream that carries the patch; where streams genuinely
differ, the directory carries a clearly named variant file (e.g.
`doc/iarraypure/iarraypure-3.8.md`).

### Building a distribution

Any build is produced from a code branch — a single `feature/<stream>/<patch>`,
or `trunk/<stream>` for the whole stream — by overlaying the build from `main` and
running `make`. The build is a plain `make` (GNU make, plus `curl`, `javac`, `jar`
and a JDK ≥ 17). From a checkout of any code branch:

    git archive origin/main bin/proscala-overlay | tar -x   # bootstrap the helper
    bin/proscala-overlay                                     # drop the build in
    make                                                     # build every module jar

`bin/proscala-overlay` copies the Makefile, the stream's config, the vendored
Scala.js IR (choosing the stock or scala-wasm IR by whether the tree carries the
WASM/WIT sources) and the other build inputs from `main` into the worktree as
untracked, git-excluded files, so `git status` still shows only the branch's own
change. `make` then downloads the reference compiler and third-party jars from Maven
Central,
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
targets: `make deps` (fetch dependencies only), `make tarball` (build, then bundle
the published jars into a single `release/<branch>/proscala-<version>.tar.gz` — what
a release attaches), `make clean` / `make distclean` (remove a branch's output).
Override the output path with `make BRANCH=<name>`. The stream is derived from the
branch name; from a detached checkout (e.g. CI) pass it explicitly with
`make STREAM=3.8|3.9|3.10`.

### Keeping up with upstream

We track `scala/scala3` closely and re-base the whole tree onto it frequently, so
patches never drift far from the code they modify. Do this per stream with:

    bin/proscala-rebase-tree <stream> <upstream-ref>
    # e.g. bin/proscala-rebase-tree 3.9 upstream/release-3.9.0
    #      bin/proscala-rebase-tree 3.10 upstream/main

The script (bash 4+) fetches `upstream`, fast-forwards `upstream/<stream>` to the
ref, then rebases every patch onto its parent (in dependency order — `wasm` before
`wasm-witcall`; a plain patch's parent is `upstream/<stream>`), and finally rebuilds
`trunk/<stream>` as the merge of all patches. It works out each branch's current
base as `merge-base(branch, parent)` so only that branch's own commits are
replayed, and it rebases branches in place when they are checked out in a worktree
so your working copies are left alone. (`-n`/`--dry-run` previews the whole plan and
changes nothing.)

A branch whose commits clash with upstream is left **unchanged** (its rebase is
aborted) and listed at the end; branches depending on it are skipped. Resolve each
by hand — `git rebase --onto upstream/<stream> <old-base> feature/<stream>/<patch>`,
fix the conflict, `git rebase --continue` — then re-run the script (it is
idempotent: already-updated branches are no-ops) to finish the tree and rebuild
`trunk`. Review, build-test the affected branches, then push renamed history with
`git push --force-with-lease`. Nothing is pushed by the script.

### Changing the build

Because the build lives on `main` and is overlaid at build time, a build change
(the `Makefile`, `mk/<stream>.mk`, vendored sources) is a **single commit on
`main`** — there is nothing to cascade across branches. Every subsequent build of
any code branch picks it up automatically. An upstream update reaches a release line
through the next `trunk/<stream> → release/<stream>` pull request; a build change on
`main` reaches every build immediately (and a release when it is next cut).

The rebase-tree script never touches `upstream/*`, `main`, or `release/*`.
`upstream/*` are pristine mirrors and `release/*` are protected, moving only through
pull requests.

### Everyday workflow

1. **Develop.** Branch a `scratch/<feature>` off the relevant `trunk/<stream>`
   (or `release/<stream>`) and do the work there.
2. **Isolate.** When it's ready, split the change onto its own clean
   `feature/<stream>/<patch>` branch — a single-purpose, source-only patch on
   `upstream/<stream>`, following the patch rules above — **and** merge it into
   `trunk/<stream>`. Now the change exists both as a reusable patch and in the
   aggregate.
3. **Accumulate.** Repeat for further changes; `trunk/<stream>` gathers them all.
4. **Release.** When you want to publish, open a pull request from
   `trunk/<stream>` to `release/<stream>`. As release branches are protected, this
   PR is the only route in.
5. **Publish.** Merging the PR triggers the release workflow (below).

**Release PRs after a rebase-tree run.** Rebasing the tree rewrites trunk's
history while the release branch keeps the pre-rebase commits, so a direct
`trunk → release` PR can show conflicts — reliably so when upstream touched the
CI workflow files, because release branches strip the inherited scala3
workflows (keeping only `release.yml`), and delete-vs-modify always conflicts.
Do not resolve such a PR by hand. Instead build a deterministic resolution
merge on a prep branch — trunk's content with release's `.github/` — and PR
that:

    git worktree add /tmp/relprep -b prep/release-<stream> trunk/<stream>
    cd /tmp/relprep
    git merge -s ours --no-commit origin/release/<stream>
    git rm -rq .github && git checkout origin/release/<stream> -- .github
    git commit

Verify before pushing: `git diff --name-only trunk/<stream> HEAD` must list
only `.github/` paths, and `git diff origin/release/<stream> HEAD -- .github`
must be empty. Open the PR from `prep/release-<stream>`; delete the prep
branch after the merge. (First needed for release/3.10, PR #12, 2026-07.)

Keep the streams in step with upstream out-of-band with `bin/proscala-rebase-tree`
(see *Keeping up with upstream*), which flows into the release lines via step 4.

### Releases

Merging into a `release/<stream>` branch runs `.github/workflows/release.yml`,
which:

1. **Overlays** the build from `main` (`bin/proscala-overlay`), so the release
   branch — which holds only Scala source plus this workflow — can be built.
2. **Versions** the build as `<upstream-base>-p<n>`. The base is the stream's
   `mk/<stream>.mk` `VERSION` with the `-propensive` suffix stripped; `<n>` is one
   greater than the highest existing `-p` tag for that base (starting at `1`). A
   stream that tracks a non-final upstream carries a `-dev` marker in its `VERSION`,
   so it releases as `<base>-dev-p<n>`.
3. **Builds** everything cleanly (`make … tarball`).
4. **Tags** the commit with the version and creates a **GitHub release**, attaching a
   single `proscala-<version>.tar.gz` — a top-level `lib/` of the jars we build plus
   the Scala.js / scala-wasm runtime; third-party dependencies are not published.

Current streams and their release versions:

| Stream | Tracks | Version |
| ------ | --------------------------- | ------------------- |
| `3.8`  | `scala/scala3 release-3.8.4` | `3.8.4-p<n>`        |
| `3.9`  | `scala/scala3 release-3.9.0` | `3.9.0-RC4-p<n>`    |
| `3.10` | `scala/scala3 main`          | `3.10.0-dev-p<n>`   |

The GitHub token needs `contents: write` (declared in the workflow). Because the
code branches are now pure upstream, they carry the inherited scala/scala3 CI
workflow files again; those are **disabled at the repository level** (Actions →
each workflow → Disable), so `Release` is the only workflow that runs on the fork.
`release.yml` lives only on the `release/<stream>` branches — the one build-related
file that must sit on a branch, so a push there triggers it.

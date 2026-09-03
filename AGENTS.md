# AGENTS.md

This file documents how the Proscala repository is organised — its branch
model, patch rules, cross-branch tooling and release process. It describes the
repository as a whole, but it lives **only on `main`**, alongside the
documentation and the build.

The code branches (`upstream/*`, `feature/*`, `trunk/*`, `release/*`) are pure
upstream source, so each carries *upstream Scala 3's* own `AGENTS.md` instead —
a different, unrelated file about building `dotc` with sbt, which knows nothing
of streams, patches or this fork's layout. If you are working in a code-branch
worktree, the `AGENTS.md` next to you is not this one: read this file from
`main` (`git show main:AGENTS.md`).

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
the minor/patch number: `3.9`, `3.10`.

### Branch naming

- **`upstream/<stream>`** — tracks the matching branch of `scala/scala3` and is
  fast-forwarded periodically. Everything else in the stream is rebased onto it.
  Which branch each mirrors is recorded as `UPSTREAM_REF` in `mk/<stream>.mk`, and
  that is the authoritative copy — the mapping below is checked against it:
  - `upstream/3.9` → `scala/scala3` `release-3.9.0`
  - `upstream/3.10` → `scala/scala3` `main`
- **`feature/<stream>/zflags`** — the **stream base**: a single commit on
  `upstream/<stream>` adding the `-Z` setting and the registry of names behind
  which the fork's opt-in behaviours are enabled (`config.Proscala`; see
  `doc/zflags/zflags.md`). Not a patch: it is not listed in `features/<stream>`,
  every patch is rebased onto it, and `trunk/<stream>` is built on it. It is
  edited only to register a new gated patch's name.
- **`feature/<stream>/<patch>`** — one branch per patch per stream, a **pure-source
  deviation based on the stream base**. It carries only its own change —
  no build files (those live on `main` and are overlaid at build time). `<patch>` is
  a short alphanumeric identifier (e.g. `aliascap`, `unboxedpure`, `wasm`). A stream
  only carries the patches it needs, so the set differs between streams.
- **`trunk/<stream>`** — the aggregation of *all* of a stream's patches, merged onto
  the stream base. It must always contain every patch named in
  `features/<stream>`. (Formerly `all/<stream>`.)
- **`scratch/<feature>`** — a throwaway branch for work in progress, usually
  branched off a `trunk/<stream>` or `release/<stream>`. It is not part of the
  published structure: once the work is ready it is split into a clean
  `feature/<stream>/<patch>` branch and merged into `trunk/<stream>`, and the
  scratch branch is discarded.
- **`release/<stream>`** — the published release line for a stream, created from
  `trunk/<stream>`. It is **protected** (pull-request-only): merging a PR into it
  triggers a GitHub Actions build that tags and publishes a versioned release.
- **`main`** — documentation, repository-wide files, **and the build**: the
  `Makefile`, per-stream config (`mk/<stream>.mk`), the per-stream patch lists
  (`features/<stream>`), the vendored Scala.js IR (`mk/scalajs-ir/`), the Scala.js
  scalalib support sources (`library-js-aux/`),
  `project/ScalaLibraryFilesToCopy.scala`, and `bin/` (the overlay and rebase
  tooling). No Scala compiler/library source of its own.

### Patch rules

- Every patch is a pure-source deviation on the stream base
  (`feature/<stream>/zflags`, itself one commit on `upstream/<stream>`) — just
  its own change, with **no build files** (the build lives on `main` and is
  overlaid at build time). A bare id like `aliascap` means exactly that change.
- **Gate a patch behind `-Z` only where its off state is a meaningful choice**:
  a change to what the compiler produces for code it already accepted, or one
  that rejects code upstream accepts. A crash, hang or spurious-error fix is
  always on. A gated patch registers its name in `config.Proscala` on the base
  (one edit there, never in the patch) and tests
  `config.Proscala.enabled(config.Proscala.<Feature>)` at each site, keeping
  upstream's code as the other branch; its doc states the flag, and its row in
  `doc/README.md` carries it in the `Flag` column. Flags that change pickled
  capture sets must be documented in `doc/compatibility.md` as shared across
  module boundaries. See `doc/zflags/zflags.md`.
- A patch is a single self-contained change (one or a few commits) on the stream base.
- **Keep patches independent.** Do not stack a patch on another merely because they
  were developed together. Each branch should hold only its own change on the base.
- **Genuine dependencies only.** If a patch cannot work — or cannot even make sense —
  without another patch, build it on that patch's branch and name it
  `<dependency>-<patch>`, hyphen-separated. Example: `wasm-witcall` — the `witcall`
  intrinsic builds on `wasm`, which itself builds on the stream base.
- Prefer the shortest name that captures the real dependency. Long chains of many
  patch ids (`a-b-c-d-…`) are a smell — they are almost always an aggregation
  masquerading as a dependency and should be collapsed back to independent patches
  plus `trunk`.

### The stream feature lists

Which patches a stream carries is defined on `main`, in `features/<stream>` — one
patch id per line (the `<patch>` part of `feature/<stream>/<patch>`), with blank
lines and `#` comments ignored and order irrelevant. The lists differ between
streams: a patch only exists where it is needed, and some are upstreamed or become
obsolete in a later stream.

    features/3.9    33 patches   carries castbox, depset, splicealias, samstateful, staleread, virtualdir
    features/3.10   35 patches   adds anonspec, anykindcap, boolunapply, integratemap, macroalias, modulepath, prunecomplete, unioncaps; drops those six

Twenty-six patches are common to both streams.

**This list is authoritative, not descriptive.** `bin/proscala-rebase-tree`
rebuilds `trunk/<stream>` as the merge of exactly these patches, so the list — not
the set of branches your clone happens to hold — decides what a trunk contains.
The script reconciles the two before it touches anything:

- a listed patch with no local branch is created from `origin/feature/<s>/<patch>`;
- a listed patch that exists neither locally nor on origin is a fatal error;
- a `feature/<s>/*` branch that is **not** listed is a fatal error — add it to the
  list or delete the branch.

The last two matter: before the lists existed the script enumerated local branches
only, so a clone holding a subset of a stream would rebuild its trunk from that
subset, drop every other patch, and report success. Work in progress belongs on
`scratch/<feature>`, which is why a stray unlisted `feature/` branch is treated as
an error rather than silently included.

Adding a patch to a stream therefore means adding its id to `features/<stream>` in
the same change that creates the branch. Removing one means deleting the line (and
the branch).

### Keeping the documentation honest

The same fact is often stated in several places — a stream's patches appear in
`features/<stream>` and in the `Streams` column of `doc/README.md`; its upstream
branch and release version appear in `mk/<stream>.mk`, `README.md` and twice in
this file. Rather than trying to remember every copy, **each fact has one source
of truth and the copies are checked against it**:

| Fact | Source of truth |
| ---- | --------------- |
| which patches a stream carries | `features/<stream>` |
| which `scala/scala3` branch a stream mirrors | `UPSTREAM_REF` in `mk/<stream>.mk` |
| what a stream releases as | `VERSION` in `mk/<stream>.mk` |
| whether a patch has a reproduction | the filesystem, `doc/<patch>/repro*/` |
| which `-Z` name enables a patch | `config.Proscala` on `feature/<stream>/zflags` |

    bin/proscala-check-docs        # exit 1 and list every divergence
    bin/proscala-check-docs -v     # also show what passed

It checks the feature table against the lists, the `Repro` column against the
reproductions that actually exist, the `Flag` column against the registry on
each stream's `zflags` branch, the stream tables in `README.md` and this file
against `mk/<stream>.mk`, the patch counts quoted above, that no feature doc
hard-codes a stream when its patch spans several, that every relative link
resolves, and — when the `origin/*` refs are present — that every feature branch
is listed and every listed patch is merged into its trunk. Run it after touching
any of them; `.github/workflows/check-docs.yml` runs it on `main` too.

It checks structure, not prose: it cannot tell you that a feature doc has stopped
describing what its patch does. That still needs reading.

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
a clearly named variant file).

### Building a distribution

Any build is produced from a code branch — a single `feature/<stream>/<patch>`,
or `trunk/<stream>` for the whole stream — by overlaying the build from `main` and
running `make`. The build is a plain `make` (GNU make, plus `curl`, `javac`, `jar`
and a JDK ≥ 17; publishing to Maven Central additionally needs `gpg` and `zip`).
From a checkout of any code branch:

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
  presentation-compiler, our Scala.js libraries, the supplementary
  proscala-library for the JVM and Scala.js, …) plus the Scala.js / scala-wasm
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
`make STREAM=3.9|3.10`.

### Keeping up with upstream

We track `scala/scala3` closely and re-base the whole tree onto it frequently, so
patches never drift far from the code they modify. Do this per stream with:

    bin/proscala-rebase-tree <stream> <upstream-ref>
    # e.g. bin/proscala-rebase-tree 3.9 upstream/release-3.9.0
    #      bin/proscala-rebase-tree 3.10 upstream/main

The script (bash 4+) takes the stream's patches from `features/<stream>` (see *The
stream feature lists*), creating any listed branch this clone is missing from
`origin` and refusing to run if the list and the branches disagree. It then fetches
`upstream`, fast-forwards `upstream/<stream>` to the ref, rebases the stream base
`feature/<stream>/zflags` onto it, then every patch onto its parent (in dependency
order — `wasm` before `wasm-witcall`; a plain patch's parent is the base), and
finally rebuilds `trunk/<stream>` as the merge of all patches. A trunk merge that
conflicts is committed automatically when `rerere` has a recorded resolution for
it; otherwise the script stops and names the scratch worktree to resolve it in. It works out each branch's current base as
`merge-base(branch, parent)` so only that branch's own commits are replayed, and it
rebases branches in place when they are checked out in a worktree so your working
copies are left alone. (`-n`/`--dry-run` previews the whole plan — including which
branches it would create — and changes nothing.)

It needs an `upstream` remote pointing at `scala/scala3`
(`git remote add upstream https://github.com/scala/scala3.git`) and a local
`upstream/<stream>` mirror branch; a fresh clone has neither.

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
   `upstream/<stream>`, following the patch rules above — **add its id to
   `features/<stream>` on `main`**, **and** merge it into `trunk/<stream>`. Now the
   change exists as a reusable patch, in the stream's patch list, and in the
   aggregate. A patch missing from the list will be dropped from `trunk` by the
   next rebase-tree run, which refuses to proceed until the two agree. Add the
   patch's row to `doc/README.md` and run `bin/proscala-check-docs`.
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

0. **Checks the four publishing secrets and imports the signing key**, before
   anything irreversible happens — see *Publishing to Maven Central* below.
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
5. **Publishes the same jars to Maven Central** (`make … publish`), under
   `dev.propensive`, at the same version.

### Publishing to Maven Central

Every release also goes to Maven Central, from the same trigger. The machinery
is `mk/publish.mk` on `main` (overlaid with the rest of the build), so it is a
**single commit on `main`** like any other build change — the release branches
only carry the workflow step that invokes it.

    make VERSION=<v> publish-bundle   # build, stage, sign, zip — no upload
    make VERSION=<v> publish          # ... and upload to the Central Portal

Fifteen artifacts are published, under the group `dev.propensive`, at
`<upstream-base>-p<n>`. Thirteen carry **the same artifact names as the mainline
Scala releases**: `scala-library`, `scala3-library_3`, `scala3-interfaces`,
`tasty-core_3`, `scala3-compiler_3`, `scala3-directives-parser_3`,
`scala3-staging_3`, `scala3-tasty-inspector_3`, `scala3-repl_3`,
`scala3-sbt-bridge`, `scala3-presentation-compiler_3`, `scalajs-scalalib_2.13` and
`scala3-library_sjs1_3`; matching the mainline names is what lets sbt's
`scalaOrganization := "dev.propensive"` swap the fork in wholesale. Two are the
fork's own: `proscala-library_3` and `proscala-library_sjs1_3`, the
**supplementary library** holding the standard-library additions
(`scala.Literate`, `scala.Spreadable`, `scala.annotation.internal.diagnostic`)
from `library-proscala/src` on the code branches, built into their own jar so
`scala-library` stays byte-identical to upstream's from the same sources.
Consumers add it beside a `scala3-library`, and the compiler finds its classes
by name, so nothing else depends on it. A WASM tree publishes a sixteenth,
`scalajs-library_2.13` — see below. Both release streams carry the `wasm` patch,
so a real release publishes sixteen.

Each gets a POM, a sources jar and an (empty) javadoc jar, all GPG-signed with
md5/sha1 checksums, bundled into one zip and uploaded to the Central Portal with
`publishingType=AUTOMATIC` — so a release goes live unattended. **Maven Central
is append-only**: a published version can never be replaced, only superseded by
the next `-p<n>`.

The POM dependency graph is derived from the same `mk/<stream>.mk` variables the
compile classpaths use, so a version bump moves the POMs with it and there is no
second copy to drift. It matches the graph Soundness already resolves the fork
through (the `repo` task in its `build.mill`), plus the two modules Soundness
does not use.

#### The Scala.js artifacts

Two wrinkles here, both stemming from the same thing: on the classpath, Scala.js
artifacts must be present exactly once, because the linker treats a class defined
in two jars as a duplicate definition and refuses it.

**The stdlib.** `scalajs-library_2.13` depends on `scalajs-scalalib_2.13` — the
Scala 2.13 Scala.js stdlib. Upstream publishes *its* Scala 3 stdlib to that
**same coordinate** at the Scala version, so version-conflict resolution evicts
the 2.13 one; that is why a Scala 3 artifact carries a `_2.13` suffix at all.
Publishing under `dev.propensive` is a different coordinate, so nothing is
evicted. On a **stock tree** our `scala3-library_sjs1_3` POM therefore carries an
explicit `<exclusion>` on the dependency that drags the 2.13 one in, with the
excluded group following the tree (`org.scala-js`, or `io.github.scala-wasm` on
the scala-wasm fork).

**The library itself, on a WASM tree.** The `$(SJS_LIB_SHIP)` recipe does not
merely add to the Scala.js library: it *replaces* its `scala/scalajs/wit/package*`
with Proscala's — the fork's version has only `native`, ours adds nine `wit*`
intrinsics including `witImportCall` — and *deletes* all of
`scala/scalajs/wasi/*`, so those facades reach the classpath only from the
scalalib. That single provenance matters: mixed provenance reorders WIT variant
cases, so (for example) `wasi:http`'s `get` encodes as the `post` discriminant —
a silent miscompilation, not an error.

Neither half can be shipped as an extra jar beside the stock library: the wit
package would be a duplicate class rather than an addition, and nothing can
remove entries from someone else's jar. So a WASM tree publishes the patched
library as `dev.propensive:scalajs-library_2.13`, at the Scala version, and
consumers resolve that instead — the same substitution Soundness makes locally in
its `build.mill` `repo` task. Its POM records the provenance and the Apache-2.0
licence of the original.

A pleasant consequence: with library *and* scalalib both under `dev.propensive`,
no stock Scala.js artifact enters our graph at all, so on a WASM tree the
`<exclusion>` above is unnecessary and is not emitted.

Four repository secrets are required (Settings → Secrets and variables →
Actions); the workflow fails fast if any is missing:

| Secret | What it is |
| ------ | ---------- |
| `SONATYPE_USERNAME` | Central **user token** name (not portal login) |
| `SONATYPE_PASSWORD` | Central user token secret |
| `GPG_PRIVATE_KEY`   | ASCII-armoured private key (`gpg --armor --export-secret-keys <id>`) |
| `GPG_PASSPHRASE`    | that key's passphrase |

Locally the same target reads `SONATYPE_USERNAME` / `SONATYPE_PASSWORD` from the
environment, and leaves `gpg-agent` in charge when `PROSCALA_GPG_PASSPHRASE` is
unset — so it prompts through pinentry exactly as `consequent`'s `etc/ci/release.sh`
does. Sourcing the credentials from the macOS keychain, as consequent documents:

    export SONATYPE_USERNAME=$(security find-generic-password -a proscala-release \
      -s proscala.sonatype.username -w)
    export SONATYPE_PASSWORD=$(security find-generic-password -a proscala-release \
      -s proscala.sonatype.password -w)

Current streams and their release versions:

| Stream | Tracks | Version |
| ------ | --------------------------- | ------------------- |
| `3.9`  | `scala/scala3 release-3.9.0` | `3.9.0-RC6-p<n>`    |
| `3.10` | `scala/scala3 main`          | `3.10.1-dev-p<n>`   |

The GitHub token needs `contents: write` (declared in the workflow). Because the
code branches are now pure upstream, they carry the inherited scala/scala3 CI
workflow files again; those are **disabled at the repository level** (Actions →
each workflow → Disable). Only two workflows of ours run on the fork: `Release`,
from `release.yml` on the `release/<stream>` branches — the one build-related file
that must sit on a branch, so a push there triggers it — and `Check docs`, from
`.github/workflows/check-docs.yml` on `main`, which runs `bin/proscala-check-docs`
(see *Keeping the documentation honest*). A newly added workflow is enabled by
default, so neither needs anything switched on; the disabling above applies only
to the inherited scala/scala3 ones.

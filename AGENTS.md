# AGENTS.md

This file documents how the Proscala repository is organised — its layout,
patch rules, tooling and release process.

Everything lives on one branch, `main`. The Scala source is not stored here:
each stream's tree is generated from upstream `scala/scala3` plus this
repository's patch files, into a worktree under `worktrees/<stream>`. That tree is
pure upstream source plus the patches, so it carries *upstream Scala 3's* own
`AGENTS.md` — a different, unrelated file about building `dotc` with sbt, which
knows nothing of streams, patches or this fork's layout. If you are working in a
generated tree, the `AGENTS.md` next to you is not this one: read this file from
`main`.

**Important**: all AI-assisted contributions, including code, PR/issue descriptions, comments, and code reviews, must comply with the [LLM usage policy](LLM_POLICY.md) — state LLM usage clearly in descriptions, commit messages, etc.

## Project Overview

Proscala is the Propensive fork of the Scala 3 compiler (`dotc`), standard
library and language spec. It maintains a small set of patches on top of
upstream `scala/scala3`, organised into streams (see below). We care about
maintainability. "The tests pass" is not enough to justify that a change is good.

`main` holds the patches (as `git format-patch` files), the documentation, the
repository-wide files **and the build** (the Makefile, per-stream config,
vendored Scala.js sources and helper scripts). Nothing is ever force-pushed: an
upstream bump, a new or changed patch and a release are each an ordinary commit
(or tag) on `main`.

## Repository layout

Proscala's patches are organised into **streams**. A stream corresponds to one
major Scala 3 release, and its name omits the minor/patch number: `3.9`, `3.10`.

- **`mk/<stream>.mk`** — the stream's build config, including the two facts that
  tie it to upstream: `UPSTREAM_SHA`, the `scala/scala3` commit its patches apply
  onto, and `UPSTREAM_REF`, the `scala/scala3` branch that commit is taken from.
- **`patches/<stream>/series`** — the stream's patches, one name per line, **in
  the order they are applied**, with blank lines and `#` comments ignored. The
  first is always `zflags`, the stream base (below).
- **`patches/<stream>/<patch>.patch`** — a patch as this stream carries it.
- **`patches/common/<patch>.patch`** — a patch shared by every stream that lists
  it and has no copy of its own. A stream copy always wins over common.
- **`worktrees/<stream>`** — git-ignored; the generated source tree, made by
  `bin/proscala-tree`. It is a git worktree of this repository, detached at
  `UPSTREAM_SHA`, with one commit per patch on top.
- **`doc/`** — per-patch documentation (below); **`bin/`** — the tooling;
  **`mk/scalajs-ir/`**, **`library-js-aux/`**,
  **`project/ScalaLibraryFilesToCopy.scala`** — build inputs overlaid into a tree.

The upstream `scala/scala3` history is needed only for the commits named by
`UPSTREAM_SHA`, and the tools fetch exactly those on demand (from a remote named
`upstream` if you have one, else straight from GitHub), so a plain clone of this
repository is enough to build any stream. Work in progress may be pushed to any
branch for safe keeping, but nothing depends on such branches.

The repository used to hold each patch as its own branch (`feature/<stream>/<patch>`,
merged into `trunk/<stream>`, published through `release/<stream>`). Those
branches were retired in October 2026; every one of them is kept, unchanged, as a
tag `archive/<branch>`.

### Patch files

A patch file is `git format-patch` output for **exactly one commit**: its author,
date, message and diff. The message ends with a trailer naming the patch,

    Proscala-Patch: aliascap

which is how `bin/proscala-export` maps a tree's commits back to files. Since
`git am` cuts a message at a line consisting of `---`, a patch's message must not
contain one. The files are written only by `bin/proscala-export` (below), with
every git setting that would change their bytes pinned, so the same commit always
produces the same file. They are meant to be read: review a change to a patch as
the diff of its file.

### Patch rules

- Every patch is a pure-source change on the stream base — just its own change,
  with **no build files** (the build lives on `main` and is overlaid at build
  time). A bare id like `aliascap` means exactly that change.
- **`zflags` is the stream base, not a patch**: it adds the `-Z` setting and the
  registry of names behind which the fork's opt-in behaviours are enabled
  (`config.Proscala`; see `doc/zflags/zflags.md`). It comes first in every
  series, has no row in `doc/README.md`, and is edited only to register a new
  gated patch's name.
- **Gate a patch behind `-Z` only where its off state is a meaningful choice**:
  a change to what the compiler produces for code it already accepted, or one
  that rejects code upstream accepts. A crash, hang or spurious-error fix is
  always on. A gated patch registers its name in `config.Proscala` in `zflags`
  (one edit there, never in the patch) and tests
  `config.Proscala.enabled(config.Proscala.<Feature>)` at each site, keeping
  upstream's code as the other branch; its doc states the flag, and its row in
  `doc/README.md` carries it in the `Flag` column. Flags that change pickled
  capture sets must be documented in `doc/compatibility.md` as shared across
  module boundaries. See `doc/zflags/zflags.md`.
- A patch is a single self-contained change, held as one commit. (Work on it in
  as many commits as you like; squash them before exporting.)
- **Keep patches independent.** Do not make a patch rely on another merely
  because they were developed together. Two patches may touch the same file, in
  which case the later one in the series is written against the earlier one's
  result — that is ordering, not dependency.
- **Genuine dependencies only.** If a patch cannot work — or cannot even make sense —
  without another patch, name it `<dependency>-<patch>`, hyphen-separated, and
  list it after its dependency. Example: `wasm-witcall` — the `witcall` intrinsic
  builds on `wasm`.
- Prefer the shortest name that captures the real dependency. Long chains of many
  patch ids (`a-b-c-d-…`) are a smell — they are almost always an aggregation
  masquerading as a dependency and should be collapsed back to independent patches.

### The stream series

Which patches a stream carries, and in what order, is `patches/<stream>/series`.
The streams differ: a patch only exists where it is needed, and some are
upstreamed or become obsolete in a later stream.

    patches/3.9/series    36 patches   carries castbox, depset, splicealias, samstateful, staleread, virtualdir, rootclassify, sharedunscoped, classifiermeet
    patches/3.10/series   33 patches   adds anonspec, anykindcap, boolunapply, integratemap, macroalias, modulepath, prunecomplete, unioncaps; drops those six, and nullreceiver and permitlazy (fixed upstream)

(The counts exclude `zflags`.) Twenty-five patches are carried by both streams;
twelve of them apply unchanged to both and are kept once, in `patches/common/`,
and the other thirteen differ in their surrounding code (or more) and are kept
per stream.

**A common file must suit every stream that uses it.** `bin/proscala-export`
writes a changed shared patch back to `patches/common/` only if every other stream
using it still applies with the new version, and then says loudly that those
streams' trees changed and want rebuilding and testing. If a stream can no longer
use the shared version, its copy is forked into `patches/<stream>/` automatically.
Promoting a stream copy to `common/` is a deliberate `git mv` (keeping one copy and
deleting the others), which `bin/proscala-check` then verifies. Shared patches
must appear in the same relative order in every series.

### Keeping the documentation honest

The same fact is often stated in several places — a stream's patches appear in
`patches/<stream>/series` and in the `Streams` column of `doc/README.md`; its
upstream branch and release version appear in `mk/<stream>.mk`, `README.md` and in
this file. Rather than trying to remember every copy, **each fact has one source
of truth and the copies are checked against it**:

| Fact | Source of truth |
| ---- | --------------- |
| which patches a stream carries, in what order | `patches/<stream>/series` |
| which `scala/scala3` commit a stream is built on | `UPSTREAM_SHA` in `mk/<stream>.mk` |
| which `scala/scala3` branch that commit is from | `UPSTREAM_REF` in `mk/<stream>.mk` |
| what a stream releases as | `VERSION` in `mk/<stream>.mk` |
| whether a patch has a reproduction | the filesystem, `doc/<patch>/repro*/` |
| which `-Z` name enables a patch | `config.Proscala`, as the stream's series builds it |

    bin/proscala-check        # exit 1 and list every divergence
    bin/proscala-check -v     # also show what passed

It applies every stream's series onto its `UPSTREAM_SHA` (in a throwaway index,
with no worktree, and without three-way merging — the definition of "the series
applies"), and checks that every patch file holds one commit with the right
trailer, that no file is unused and no stream copy merely duplicates
`patches/common/`, and that shared patches keep one order. It checks the feature
table against the series, the `Repro` column against the reproductions that
actually exist, the `Flag` column against the registry the series builds, the
stream tables in `README.md` and this file against `mk/<stream>.mk`, the patch
counts quoted above, that no feature doc hard-codes a stream when its patch spans
several, and that every relative link resolves. It notes, without failing, any
patch that two streams carry as separate files with identical changes (a
candidate for `patches/common/`). Run it after touching any of them;
`.github/workflows/check.yml` runs it on every push and pull request to `main`.

It checks structure, not prose: it cannot tell you that a feature doc has stopped
describing what its patch does. That still needs reading.

### Feature documentation

Every patch has a documentation directory, `doc/<patch>/`, containing
`doc/<patch>/<patch>.md` (the feature doc) and, for bug fixes,
`doc/<patch>/repro/` with a minimal reproduction (standalone source files plus a
`README.md` giving the compiler flags and expected failure, or a `FIXME.md` while
no self-contained reproduction is known). `doc/README.md` indexes all features.
Patches themselves carry **only code** — no documentation files. Writing the doc
is part of developing a patch, not an afterthought — commit it with the patch.

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
differ, the directory carries a clearly named variant file.

## The tools

All need bash 4+ and git; building additionally needs GNU make, `curl`, `javac`,
`jar` and a JDK ≥ 17, and publishing to Maven Central needs `gpg` and `zip`.

### Building a stream: `bin/proscala-tree`

    bin/proscala-tree 3.10            # make worktrees/3.10
    cd worktrees/3.10 && make         # build every module jar

`bin/proscala-tree <stream> [<dir>]` creates a git worktree at `<dir>` (default
`worktrees/<stream>`), detached at `UPSTREAM_SHA`, applies the series with
`git am` — one commit per patch, so `git log` in the tree reads like the patch
list — and overlays the build from this checkout's `HEAD` (`bin/proscala-overlay`
copies the Makefile, the stream's config, the vendored Scala.js IR — the stock or
scala-wasm IR, by whether the tree carries the WASM/WIT sources — and the other
build inputs in as untracked, git-excluded files). `make` then downloads the
reference compiler and third-party jars from Maven Central, compiles each module
with that reference compiler, and lays out its artefacts under the tree's
`release/<name>/`, where `<name>` is the tree's directory name:

- `release/<name>/lib/`  — **the published jars**: everything we build (compiler,
  stdlib, tasty-core, repl, staging, tasty-inspector, sbt-bridge,
  presentation-compiler, our Scala.js libraries, the supplementary
  proscala-library for the JVM and Scala.js, …) plus the Scala.js / scala-wasm
  runtime jars, so a downloaded release can run Scala.js / WASM output
- `release/<name>/deps/` — the remaining third-party runtime jars (jline, guava,
  lsp4j, …), needed to run the compiler locally but not published
- `release/<name>/bin/`  — `scalac` / `scala` launchers whose classpath spans
  both `lib/` and `deps/`, so the local distribution runs as-is

Intermediate classes go under `.build/<name>/`; downloaded Maven jars are shared
under `.build/jars`. Useful targets: `make deps` (fetch dependencies only),
`make tarball` (build, then bundle the published jars into a single
`release/<name>/proscala-<version>.tar.gz`), `make release-jars` (copy each
published jar to `release/<name>/jars/<artifactId>-<version>.jar`, under its Maven
name — a release attaches the tarball and these jars), `make clean` /
`make distclean`. The stream is read from the tree's `.proscala-stream`; override
the output name with `make BRANCH=<name>`. The overlay comes from the *committed*
`HEAD` of this checkout, so commit a build change before rebuilding a tree with it.

Other modes: `--only <patch>` applies just `zflags` and one patch, to build it in
isolation; `--reset` rebuilds an existing tree, but refuses if the tree holds any
commit whose change is in no patch file (each tree records which file it applied
for each patch, so a tree that is merely out of date is never mistaken for one
holding work); `--continue` resumes after a patch that did not apply (below).

### Writing patches back: `bin/proscala-export`

    bin/proscala-export 3.10          # worktrees/3.10 -> patches/3.10/ (and common/)

`bin/proscala-export <stream> [<dir>]` reads the tree's commits above
`UPSTREAM_SHA` — each must be an ordinary commit with a `Proscala-Patch:` trailer,
at most one per name — and rewrites the stream's patch files and `series` to
match, in commit order. Before writing anything it proves the result: applying
the new series onto `UPSTREAM_SHA` must reproduce the tree's content exactly. It
also refuses to export a tree that is out of date — one still holding a patch
exactly as it was applied whose file has changed since (for instance because
another stream's export changed a shared file) — since that would silently undo
the change; rebuild such a tree with `--reset`. A patch in `series` with no
commit in the tree is an error unless removed on purpose with `--drop <patch>`,
so a patch can never vanish by accident. Export commits nothing: review
`git diff` on `main` and commit it.

### Everyday workflow

1. **Develop.** `bin/proscala-tree <stream>` and work in `worktrees/<stream>`,
   committing as you go. Unfinished work can be pushed to any branch as a backup.
2. **Shape it into a patch.** Squash the work into one commit (`git rebase -i`)
   whose message explains the change and ends with `Proscala-Patch: <patch>`. Put
   it where it belongs in the series: after anything it genuinely depends on;
   otherwise anywhere — the end is simplest. To change an existing patch, fold the
   change into that patch's commit (`git commit --fixup=<commit>` then
   `git rebase -i --autosquash`).
3. **Export, document, check.** `bin/proscala-export <stream>`; write
   `doc/<patch>/<patch>.md` (and a repro); add the patch's row to `doc/README.md`;
   run `bin/proscala-check`; then commit the patch, its doc and its row together
   on `main`.
4. **Other streams.** To carry the patch to another stream too, apply it in that
   stream's tree (`git am -3 patches/<stream>/<patch>.patch`, or cherry-pick from
   the first tree), fix it up if needed, and export there. If the result applies
   unchanged to both, move it to `patches/common/`.
5. **Release.** `bin/proscala-release <stream>` (see *Releases*).

### Keeping up with upstream

We track `scala/scala3` closely and move each stream onto a newer upstream commit
frequently, so patches never drift far from the code they modify. For a stream:

    git fetch upstream                          # a remote for scala/scala3
    # 1. set UPSTREAM_SHA in mk/<stream>.mk to the new commit (e.g. upstream/main's head)
    # 2. move the existing tree onto it, patch by patch:
    cd worktrees/<stream>
    git rebase --onto <new-sha> "$(cat "$(git rev-parse --absolute-git-dir)/proscala-base")"
    #    fix any conflicts as usual (rerere remembers resolutions), then
    cd ../.. && bin/proscala-export <stream>
    # 3. bin/proscala-check, build and test the tree, commit mk/ and patches/ on main

Rebasing the tree, rather than re-applying the files, gives git true merge bases
for every patch, so most context drift resolves itself and conflicts are ordinary
rebase conflicts. A patch that upstream has made redundant becomes an empty
commit; drop it and export with `--drop <patch>`. Where a shared patch no longer
applies to one stream, export forks it. The bump is one commit on `main`; nothing
else moves, and nothing is force-pushed.

Alternatively, `bin/proscala-tree <stream> --reset` builds a fresh tree on the
new `UPSTREAM_SHA` by applying the files; a patch that does not apply stops it
mid-`git am`. Resolve it (`git am --show-current-patch=diff` shows what the
patch wanted), `git add` and `git am --continue`, then
`bin/proscala-tree <stream> --continue` to apply the rest. `--3way` lets `git am`
try a three-way merge first, which needs the old upstream history locally.

### Changing the build

The build lives only on `main` and is overlaid into a tree when it is made, so a
build change (the `Makefile`, `mk/<stream>.mk`, vendored sources) is a **single
commit on `main`**. Rebuild a tree's overlay to pick it up
(`bin/proscala-overlay <stream>` from inside the tree, or
`bin/proscala-tree <stream> --reset`).

### Releases

    bin/proscala-release 3.10 --dry-run    # check, and say what it would do
    bin/proscala-release 3.10              # tag HEAD and push the tag

A release is a **tag on `main`**. `bin/proscala-release <stream>` refuses unless
`HEAD` is `origin/main`, nothing tracked is uncommitted and `bin/proscala-check`
passes; it then computes the version, tags `HEAD` with it and pushes the tag.
Pushing the tag runs `.github/workflows/release.yml`, which:

0. **Checks the four publishing secrets and imports the signing key**, before
   anything irreversible happens — see *Publishing to Maven Central* below.
1. **Works out the stream** from the tag: the stream whose `mk/<stream>.mk`
   `VERSION` base the tag carries.
2. **Builds the tree** with `bin/proscala-tree` — the stream's series at the
   tagged commit, on its `UPSTREAM_SHA` — and the distribution in it, cleanly
   (`make … tarball release-jars`).
3. **Creates a GitHub release** for the tag, attaching
   `proscala-<version>.tar.gz` — a top-level `lib/` of the jars we build plus the
   Scala.js / scala-wasm runtime; third-party dependencies are not published —
   together with each published jar under its Maven name
   (`<artifactId>-<version>.jar`), so the release assets and the Central artefacts
   match byte for byte. The notes record the upstream commit and the source
   tree's hash, so the release's source can be regenerated exactly from the tag.
4. **Publishes the same jars to Maven Central** (`make … publish`), under
   `dev.propensive`, at the same version.

The version is `<upstream-base>-p<n>`. The base is the stream's `mk/<stream>.mk`
`VERSION` with the `-propensive` suffix stripped; `<n>` is one greater than the
highest existing `-p` tag of the stream (the counter runs across upstream bases,
so `3.10.0-dev-p15` is followed by `3.10.1-dev-p16`). A stream that tracks a
non-final upstream carries a `-dev` marker in its `VERSION`, so it releases as
`<base>-dev-p<n>`.

Run by hand from the Actions tab (`workflow_dispatch`, choosing a stream), the
same workflow is a dry run: it builds the stream's next version from the chosen
ref and stops before releasing or publishing anything. Only a tag releases, so
editing `release.yml` never cuts a release. A release that lacks its jars — one
cut before the workflow attached them, or whose upload failed after the tag was
made — is completed with `bin/proscala-attach-jars <tag>`, which takes them from
Central, verifies each against Central's SHA-1 and uploads them beside the
tarball.

### Publishing to Maven Central

Every release also goes to Maven Central, from the same trigger. The machinery
is `mk/publish.mk` on `main` (overlaid with the rest of the build), so it is a
**single commit on `main`** like any other build change, invoked by the last
step of `release.yml`.

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
from `library-proscala/src` in the tree (added by patches), built into their own jar so
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
| `3.9`  | `scala/scala3 lts-3.9`       | `3.9.1-dev-p<n>`    |
| `3.10` | `scala/scala3 main`          | `3.10.1-dev-p<n>`   |


The GitHub token needs `contents: write` (declared in the workflow). Two
workflows run on the fork, both from `main`: `Release`
(`.github/workflows/release.yml`, on a release tag or by hand as a dry run) and
`Check` (`.github/workflows/check.yml`, on pushes and pull requests to `main`,
running `bin/proscala-check`). The scala/scala3 CI workflows that the retired
code branches inherited were disabled at the repository level; no branch carries
them now, and a generated tree's `.github/` is never pushed.

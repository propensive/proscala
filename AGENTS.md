# AGENTS.md

This file documents how the Proscala repository is organised — its layout,
patch rules, tooling and release process.

Everything lives on one branch, `main`. The Scala source is not stored here: a
source tree is generated from any upstream `scala/scala3` commit plus this
repository's patches, into a worktree under `worktrees/`. That tree is pure
upstream source plus the patches, so it carries *upstream Scala 3's* own
`AGENTS.md` — a different, unrelated file about building `dotc` with sbt, which
knows nothing of patches or this fork's layout. If you are working in a
generated tree, the `AGENTS.md` next to you is not this one: read this file from
`main`.

**Important**: all AI-assisted contributions, including code, PR/issue descriptions, comments, and code reviews, must comply with the [LLM usage policy](LLM_POLICY.md) — state LLM usage clearly in descriptions, commit messages, etc.

## Project Overview

Proscala is the Propensive fork of the Scala 3 compiler (`dotc`), standard
library and language spec. It maintains a small set of patches on top of
upstream `scala/scala3`. We care about maintainability. "The tests pass" is not
enough to justify that a change is good.

The patches can be applied to **any** `scala/scala3` commit from the 3.9 era on —
a release, a release candidate, a nightly, the head of a branch. Each patch is kept in as many **versions** as upstream's
changes have made necessary, and records **where it applies**; the tools pick, for
any target, the right patches in the right versions, mechanically. That makes it
possible to build the fork on the exact upstream a bug report names, to bisect
upstream for the commit that makes a patch unnecessary, and to try a nightly
before moving a release line onto it.

Proscala has **its own version number**, independent of the Scala it patches
(see *Proscala version numbers*), and each release is published for every Scala
release from 3.9.0 on and for a snapshot of every upstream branch developing an
unreleased version (`main`, `lts-3.9`, `release-3.10.1`, …).

`main` holds the patches, the documentation, the repository-wide files **and the
build** (the Makefile, per-stream config, vendored Scala.js sources and helper
scripts). Nothing is ever force-pushed: a new or changed patch, a new upstream to
support and a release are each an ordinary commit (or tag) on `main`.

## Repository layout

- **`patches/series`** — every patch, one name per line, **in the one order
  patches are applied in**, everywhere. The first is always `zflags`, the stream
  base (below).
- **`patches/<patch>/meta`** — where the patch applies, and its versions (below).
- **`patches/<patch>/<anchor>.patch`** — one version of the patch, named after
  the first 12 hex digits of the upstream commit it was made on.
- **`mk/<stream>.mk`** — a **stream**: a named upstream commit we develop
  against, with its hand-tested build config. `UPSTREAM_SHA` is the `scala/scala3` commit
  and `UPSTREAM_REF` the branch it is taken from.
  The streams are `3.9` (on `lts-3.9`) and `3.10` (on `main`). A stream carries
  no patch list of its own: it carries whatever the patches' bounds say applies
  at its commit.
- **`worktrees/<target>`** — git-ignored; generated source trees, made by
  `bin/proscala-tree`. Each is a git worktree of this repository, detached at an
  upstream commit, with one commit per patch on top.
- **`doc/`** — per-patch documentation (below); **`bin/`** — the tooling;
  **`mk/scalajs-ir/`**, **`library-js-aux/`**,
  **`project/ScalaLibraryFilesToCopy.scala`** — build inputs overlaid into a tree.

Which patches apply to a target is decided by **ancestry** between upstream
commits, so the tools need upstream history: from `PROSCALA_SINCE` (2026-05-01,
set in `bin/proscala-lib.sh`) on, the supported window, inside which every anchor
and bound must lie. They fetch what is missing on demand, from a remote named
`upstream` if you have one, else straight from GitHub. A full clone of this
repository (which already holds most of that history) is best, and the workflows
check out full history. In a shallow clone the tools fetch `PROSCALA_DEPTH`
(5000) commits behind each upstream commit they need, and **refuse** to choose
patches if that history stops short of the window, rather than silently
answering ancestry questions wrongly. Work in progress may be pushed to any
branch for safe keeping, but nothing depends on such branches.

The repository used to hold each patch as a branch per stream
(`feature/<stream>/<patch>`, merged into `trunk/<stream>`, published through
`release/<stream>`), and then as one file per stream. The branches were retired
in October 2026; every one of them is kept, unchanged, as a tag `archive/<branch>`.

### Versions

A patch's `meta` lists its versions:

    variant 403f2f663af8.patch 1 403f2f663af8ad947e36a8f80f9680a9b71f7cf2 0bc121c5fd74a0340dc56e0739ebab40de3333a2

— the file, its **revision**, and its **anchors**: the upstream commits it is
known to apply to, plainly, after the patches before it. Different versions of a
patch exist because upstream changed the code around it; they make the same
change, adapted. `bin/proscala-check` proves every version at every anchor.

A version file is `git format-patch` output for **exactly one commit**: its
author, date, message and diff. The message ends with a trailer naming the patch,

    Proscala-Patch: aliascap

which is how `bin/proscala-export` maps a tree's commits back to patches. Since
`git am` cuts a message at a line consisting of `---`, a patch's message must not
contain one. Version files are written only by the tools, with every git setting
that would change their bytes pinned, so the same commit always produces the same
file. They are meant to be read: review a change to a patch as the diff of its
files.

**Revisions** keep a fix to a patch from being lost in its older versions. When
the patch itself changes — a bug fixed in it, a feature added — its new version
gets the next revision, and `bin/proscala-export --revise` brings every older
version up to it by a three-way merge where it can. A version it cannot update
stays usable but is reported as **behind** by `bin/proscala-check`, because it
still carries the old change; it is preferred only where no current version
applies.

### Bounds: where a patch applies

A patch applies to every target unless its `meta` says otherwise, with lines
of three kinds. Each names an upstream commit and applies to that commit and
everything descended from it; a patch may have several of each, one per line of
history (a fix landing on `main` and, separately, as a backport on a release
branch):

| Line | Meaning |
| ---- | ------- |
| `needed-from <sha>`   | only on descendants of `<sha>`: upstream introduced the problem there |
| `obsolete-from <sha>` | not on descendants of `<sha>`: upstream fixed it there |
| `absent-from <sha>`   | not on descendants of `<sha>`: deliberately not carried on that line |

Each line ends with a `#` comment giving the reason. Bounds cannot be worked out
mechanically — a patch failing to apply looks the same whether the code it fixes
does not exist yet, was fixed upstream, or merely changed — so they are written
by hand, from what is known about the problem; where the exact commit is not
known, the comment says so. For example, `nullreceiver` is `obsolete-from` both
upstream's fix on `main` and its backport to `release-3.10.0`.

### Choosing patches for a target

For a target commit, every patch in `patches/series` whose bounds include it is
applied, in order. For each, the versions are tried best first — highest
revision, then those anchored at an ancestor of the target, then the nearest
anchor (fewest commits between) — and the first that applies plainly is used.
If none does, the patch is **missing** at that target: `bin/proscala-tree`
refuses to build it (unless told `--allow-missing`), and `bin/proscala-coverage`
lists it as a gap to fill. A version that only applies by a three-way merge is
used only when asked (`--3way`), and `bin/proscala-fill` records such merges as
new versions once their changes are confirmed identical.

### Patch rules

- Every patch is a pure-source change on the stream base — just its own change,
  with **no build files** (the build lives on `main` and is overlaid at build
  time). A bare id like `aliascap` means exactly that change.
- **`zflags` is the stream base, not a patch**: it adds the `-Z` setting and the
  registry of names behind which the fork's opt-in behaviours are enabled
  (`config.Proscala`; see `doc/zflags/zflags.md`). It comes first in the series,
  has no row in `doc/README.md`, and is edited only to register a new gated
  patch's name.
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

### What the streams carry

The bounds give the streams different patch sets:

    stream 3.9    36 patches   carries castbox, depset, splicealias, samstateful, staleread, virtualdir
    stream 3.10   34 patches   adds anonspec, anykindcap, boolunapply, integratemap, modulepath, prunecomplete, unioncaps; drops those six, and nullreceiver, permitlazy and rootclassify (fixed upstream); macroalias applies to 3.10.0 only

(The counts exclude `zflags`.)

### Keeping the documentation honest

The same fact is often stated in several places — the patches a stream carries
appear in the `Streams` column of `doc/README.md`; its upstream branch appears
in `mk/<stream>.mk`, `README.md` and in this file. Rather
than trying to remember every copy, **each fact has one source of truth and the
copies are checked against it**:

| Fact | Source of truth |
| ---- | --------------- |
| the patches, in order | `patches/series` |
| where a patch applies, and its versions | `patches/<patch>/meta` |
| which patches a stream carries | the bounds, at the stream's `UPSTREAM_SHA` |
| which `scala/scala3` commit a stream is built on | `UPSTREAM_SHA` in `mk/<stream>.mk` |
| which `scala/scala3` branch that commit is from | `UPSTREAM_REF` in `mk/<stream>.mk` |
| what a release is built for | the release tag's annotation (from `bin/proscala-release`) |
| whether a patch has a reproduction | the filesystem, `doc/<patch>/repro*/` |
| which `-Z` name enables a patch | `config.Proscala`, as each stream builds it |

    bin/proscala-check           # exit 1 and list every divergence
    bin/proscala-check -v        # also show what passed
    bin/proscala-check --quick   # skip proving every version at every anchor

It checks that `patches/series` and the patch directories agree, that every
`meta` line is well-formed and names a commit inside the history window, that
every version file holds one commit with the right trailer and is named in its
`meta`, and that no two versions are identical; that every stream gets every
patch it carries, plainly; and — the slow part — that every version applies
plainly at every one of its anchors, after the patches chosen before it (in a
throwaway index, with no worktree). It notes, without failing, versions that are
behind their patch's latest revision. It checks the feature table against what
the streams carry, the `Repro` column against the reproductions that actually
exist (and that each has its executable `test.sh`), the `Flag` column against the registry each stream builds, the stream
tables in `README.md` and this file against `mk/<stream>.mk`, the patch counts
quoted above, that no feature doc hard-codes a stream when its patch spans
several, and that every relative link resolves. Run it after touching any of
them; `.github/workflows/check.yml` runs it on every push and pull request to
`main`.

It checks structure, not prose: it cannot tell you that a feature doc has stopped
describing what its patch does, or that a bound's reason is right. That still
needs reading.

### Feature documentation

Every patch has a documentation directory, `doc/<patch>/`, containing
`doc/<patch>/<patch>.md` (the feature doc) and `doc/<patch>/repro/` with a
minimal reproduction: standalone source files, a `README.md` giving the compiler
flags and what happens with and without the patch, and a `test.sh` that is the
same thing in executable form (see *Testing the patches*) — or a `FIXME.md`
while no self-contained reproduction is known. A feature rather than a fix has
one too, showing what the feature does. `doc/README.md` indexes all features.
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
`jar` and a JDK ≥ 17, and the release artefacts `zip`.

### Building any upstream: `bin/proscala-tree`

    bin/proscala-tree 3.10                  # a stream: its pinned commit and config
    bin/proscala-tree 3.10.0                # a scala/scala3 release tag
    bin/proscala-tree main                  # a branch head (also lts-3.9, release-3.10.1, …)
    bin/proscala-tree 3.10.2-RC1-bin-20261010-bb20dff-NIGHTLY   # a nightly, by its version
    bin/proscala-tree 88be2f56a1            # any commit
    bin/proscala-tree 3.10.0 --plan         # just say which versions would apply
    cd worktrees/3.10.0 && make             # build every module jar

`bin/proscala-tree <target> [<dir>]` resolves the target to a `scala/scala3`
commit, chooses the patches for it (see *Choosing patches for a target*), creates
a git worktree at `<dir>` (default `worktrees/<target>`) detached at that commit,
applies the patches with `git am` — one commit per patch, so `git log` in the
tree reads like the patch list — and overlays the build from this checkout's
`HEAD` (`bin/proscala-overlay` copies the Makefile, the build configs, the
vendored Scala.js IR — the stock or scala-wasm IR, by whether the tree carries
the WASM/WIT sources — and the other build inputs in as untracked, git-excluded
files).

A stream builds with its own, hand-tested `mk/<stream>.mk`. Any other target gets
`mk/target.mk`, written by `bin/proscala-buildconf` from the tree's own sbt
build: it starts from the stream config whose module layout matches (3.10's if
the tree has the `scala3-directives-parser` module, else 3.9's) and takes
upstream's reference compiler, Scala.js version and ASM flavour (shaded
`scala-asm` or `org.ow2.asm`, for the tree, and whatever the reference
compiler's published POM depends on); everything else stays at the stream's
values. Its version is `<upstream base version>-bin-<commit>-propensive`, which
can never be published. A Scala.js version without vendored IR is added by
`bin/proscala-vendor-ir <version>` (only needed for a tree without the `wasm`
patch, which brings its own IR).

`make` then downloads the reference compiler and third-party jars from Maven
Central, compiles each module with that reference compiler, and lays out its
artefacts under the tree's `release/<name>/`, where `<name>` is the tree's
directory name:

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
`make distclean`. The build config is read from the tree's `.proscala-stream`;
override the output name with `make BRANCH=<name>`. The overlay comes from the
*committed* `HEAD` of this checkout, so commit a build change before rebuilding a
tree with it.

Other modes: `--only <patch>` applies just `zflags` and one patch, to build it in
isolation; `--3way` lets a patch with no plainly-applying version apply by a
three-way merge; `--allow-missing` builds without patches that have no version
for the target (and names them); `--reset` rebuilds an existing tree, but refuses
if the tree holds any commit whose change is in no version file (each tree
records which file it applied for each patch, so a tree that is merely out of
date is never mistaken for one holding work); `--continue` resumes after a patch
that did not apply.

### Writing patches back: `bin/proscala-export`

    bin/proscala-export 3.10                # the tree worktrees/3.10
    bin/proscala-export 3.10.0 --adapt      # a version of a patch for this upstream
    bin/proscala-export 3.10 --revise       # a change to the patch itself

`bin/proscala-export <dir or target>` reads the tree's commits above its
upstream base — each must be an ordinary commit with a `Proscala-Patch:`
trailer, at most one per name, in `patches/series` order — and records every
patch whose commit differs from the version that was applied, as a version
anchored at the base:

- a change of **context only** (the patch's own `+`/`-` lines are unchanged: the
  tree was rebased, or a three-way merge placed it) is recorded at once;
- a **new patch** is recorded at once and added to `patches/series` where the
  tree has it;
- any other change must be qualified: **`--adapt`** says this upstream needs the
  patch done differently (other versions are left alone), **`--revise`** says the
  patch itself changed (see *Revisions*).

`--obsolete <patch>` records that the tree no longer carries a patch because
upstream made it unnecessary (`obsolete-from` the base); `--remove <patch>`
deletes a patch altogether. A patch the target should carry but the tree lacks is
an error otherwise, so a patch can never vanish by accident. Before writing
anything, export proves the result: choosing patches for the base anew must
rebuild the tree exactly. It also refuses to export a tree that is out of date —
one still holding a patch exactly as it was applied whose file has changed since —
since that would silently undo the change; rebuild such a tree with `--reset`.
Export commits nothing: review `git diff` on `main` and commit it.

### Coverage: `bin/proscala-coverage` and `bin/proscala-fill`

    bin/proscala-coverage                   # streams, release tags, branch heads
    bin/proscala-coverage --3way 3.10.0     # and which gaps a merge would close
    bin/proscala-fill 3.10.0 3.10.0-RC3     # record the merges that are safe

`bin/proscala-coverage [<target>...]` chooses patches for each target (by
default the streams, every `scala/scala3` release tag from 3.9.0-RC1 on, and the
heads of `main`, `lts-3.9` and the release branches) and lists, per target, the
patches that are in range but have no version that applies: the gaps. It exits
1 if there are any. `.github/workflows/coverage.yml` runs it weekly and on
demand, and builds a few targets end to end.

`bin/proscala-fill <target>...` closes the gaps a three-way merge can: each patch
that merges cleanly at a target is recorded as a new version anchored there,
with the revision it was merged from — but only if its `+`/`-` lines are exactly
those of the version it came from, because a clean merge can still change what a
patch does when upstream edited the lines around it. Those that differ are
listed (`--accept-changed` records them too, for review); those that do not
merge at all need a person.

### Testing the patches: `bin/proscala-test`

    cd worktrees/3.10 && make && cd ../..
    bin/proscala-test worktrees/3.10                 # every patch the tree carries
    bin/proscala-test worktrees/3.10 --only aliascap -v
    bin/proscala-test worktrees/3.10 --stock 3.10.0  # do the reproductions reproduce?

`bin/proscala-test <tree>` tests a built tree's patches, against the compiler in
its `release/<name>/`. For each patch the tree carries, it runs:

- **its reproductions** — each `doc/<patch>/repro*/test.sh`, in a scratch copy of
  its directory. A spec says what must happen with the patch and, where it can be
  shown, without it:

  ```bash
  ZFLAG=-Zalias-captures            # the patch's -Z flag; omitted if always on

  with_feature() {                  # must hold for Proscala, with $ZFLAG
    compiles $ZFLAG -d . defs.scala
    compiles $ZFLAG -cp . -d . lib.scala
    compiles $ZFLAG -cp . -d . client.scala
  }

  without_feature() {               # upstream's behaviour: the bug
    compiles -d . defs.scala
    compiles -cp . -d . lib.scala
    fails_with 'is not visible from any in type raises' -cp . -d . client.scala
  }
  ```

  with the helpers `compiles`, `fails_with <regex>`, `reports <regex>` (output
  must match, success or not), `runs <regex> <classpath> <main>`, `fail` and
  `skip`, and `$DIST`, `$COMPILER_CP` and `$SCALA_VERSION` for anything else. A
  gated patch's `without_feature` is run too, on the same compiler without the
  flag, which proves the gate.
- **its own tests** — every upstream-style test the patch adds under `tests/`,
  compiled as upstream's test runner would: upstream's default options (tree
  checking included), the directory's extra ones (capture checking for
  `*-custom-args/captures`, explicit nulls for `explicit-nulls/*`, …) and the
  file's own `//> using options`; files named `*_1`, `*_2`, … compile in
  separate runs, in order. A `pos` test must compile; a `neg` test must report
  errors on exactly the lines marked `// error`.

`--stock <version>` runs every `without_feature` against upstream's published
compiler instead (fetched with `cs`), which must show the bug: it proves that a
reproduction reproduces, and, run against a newer upstream, reveals a patch that
upstream has made unnecessary. The release workflow runs `bin/proscala-test` on
every target before releasing anything, and the Coverage workflow on its builds
of upstream `main` and `lts-3.9`.

### Covering a new target

To support an upstream commit that has gaps (say a new release candidate):

1. `bin/proscala-coverage <target>` lists the gaps; `bin/proscala-fill <target>`
   closes the ones a merge can.
2. For each gap left, decide whether the patch is needed there at all. If
   upstream fixed the problem, or the problem does not exist yet on that line,
   add the bound to `patches/<patch>/meta`, with its reason.
3. Otherwise make the version: `bin/proscala-tree <target> --allow-missing`
   builds the tree without the missing patches; apply the nearest version by
   hand (`git am -3 patches/<patch>/<file>`, resolving the conflicts, or redo the
   change), commit it with the `Proscala-Patch:` trailer in its place in the
   series (`git rebase -i` to move it), and `bin/proscala-export <target> --adapt`.
4. Build the tree, run `bin/proscala-test` on it, run `bin/proscala-check`, and
   commit on `main`.

### Everyday workflow

1. **Develop.** `bin/proscala-tree <stream>` (or any target) and work in the
   tree, committing as you go. Unfinished work can be pushed to any branch as a
   backup.
2. **Shape it into a patch.** Squash the work into one commit (`git rebase -i`)
   whose message explains the change and ends with `Proscala-Patch: <patch>`. Put
   it where it belongs in the series: after anything it genuinely depends on;
   otherwise anywhere — the end is simplest. To change an existing patch, fold the
   change into that patch's commit (`git commit --fixup=<commit>` then
   `git rebase -i --autosquash`).
3. **Export, document, test, check.** `bin/proscala-export <target>` (with
   `--revise` for a change to an existing patch); give a new patch the bounds it
   needs; write `doc/<patch>/<patch>.md` and its reproduction, with `test.sh`;
   add the patch's row to `doc/README.md`; run `bin/proscala-test` on the built
   tree (and with `--stock` where upstream has a release) and
   `bin/proscala-check`; then commit the patch, its doc and its row together on
   `main`.
4. **Other upstreams.** A new patch at first has one version, so other targets
   may report it missing: run `bin/proscala-coverage`, and cover the targets that
   matter (above), at least the other stream.
5. **Release.** `bin/proscala-release <x.y.z>` (see *Proscala version numbers*
   for which number, and *Releases*).

### Keeping up with upstream

Moving a stream onto a newer upstream commit is covering a new target and then
pointing the stream at it:

    bin/proscala-coverage <new-sha>          # the gaps, if any
    bin/proscala-fill <new-sha>              # the mechanical ones
    # cover the rest as above, then set UPSTREAM_SHA in mk/<stream>.mk
    bin/proscala-check; bin/proscala-tree <stream> --reset; build and test

The old versions stay: the stream's previous commit, and every other upstream the
patches covered, still build exactly as before. Alternatively, rebase an existing
tree onto the new commit (`git rebase --onto <new-sha> <old-base>` inside it,
which gives git true merge bases for every patch) and export it; patches whose
`+`/`-` lines survive unchanged are recorded without further ado, the rest need
`--adapt`. Nothing is force-pushed.

### Changing the build

The build lives only on `main` and is overlaid into a tree when it is made, so a
build change (the `Makefile`, `mk/<stream>.mk`, vendored sources) is a **single
commit on `main`**. Rebuild a tree's overlay to pick it up
(`bin/proscala-tree <target> --reset`).

### Proscala version numbers

Proscala has its own version, independent of the Scala it patches. A Proscala
version names a **set of features** — the patches, each with the guarantee its
doc states — and each release is built for many upstreams, on each of which every
feature is *the same feature*, adapted: a different version of the patch, or no
patch at all where upstream already provides the guarantee. Versions follow
[semantic versioning](https://semver.org), with the public interface being what
users of Proscala on a given upstream can rely on beyond that upstream: the
features and their documented guarantees, the `-Z` flag names, the
`proscala-library` API, machine-readable output (`semdiag`'s XML), and which flags
change what is pickled (`doc/compatibility.md`).

| Change | Increment |
| ------ | --------- |
| a new version or bound of a feature (more upstreams covered) | patch |
| a patch dropped where upstream now meets its guarantee | patch |
| a fix making a feature meet its documented guarantee | patch |
| a new always-on crash, hang or spurious-error fix (it only turns rejected programs into accepted ones) | patch |
| a new `-Z` feature, new `proscala-library` API, an additive XML change | minor |
| a feature removed, a flag renamed, a guarantee weakened | major |
| a gated feature made always-on (code that never opted in changes) | major |
| flagged code pickling differently, so it no longer links with the previous version's | major |
| an incompatible XML change, or `proscala-library` API removed | major |

Two consequences follow. A `-Z` flag whose feature upstream has made redundant
stays registered on that upstream, accepted and doing nothing, since dropping it
would break builds that pass it (under `-Werror`, fatally); removing it is a major
change. And covering a newly released upstream, which needs new versions of
patches, is a patch release: 1.0.1 is 1.0.0's features on more Scala versions.

### Releases

    bin/proscala-release 1.0.0 --targets    # what it would be built for
    bin/proscala-release 1.0.0 --dry-run    # check everything, and say what it would do
    bin/proscala-release 1.0.0              # tag HEAD v1.0.0 and push the tag

A release is a **tag `v<x.y.z>` on `main`**, built for every `scala/scala3`
final release `3.<y>.<z>` with `y` ≥ 9, and for a **snapshot** of every upstream
branch developing a version that has not been released yet — `main`, each
`lts-3.<y>` and each `release-3.<y>.<z>`, from 3.9 on — as it is when the release
is cut. A release branch drops out once its version is tagged, and is then
covered as a release. Each build's version puts the upstream first, then `-pro-`
and the Proscala version:

| Upstream (on 2026-10-12) | Version |
| ------------------------ | ------- |
| release 3.9.0 | `3.9.0-pro-1.0.0` |
| release 3.10.0 | `3.10.0-pro-1.0.0` |
| `lts-3.9`, developing 3.9.1 | `3.9.1-0bc121c5fd74a034-pro-1.0.0` |
| `release-3.10.1`, developing 3.10.1 | `3.10.1-60c03047d6043474-pro-1.0.0` |
| `main`, developing 3.10.2 | `3.10.2-88be2f56a1103b0e-pro-1.0.0` |

A snapshot is named after the version its branch develops (upstream's
`developedVersion`) and the first 16 hex digits of the commit
(`PROSCALA_HASH_LENGTH`), which identify it with no realistic risk of a clash. The
`3.x.y` at the front is not decoration: sbt treats a `scalaVersion` as Scala 3
only if it starts with a full `3.x.y` — anything else (a bare hash, `3-…`,
`3.10-…`) makes it fetch the Scala 2 compiler, or a `scala3-library_<version>`
that does not exist — and `_` or `+` as the separator break resolution the same
way (all tested with sbt 1.11). So a project uses Proscala 1.0.0 on Scala 3.10.0
with `scalaOrganization := "dev.propensive"` and
`scalaVersion := "3.10.0-pro-1.0.0"`.

`bin/proscala-release <x.y.z>` refuses unless `HEAD` is `origin/main`, nothing
tracked is uncommitted, `bin/proscala-check` passes, the version is greater than
every earlier release, and every target gets every patch it should (no gaps:
`bin/proscala-coverage`). It writes the exact upstream commit of every target
into the tag's annotation (`target <spec> <commit> <version>` lines), so the
release builds what was checked even after `main` has moved on, then pushes the
tag. That runs `.github/workflows/release.yml`:

1. **plan** reads the targets from the tag.
2. **build**, for every target in parallel: builds the tree for the target's
   commit with `bin/proscala-tree`, and the release artefacts in it, cleanly
   (`make … tarball release-jars maven-repo`; see *What a release contains*),
   then tests the patches against it (`bin/proscala-test`). Nothing leaves the
   runner yet.
3. **publish**, only once every target has built: creates the GitHub release
   `v<x.y.z>`, with every target's tarball, jars and Maven repository, and notes
   listing each target's upstream commit and `scalaVersion` and how to use them.

So a release publishes for all its targets or for none. Run by hand from the
Actions tab (`workflow_dispatch`, giving a version), the same workflow is a dry
run: it plans and builds every target and publishes nothing. Only a tag releases,
so editing `release.yml` never cuts a release.

The streams (`mk/<stream>.mk`) no longer release: they are development pins,
with hand-tested build configs. Releases before 1.0.0 were made per stream, as
`<upstream base>-p<n>` (the last were `3.9.1-dev-p20` and `3.10.1-dev-p17`).

### What a release contains

Releases go to **GitHub Releases only**; nothing is published to Maven Central.
For each target, a release attaches three kinds of asset, built by the
release-artefact targets in `mk/publish.mk` (overlaid with the rest of the
build, so a change to them is a single commit on `main`):

    make VERSION=<v> tarball        # proscala-<v>.tar.gz: lib/ of the jars we build, plus the Scala.js runtime
    make VERSION=<v> release-jars   # each published jar, under its Maven name
    make VERSION=<v> maven-repo     # proscala-<v>-maven.zip: a Maven repository of them

The Maven repository is what makes the fork usable as a drop-in replacement:
unzip each target's into one directory, name it as a resolver, and sbt's
`scalaOrganization := "dev.propensive"` swaps the fork in wholesale. sbt also
fetches `scaladoc_3` from that organisation, which Proscala does not build, and
the compiler bridge from `org.scala-lang` regardless, so two more settings are
needed (tested with sbt 1.11):

```scala
val proscala = file("/path/to/proscala-repo")   // the unzipped proscala-<version>-maven.zip
resolvers         += "proscala" at proscala.toURI.toString
scalaOrganization := "dev.propensive"
scalaVersion      := "3.10.0-pro-1.0.0"
// sbt also wants these two, which Proscala does not provide as it expects:
excludeDependencies += "dev.propensive" % "scaladoc_3"   // no scaladoc is built
scalaCompilerBridgeBinaryJar := Some(proscala / s"dev/propensive/scala3-sbt-bridge/${scalaVersion.value}/scala3-sbt-bridge-${scalaVersion.value}.jar")
```

Fifteen artifacts are in each repository, under the group `dev.propensive`, at
the target's version (`<scala version>-pro-<x.y.z>`). Thirteen carry **the same artifact names as the mainline
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
by name, so nothing else depends on it. A WASM tree adds a sixteenth,
`scalajs-library_2.13` — see below. Every release target from Scala.js 1.22.0
on carries the `wasm` patch, so a release has sixteen for each.

Each artifact gets a POM and a sources jar, with md5/sha1 checksums. A GitHub
release can be edited or deleted, but its tag should not be reused: a version,
once released, means those bytes.

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
Our `dev.propensive` artifact is a different coordinate, so nothing is
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
remove entries from someone else's jar. So a WASM tree ships the patched
library as `dev.propensive:scalajs-library_2.13`, at the Scala version, and
consumers resolve that instead — the same substitution Soundness makes locally in
its `build.mill` `repo` task. Its POM records the provenance and the Apache-2.0
licence of the original.

A pleasant consequence: with library *and* scalalib both under `dev.propensive`,
no stock Scala.js artifact enters our graph at all, so on a WASM tree the
`<exclusion>` above is unnecessary and is not emitted.

The development streams:

| Stream | Tracks |
| ------ | --------------------------- |
| `3.9`  | `scala/scala3 lts-3.9`       |
| `3.10` | `scala/scala3 main`          |


The release workflow needs no secrets: its GitHub token has `contents: write`
(declared in the workflow). Three
workflows run on the fork, all from `main`: `Release`
(`.github/workflows/release.yml`, on a release tag or by hand as a dry run),
`Check` (`.github/workflows/check.yml`, on pushes and pull requests to `main`,
running `bin/proscala-check`) and `Coverage` (`.github/workflows/coverage.yml`,
weekly and by hand: `bin/proscala-coverage`, and builds of upstream `main` and
`lts-3.9` with the patches). The scala/scala3 CI workflows that the retired
code branches inherited were disabled at the repository level; no branch carries
them now, and a generated tree's `.github/` is never pushed.

# proscala-lib.sh — shared helpers for the bin/proscala-* tools. Sourced, not run.
#
# The repository model these helpers encode (see AGENTS.md):
#
#   mk/<s>.mk               UPSTREAM_SHA — the scala/scala3 commit stream <s> is built on
#   patches/<s>/series      the stream's patches, in application order, `zflags` first
#   patches/<s>/<p>.patch   a patch specific to stream <s>
#   patches/common/<p>.patch  a patch shared by every stream that lists <p> without
#                           its own copy (a stream copy always wins)
#
# Every patch file is `git format-patch` output for exactly one commit whose
# message ends with the trailer `Proscala-Patch: <p>`.

# shellcheck shell=bash

PROSCALA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROSCALA_PROG="${PROSCALA_PROG:-$(basename "$0")}"
PROSCALA_SCALA3_URL="${PROSCALA_SCALA3_URL:-https://github.com/scala/scala3.git}"

die()  { echo >&2 "$PROSCALA_PROG: $*"; exit 1; }
note() { echo ">> $*"; }
warn() { echo >&2 "!! $*"; }

# git, with every user setting that would change the bytes of a generated patch
# pinned, so the same commit always exports to the same file on every machine.
pgit() {
  git -c diff.noprefix=false -c diff.mnemonicPrefix=false -c diff.algorithm=myers \
      -c diff.renames=true -c diff.relative=false -c diff.suppressBlankEmpty=false \
      -c format.signOff=false -c format.coverLetter=false -c format.numbered=false \
      -c format.thread=false \
      -c format.useAutoBase=false -c core.quotePath=true -c color.ui=false "$@"
}

# streams — every stream with a series, version-sorted
streams() {
  local d
  for d in "$PROSCALA_ROOT"/patches/*/; do
    if [ -f "$d/series" ]; then basename "$d"; fi
  done | sort -V
}

# require_stream <s>
require_stream() {
  [ -n "${1:-}" ] || die "no stream given (one of: $(streams | tr '\n' ' '))"
  [ -f "$PROSCALA_ROOT/patches/$1/series" ] || die "unknown stream '$1' (no patches/$1/series)"
  [ -f "$PROSCALA_ROOT/mk/$1.mk" ] || die "stream '$1' has no mk/$1.mk"
}

# mkvar <s> <name> — a `:=` assignment from mk/<s>.mk
mkvar() { sed -nE "s/^$2[[:space:]]*:=[[:space:]]*([^[:space:]]+).*/\1/p" "$PROSCALA_ROOT/mk/$1.mk" | head -1; }

# upstream_sha <s> — the pinned scala/scala3 commit, validated
upstream_sha() {
  local sha
  sha="$(mkvar "$1" UPSTREAM_SHA)"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "mk/$1.mk: UPSTREAM_SHA must be a full 40-hex commit id (got '$sha')"
  printf '%s\n' "$sha"
}

# ensure_commit <sha> — make the commit available locally, fetching only it if needed:
# from the `upstream` remote when there is one, else straight from scala/scala3.
ensure_commit() {
  git -C "$PROSCALA_ROOT" cat-file -e "$1^{commit}" 2>/dev/null && return 0
  if git -C "$PROSCALA_ROOT" remote get-url upstream >/dev/null 2>&1; then
    git -C "$PROSCALA_ROOT" fetch --quiet --no-tags upstream "$1" 2>/dev/null || true
  fi
  git -C "$PROSCALA_ROOT" cat-file -e "$1^{commit}" 2>/dev/null && return 0
  git -C "$PROSCALA_ROOT" fetch --quiet --no-tags --depth 1 "$PROSCALA_SCALA3_URL" "$1" \
    || die "cannot fetch scala/scala3 commit $1"
}

# series <s> — the stream's patch names in order (comments and blanks dropped)
series() { sed 's/#.*//' "$PROSCALA_ROOT/patches/$1/series" | tr -d '[:blank:]' | grep -v '^$'; }

# patch_file <s> <p> — the file stream <s> applies for <p>; empty when none exists
patch_file() {
  if [ -f "$PROSCALA_ROOT/patches/$1/$2.patch" ]; then
    printf '%s\n' "$PROSCALA_ROOT/patches/$1/$2.patch"
  elif [ -f "$PROSCALA_ROOT/patches/common/$2.patch" ]; then
    printf '%s\n' "$PROSCALA_ROOT/patches/common/$2.patch"
  fi
  return 0
}

# patch_trailer <file> — the Proscala-Patch trailer of a patch file's message
patch_trailer() {
  awk '/^---$/ { exit } { print }' "$1" | sed -nE 's/^Proscala-Patch:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' | tail -1
}

# patch_commits <file> — how many commits a patch file holds
patch_commits() { grep -c '^From [0-9a-f]\{40\} ' "$1"; }

# patch_id <file|-> — the stable patch-id of a diff (ignores line numbers, whitespace
# and `index` lines), for telling whether two copies of a patch say the same thing
patch_id() { git -C "$PROSCALA_ROOT" patch-id --stable < "${1:-/dev/stdin}" | cut -d' ' -f1; }

# apply_series <s> [<p>=<file> ...] — apply stream <s>'s whole series onto its
# UPSTREAM_SHA in a throwaway index, with no worktree, optionally substituting
# files for some patches. Plain apply, never three-way: this is the definition of
# "the series applies", and it must give the same answer in a shallow CI clone.
# On success leaves the index path in APPLIED_INDEX (caller removes it) and
# returns 0; on failure prints the patch that failed and returns 1.
APPLIED_INDEX=""
apply_series() {
  local s="$1"; shift
  local -A subst=()
  local kv
  for kv in "$@"; do subst["${kv%%=*}"]="${kv#*=}"; done
  local sha idx p f err
  sha="$(upstream_sha "$s")"
  ensure_commit "$sha"
  idx="$(mktemp "${TMPDIR:-/tmp}/proscala-index.XXXXXX")"
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" git -C "$PROSCALA_ROOT" read-tree "$sha" || { rm -f "$idx"; return 1; }
  while IFS= read -r p; do
    f="${subst[$p]:-$(patch_file "$s" "$p")}"
    if [ -z "$f" ]; then
      echo "   $s: series lists '$p' but neither patches/$s/$p.patch nor patches/common/$p.patch exists"
      rm -f "$idx"; return 1
    fi
    if ! err="$(GIT_INDEX_FILE="$idx" git -C "$PROSCALA_ROOT" apply --cached "$f" 2>&1)"; then
      echo "   $s: ${f#"$PROSCALA_ROOT"/} does not apply after the patches before it:"
      printf '%s\n' "$err" | sed 's/^/      /' | head -8
      rm -f "$idx"; return 1
    fi
  done < <(series "$s")
  APPLIED_INDEX="$idx"
  return 0
}

# stream_file <dir> — the stream a generated worktree was built for
stream_file() { [ -f "$1/.proscala-stream" ] && tr -d '[:space:]' < "$1/.proscala-stream"; }

# in_progress <dir> — non-empty when the worktree is mid-am/rebase/merge/cherry-pick
in_progress() {
  local gd
  gd="$(git -C "$1" rev-parse --absolute-git-dir)"
  for x in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    [ -e "$gd/$x" ] && { echo "$x"; return 0; }
  done
  return 0
}

# commit_patch_name <dir> <commit> — the Proscala-Patch trailer of a commit
commit_patch_name() {
  git -C "$1" log -1 --format='%(trailers:key=Proscala-Patch,valueonly,separator=%x0a)' "$2" \
    | sed 's/[[:space:]]//g' | { grep -v '^$' || true; } | tail -1
}

# export_commit <dir> <commit> — the canonical patch file for one commit, on stdout
export_commit() {
  pgit -C "$1" format-patch -1 --stdout -k -N -M --binary --full-index --zero-commit \
       --no-signature --no-color --no-ext-diff --diff-algorithm=myers \
       --src-prefix=a/ --dst-prefix=b/ "$2"
}

# tree_base <dir> <s> — the upstream commit a generated tree's patch commits sit
# on: UPSTREAM_SHA when the tree contains it (the normal case, and after a bump
# once the tree has been rebased), else the base recorded when the tree was made.
tree_base() {
  local sha rec
  sha="$(upstream_sha "$2")"
  if git -C "$1" merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
    printf '%s\n' "$sha"; return
  fi
  rec="$(git -C "$1" rev-parse --absolute-git-dir)/proscala-base"
  if [ -f "$rec" ] && git -C "$1" merge-base --is-ancestor "$(cat "$rec")" HEAD 2>/dev/null; then
    cat "$rec"; return
  fi
  die "$1 is not built on mk/$2.mk's UPSTREAM_SHA ($sha), nor on the commit it was created from"
}

# tree_commits <dir> <s> — the tree's patch commits, oldest first
tree_commits() {
  local base
  base="$(tree_base "$1" "$2")" || exit 1
  git -C "$1" rev-list --reverse "$base..HEAD"
}

# in_series <s> <p> — whether stream <s> lists <p>. (Not `| grep -q`: under
# pipefail an early-exiting grep can fail the pipe with SIGPIPE.)
in_series() { [ "$(series "$1" | grep -cx -- "$2")" -gt 0 ]; }

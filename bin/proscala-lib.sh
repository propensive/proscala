# proscala-lib.sh — shared helpers for the bin/proscala-* tools. Sourced, not run.
#
# The repository model these helpers encode (see AGENTS.md):
#
#   patches/series            every patch, in the one order they are applied in,
#                             `zflags` (the stream base) first
#   patches/<p>/meta          when <p> applies, and which versions of it exist:
#       needed-from   <sha>   only on descendants of <sha> (upstream introduced the need)
#       obsolete-from <sha>   not on descendants of <sha> (upstream fixed it)
#       absent-from   <sha>   not on descendants of <sha> (deliberately not carried there)
#       variant <file> <revision> <anchor-sha> [<anchor-sha>...]
#   patches/<p>/<file>.patch  one version: `git format-patch` output for exactly one
#                             commit, whose message ends `Proscala-Patch: <p>`, known
#                             to apply plainly at each of its anchors
#
# Upstream targets (any scala/scala3 commit: a stream's pin, a release tag, a
# nightly, a branch head) get, for each patch in range, the first version that
# applies: highest revision first, then versions anchored at an ancestor of the
# target, then the nearest anchor.

# shellcheck shell=bash

PROSCALA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROSCALA_PROG="${PROSCALA_PROG:-$(basename "$0")}"
PROSCALA_SCALA3_URL="${PROSCALA_SCALA3_URL:-https://github.com/scala/scala3.git}"
# The supported window of upstream history: every anchor and bound must be newer.
PROSCALA_SINCE="${PROSCALA_SINCE:-2026-05-01}"
# How many commits of history a shallow clone fetches behind each upstream commit
# it needs: enough to reach back past PROSCALA_SINCE (about 1000 in October 2026).
# Choosing patches tests ancestry, which a shallow boundary would silently falsify,
# so the tools refuse to choose when an anchor sits on one (see check_history).
PROSCALA_DEPTH="${PROSCALA_DEPTH:-5000}"
P="$PROSCALA_ROOT/patches"

die()  { echo >&2 "$PROSCALA_PROG: $*"; exit 1; }
note() { echo ">> $*"; }
warn() { echo >&2 "!! $*"; }
g()    { git -C "$PROSCALA_ROOT" "$@"; }

# git, with every user setting that would change the bytes of a generated patch
# pinned, so the same commit always exports to the same file on every machine.
pgit() {
  git -c diff.noprefix=false -c diff.mnemonicPrefix=false -c diff.algorithm=myers \
      -c diff.renames=true -c diff.relative=false -c diff.suppressBlankEmpty=false \
      -c format.signOff=false -c format.coverLetter=false -c format.numbered=false \
      -c format.thread=false \
      -c format.useAutoBase=false -c core.quotePath=true -c color.ui=false "$@"
}

# --- streams -------------------------------------------------------------------
# A stream is a named, pinned target that is released: mk/<s>.mk with UPSTREAM_SHA.

mkvar() { sed -nE "s/^$2[[:space:]]*:=[[:space:]]*([^[:space:]]+).*/\1/p" "$PROSCALA_ROOT/mk/$1.mk" 2>/dev/null | head -1; }

streams() {
  local f s
  for f in "$PROSCALA_ROOT"/mk/*.mk; do
    s="$(basename "$f" .mk)"
    if [ -n "$(mkvar "$s" UPSTREAM_SHA)" ]; then echo "$s"; fi
  done | sort -V
}

is_stream() { [ -n "${1:-}" ] && [ -f "$PROSCALA_ROOT/mk/$1.mk" ] && [ -n "$(mkvar "$1" UPSTREAM_SHA)" ]; }

require_stream() {
  is_stream "${1:-}" || die "unknown stream '${1:-}' (one of: $(streams | tr '\n' ' '))"
}

upstream_sha() {
  local sha
  sha="$(mkvar "$1" UPSTREAM_SHA)"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "mk/$1.mk: UPSTREAM_SHA must be a full 40-hex commit id (got '$sha')"
  printf '%s\n' "$sha"
}

# --- upstream history ------------------------------------------------------------

have_commit() { g cat-file -e "$1^{commit}" 2>/dev/null; }

# fetch_upstream <ref-or-sha>... — fetch from the `upstream` remote if there is one,
# else straight from scala/scala3; in a shallow clone, PROSCALA_DEPTH commits deep.
# (Not --shallow-since: commits merged with old committer dates cut such a fetch
# short, well inside the window.)
fetch_upstream() {
  local src=("$PROSCALA_SCALA3_URL") depth=()
  if g remote get-url upstream >/dev/null 2>&1; then src=(upstream); fi
  if [ "$(g rev-parse --is-shallow-repository)" = true ]; then depth=(--depth="$PROSCALA_DEPTH"); fi
  g fetch --quiet --no-tags ${depth[@]+"${depth[@]}"} "${src[@]}" "$@"
}

# ensure_commits <sha>... — make every commit (and its history inside the window) present
ensure_commits() {
  local missing=() c
  for c in "$@"; do have_commit "$c" || missing+=("$c"); done
  [ "${#missing[@]}" -eq 0 ] && return 0
  fetch_upstream "${missing[@]}" || die "cannot fetch scala/scala3 commit(s) ${missing[*]}"
  for c in "${missing[@]}"; do have_commit "$c" || die "scala/scala3 commit $c is still missing after fetching"; done
}

# ls_upstream <ref> — the commit a scala/scala3 tag or branch names, or nothing
ls_upstream() {
  local out
  out="$(git ls-remote "$PROSCALA_SCALA3_URL" "refs/tags/$1" "refs/tags/$1^{}" "refs/heads/$1" 2>/dev/null || true)"
  awk -v r="refs/tags/$1^{}" '$2 == r { print $1; exit }' <<<"$out" | grep . && return 0
  awk -v r="refs/tags/$1" '$2 == r { print $1; exit }' <<<"$out" | grep . && return 0
  awk -v r="refs/heads/$1" '$2 == r { print $1; exit }' <<<"$out"
  return 0
}

# resolve_target <spec> — a full commit id for: a stream name (its pin), a
# 40-hex id, an abbreviated id, a nightly version (…-bin-<date>-<sha>-NIGHTLY),
# or a scala/scala3 tag or branch (3.10.0, 3.9.0-RC3, main, lts-3.9, release-3.10.1).
resolve_target() {
  local spec="$1" sha="" abbrev=""
  if is_stream "$spec"; then sha="$(upstream_sha "$spec")"; ensure_commits "$sha"; echo "$sha"; return; fi
  if [[ "$spec" =~ ^[0-9a-f]{40}$ ]]; then ensure_commits "$spec"; echo "$spec"; return; fi
  if [[ "$spec" =~ -bin-[0-9]{8}-([0-9a-f]{7,})-NIGHTLY$ ]]; then abbrev="${BASH_REMATCH[1]}"
  elif [[ "$spec" =~ ^[0-9a-f]{7,39}$ ]]; then abbrev="$spec"; fi
  if [ -z "$abbrev" ]; then
    sha="$(ls_upstream "$spec")"
    [ -n "$sha" ] || die "'$spec' is not a stream, a commit, a nightly version, or a scala/scala3 tag or branch"
    ensure_commits "$sha"
    echo "$sha"; return
  fi
  if ! sha="$(g rev-parse --verify --quiet "$abbrev^{commit}")"; then
    # an abbreviation cannot be fetched by itself: fetch the lines it could be on
    fetch_upstream main lts-3.9 2>/dev/null || true
    sha="$(g rev-parse --verify --quiet "$abbrev^{commit}")" \
      || die "no scala/scala3 commit $abbrev on main or lts-3.9 since $PROSCALA_SINCE; give the full id"
  fi
  echo "$sha"
}

# check_history <commit>... — in a shallow clone, refuse if any of these commits
# lies on a shallow boundary, where an ancestry test could not see past it
check_history() {
  local sh c
  sh="$(g rev-parse --git-path shallow)"
  case "$sh" in /*) ;; *) sh="$PROSCALA_ROOT/$sh" ;; esac
  [ -f "$sh" ] || return 0
  for c in "$@"; do
    if [ "$(grep -cx "$c" "$sh")" -gt 0 ]; then
      die "upstream commit $c is at the edge of this shallow clone's history, so which patches apply cannot be decided; fetch deeper (PROSCALA_DEPTH, now $PROSCALA_DEPTH) or use a full clone"
    fi
  done
  # and the first commit's history must reach back past the window's start
  local b
  while read -r b; do
    if [ "$(g log -1 --format=%cs "$b" 2>/dev/null)" \> "$PROSCALA_SINCE" ] && g merge-base --is-ancestor "$b" "$1" 2>/dev/null; then
      die "this shallow clone's history of $1 stops at $b, inside the supported window (from $PROSCALA_SINCE); fetch deeper (PROSCALA_DEPTH, now $PROSCALA_DEPTH) or use a full clone"
    fi
  done < "$sh"
  return 0
}

# --- ancestry, cached ------------------------------------------------------------
declare -gA _ANC=() _DIST=()
# is_anc <a> <t> — a is t or an ancestor of it
is_anc() {
  local k="$1 $2"
  if [ -z "${_ANC[$k]:-}" ]; then
    if [ "$1" = "$2" ] || g merge-base --is-ancestor "$1" "$2" 2>/dev/null; then _ANC[$k]=1; else _ANC[$k]=0; fi
  fi
  [ "${_ANC[$k]}" = 1 ]
}
# dist <a> <t> — commits in a...t (both sides): how far apart they are
dist() {
  local k="$1 $2"
  if [ -z "${_DIST[$k]:-}" ]; then
    _DIST[$k]="$(g rev-list --count "$1...$2" 2>/dev/null || echo 999999)"
  fi
  echo "${_DIST[$k]}"
}

# --- the patches -------------------------------------------------------------------

series() { sed 's/#.*//' "${PROSCALA_SERIES:-$P/series}" | tr -d '[:blank:]' | grep -v '^$' || true; }
in_series() { [ "$(series | grep -cx -- "$1")" -gt 0 ]; }

meta() { sed 's/#.*//' "$P/$1/meta" 2>/dev/null | awk 'NF' || true; }
# bounds <p> — "<kind> <sha>" lines
bounds() { meta "$1" | awk '$1 ~ /^(needed|obsolete|absent)-from$/ { print $1, $2 }'; }
# variants <p> — "<file> <revision> <anchor>..." lines
variants() { meta "$1" | awk '$1 == "variant" { $1 = ""; sub(/^ /, ""); print }'; }
max_revision() { variants "$1" | awk 'BEGIN { m = 0 } $2 > m { m = $2 } END { print m }'; }
# every commit named in any meta file
all_anchors() {
  local p
  for p in $(series); do meta "$p" | awk '$1 ~ /-from$/ { print $2 } $1 == "variant" { for (i = 4; i <= NF; i++) print $i }'; done | sort -u
}

# in_range <p> <t> — prints "in", or "<kind> <sha>" for the bound that excludes it
in_range() {
  local kind sha needed=0 met=0 first=""
  while read -r kind sha; do
    case "$kind" in
      needed-from) needed=1; [ -n "$first" ] || first="$sha"; if is_anc "$sha" "$2"; then met=1; fi ;;
      *)           if is_anc "$sha" "$2"; then echo "$kind $sha"; return 0; fi ;;
    esac
  done < <(bounds "$1")
  if [ "$needed" = 1 ] && [ "$met" = 0 ]; then echo "needed-from $first"; return 0; fi
  echo in
}

# candidates <p> <t> — the patch's version files, best first
candidates() {
  local file rev anchors a best key
  while read -r file rev anchors; do
    best=""
    for a in $anchors; do
      if is_anc "$a" "$2"; then key="0 $(dist "$a" "$2")"; else key="1 $(dist "$a" "$2")"; fi
      if [ -z "$best" ] || [ "$(printf '%s\n%s\n' "$key" "$best" | sort -k1,1n -k2,2n | head -1)" = "$key" ]; then best="$key"; fi
    done
    echo "$((100000 - rev)) $best $P/$1/$file"
  done < <(variants "$1") | sort -k1,1n -k2,2n -k3,3n | awk '{ print $4 }'
}

# select_plan <target> <planfile> [<p>=<file>...]
# Apply every in-range patch onto <target> in a throwaway index, choosing each
# patch's version as above. Writes "<p>\t<status>\t<file>\t<detail>" lines to
# <planfile>, with status one of:
#   plain     a version applied as it is
#   3way      no version applied plainly, but one did with a three-way merge
#             (only with SELECT_3WAY=1; needs the patch's preimage blobs)
#   out       the patch's bounds exclude the target (detail: the bound)
#   missing   in range, but no version applies
#   skipped   not asked for (SELECT_ONLY)
# Overrides force a file for a patch. Leaves the index in SELECT_INDEX (the caller
# removes it); SELECT_PRE[<p>] / SELECT_POST[<p>] are the trees before and after it.
SELECT_INDEX=""
declare -gA SELECT_PRE=() SELECT_POST=()
select_plan() {
  local t="$1" plan="$2"; shift 2
  local -A force=()
  local kv p f r ok bak files
  for kv in "$@"; do force["${kv%%=*}"]="${kv#*=}"; done
  SELECT_PRE=() SELECT_POST=()
  SELECT_INDEX="$(mktemp "${TMPDIR:-/tmp}/proscala-index.XXXXXX")"
  bak="$SELECT_INDEX.bak"
  : > "$SELECT_INDEX"
  GIT_INDEX_FILE="$SELECT_INDEX" g read-tree "$t"
  if [ "$(g rev-parse --is-shallow-repository)" = true ]; then
    ensure_commits $(all_anchors)
    check_history "$t" $(all_anchors)
  fi
  : > "$plan"
  while IFS= read -r p; do
    if [ -n "${SELECT_ONLY:-}" ] && [ "$p" != zflags ] && [ "$p" != "$SELECT_ONLY" ]; then
      printf '%s\tskipped\t-\t-\n' "$p" >> "$plan"; continue
    fi
    r="$(in_range "$p" "$t")"
    if [ "$r" != in ]; then printf '%s\tout\t-\t%s\n' "$p" "$r" >> "$plan"; continue; fi
    if [ "${SELECT_TREES:-0}" = 1 ]; then SELECT_PRE[$p]="$(GIT_INDEX_FILE="$SELECT_INDEX" g write-tree)"; fi
    ok=""
    if [ -n "${force[$p]:-}" ]; then files="${force[$p]}"; else files="$(candidates "$p" "$t")"; fi
    for f in $files; do
      if GIT_INDEX_FILE="$SELECT_INDEX" g apply --cached "$f" 2>/dev/null; then ok="plain $f"; break; fi
    done
    if [ -z "$ok" ] && [ "${SELECT_3WAY:-0}" = 1 ]; then
      for f in $files; do
        cp "$SELECT_INDEX" "$bak"
        if GIT_INDEX_FILE="$SELECT_INDEX" g apply --cached -3 "$f" >/dev/null 2>&1; then ok="3way $f"; break; fi
        cp "$bak" "$SELECT_INDEX"
      done
    fi
    if [ -n "$ok" ]; then
      if [ "${SELECT_TREES:-0}" = 1 ]; then SELECT_POST[$p]="$(GIT_INDEX_FILE="$SELECT_INDEX" g write-tree)"; fi
      printf '%s\t%s\t%s\t-\n' "$p" "${ok%% *}" "${ok#* }" >> "$plan"
    else
      printf '%s\tmissing\t-\t%s version(s) tried\n' "$p" "$(echo $files | wc -w | tr -d ' ')" >> "$plan"
    fi
  done < <(series)
  if [ -f "$bak" ]; then rm -f "$bak"; fi
  return 0
}
plan_count() { awk -F'\t' -v s="$2" '$2 == s' "$1" | wc -l | tr -d ' '; }
plan_names() { awk -F'\t' -v s="$2" '$2 == s { print $1 }' "$1" | tr '\n' ' '; }

# --- patch files -------------------------------------------------------------------

patch_commits() { grep -c '^From [0-9a-f]\{40\} ' "$1"; }
patch_trailer() {
  awk '/^---$/ { exit } { print }' "$1" | sed -nE 's/^Proscala-Patch:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' | tail -1
}
# patch_id <file|-> — ignores line numbers, whitespace and `index` lines
patch_id() { g patch-id --stable < "${1:-/dev/stdin}" | cut -d' ' -f1; }
# payload <file|-> — what a patch changes: file headers and +/- lines, no context,
# so two versions differing only in where and around what they apply compare equal
payload() {
  awk '/^diff --git / { d = 1; print; next } d && /^(\+\+\+|---) / { next } d && /^[-+]/ { print }' "${1:-/dev/stdin}"
}
payload_id() { payload "$1" | g hash-object --stdin; }

# export_commit <dir> <commit> — the canonical patch file for one commit, on stdout
export_commit() {
  pgit -C "$1" format-patch -1 --stdout -k -N -M --binary --full-index --zero-commit \
       --no-signature --no-color --no-ext-diff --diff-algorithm=myers \
       --src-prefix=a/ --dst-prefix=b/ "$2"
}

# commit_from_trees <pre-tree> <post-tree> <source-patch> — a commit turning one
# tree into the other, with the author, date and message of <source-patch>; prints it
commit_from_trees() {
  local info msg parent name email date subject
  info="$(mktemp)"; msg="$(mktemp)"
  g mailinfo -k "$msg" /dev/null < "$3" > "$info"
  name="$(sed -n 's/^Author: //p' "$info")"; email="$(sed -n 's/^Email: //p' "$info")"
  date="$(sed -n 's/^Date: //p' "$info")"; subject="$(sed -n 's/^Subject: //p' "$info")"
  parent="$(GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" g commit-tree "$1" -m base)"
  { printf '%s\n\n' "$subject"; cat "$msg"; } \
    | GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_AUTHOR_DATE="$date" \
      GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" GIT_COMMITTER_DATE="$date" \
      g commit-tree "$2" -p "$parent" -F -
  rm -f "$info" "$msg"
}

# --- meta editing ------------------------------------------------------------------
variant_name() { echo "$(printf '%s' "$1" | cut -c1-12).patch"; }
# set_variant <p> <file> <revision> <anchor>... — add or replace the line for <file>
set_variant() {
  local p="$1" file="$2" rev="$3"; shift 3
  local m="$P/$p/meta"
  mkdir -p "$P/$p"; touch "$m"
  { awk -v f="$file" '!($1 == "variant" && $2 == f)' "$m"; echo "variant $file $rev $*"; } > "$m.tmp"
  mv "$m.tmp" "$m"
}
# drop_variant <p> <file> — forget a version and delete its file
drop_variant() {
  local p="${1:?drop_variant: no patch}" file="${2:?drop_variant: no file}"
  local m="$P/$p/meta"
  awk -v f="$file" '!($1 == "variant" && $2 == f)' "$m" > "$m.tmp" && mv "$m.tmp" "$m"
  case "$file" in *.patch) [ -f "$P/$p/$file" ] && rm -f "$P/$p/$file" ;; esac
  return 0
}
variant_line() { variants "$1" | awk -v f="$2" '$1 == f'; }
add_bound() { # add_bound <p> <kind> <sha> <reason>
  printf '%-13s %s   # %s\n' "$2" "$3" "$4" >> "$P/$1/meta"
}

# --- generated trees ---------------------------------------------------------------

gitdir_of() { git -C "$1" rev-parse --absolute-git-dir; }
tree_target() { cat "$(gitdir_of "$1")/proscala-target" 2>/dev/null || true; }
tree_profile() { if [ -f "$1/.proscala-stream" ]; then tr -d '[:space:]' < "$1/.proscala-stream"; fi; return 0; }

in_progress() {
  local gd x
  gd="$(gitdir_of "$1")"
  for x in rebase-apply rebase-merge MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
    if [ -e "$gd/$x" ]; then echo "$x"; return 0; fi
  done
  return 0
}

commit_patch_name() {
  git -C "$1" log -1 --format='%(trailers:key=Proscala-Patch,valueonly,separator=%x0a)' "$2" \
    | sed 's/[[:space:]]//g' | { grep -v '^$' || true; } | tail -1
}

# tree_base <dir> — the upstream commit beneath a tree's patches: the newest commit
# in its first-parent history without a Proscala-Patch trailer
tree_base() {
  local c
  while IFS= read -r c; do
    if [ -z "$(commit_patch_name "$1" "$c")" ]; then echo "$c"; return 0; fi
  done < <(git -C "$1" rev-list --first-parent HEAD)
  die "$1: every commit has a Proscala-Patch trailer; cannot find its upstream base"
}

# The applied-manifest: for each patch the tool applied, "<p>\t<patch-id>\t<file>".
# A commit whose patch-id still matches holds no local work; if its file has
# changed since, the tree is merely out of date.
manifest_path() { printf '%s/proscala-applied\n' "$(gitdir_of "$1")"; }
manifest_field() { # manifest_field <dir> <p> <2|3>
  local m; m="$(manifest_path "$1")"
  if [ -f "$m" ]; then awk -F'\t' -v p="$2" -v f="$3" '$1 == p { v = $f } END { if (v) print v }' "$m"; fi
  return 0
}
manifest_set() { # manifest_set <dir> <p> <id> <file>
  local m; m="$(manifest_path "$1")"
  touch "$m"
  { awk -F'\t' -v p="$2" '$1 != p' "$m"; printf '%s\t%s\t%s\n' "$2" "$3" "${4#"$PROSCALA_ROOT"/}"; } > "$m.tmp" && mv "$m.tmp" "$m"
}

# default_targets — the targets coverage is measured on: the streams, every
# scala/scala3 release tag from 3.9.0-RC1 on, and the heads of main, lts-3.9 and
# the release-3.x.y branches from 3.9 on
default_targets() {
  streams
  git ls-remote --tags --heads --refs "$PROSCALA_SCALA3_URL" 2>/dev/null | awk '{ print $2 }' | sed -E 's#refs/(tags|heads)/##' \
    | { grep -E '^(3\.(9|[1-9][0-9])\.[0-9]+(-RC[0-9]+)?|main|lts-3\.(9|[1-9][0-9])|release-3\.(9|[1-9][0-9])\.[0-9]+)$' || true; } \
    | sort -V
}

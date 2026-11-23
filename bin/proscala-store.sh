# proscala-store.sh — the patches, as an Orthant store. Sourced by proscala-lib.sh.
#
# The store (see AGENTS.md, and Orthant's own readme and spec/store.md):
#
#   .orthant/config.tel       two axes:
#       patch      a chain, `none` then every patch in the one order they are applied
#                  in, each the child of the one before it; `zflags` first
#       upstream   sourced: its values are scala/scala3 commits, and the content at a
#                  commit is that commit's tree, read from this repository
#   .orthant/data/<patch>/<commit>/_/<path>[.delta]
#                             what a patch does at a commit: hunks against the content
#                             the patch before it has there (or a whole new file),
#                             which Orthant carries onto every later commit
#
# So the content of a document at (patch, commit) is the upstream file with every
# patch up to that one applied. Nothing is stored where a patch does at a commit just
# what it did at the nearest earlier value.
#
# Orthant decides which value a commit is beneath by ancestry, which its own git
# reader answers by walking the whole of upstream's history: too slowly to use. So
# these helpers make a commit a value themselves (store_register), with git's answer,
# and every command is run in a *view*: a scratch copy of the store in which the
# commits being asked about are values. A view is thrown away, or, when something was
# checked in, written back over the store (store_save).

# shellcheck shell=bash

ORTHANT="${ORTHANT:-orthant}"
STORE="$PROSCALA_ROOT/.orthant"
STORE_PATCH_AXIS=patch
STORE_UPSTREAM_AXIS=upstream

need_orthant() {
  command -v "$ORTHANT" >/dev/null 2>&1 \
    || die "orthant is not installed (see https://github.com/propensive/orthant; or set ORTHANT)"
  [ -f "$STORE/config.tel" ] || die "there is no Orthant store at $STORE"
}

# --- reading the configuration (its written form: Orthant spec §7.5) ----------------

# store_axis <config> <axis> — "<name> <parent|-> <commit|->" for each value
store_axis() {
  awk -v want="$2" '
    function flush() { if (inval && axis == want) print vname, (vparent == "" ? "-" : vparent), (vcommit == "" ? "-" : vcommit); inval = 0 }
    /^axis$/      { flush(); axis = ""; fresh = 1; next }
    /^  value$/   { flush(); inval = 1; vname = vparent = vcommit = ""; next }
    /^  [a-z]/    { if (fresh && $1 == "name") { axis = $2; fresh = 0 } else flush(); next }
    /^    name /  { if (inval) vname = $2; next }
    /^    parent / { if (inval) vparent = $2; next }
    /^    commit / { if (inval) vcommit = $2; next }
    END           { flush() }
  ' "$1"
}

# store_patches [<config>] — the patches, in order: the chain beneath the root
store_patches() {
  store_axis "${1:-$STORE/config.tel}" "$STORE_PATCH_AXIS" | awk '
    { parent[$1] = $2; if ($2 == "-") root = $1; else { kids[$2]++; child[$2] = $1 } }
    END {
      for (v in kids) if (kids[v] > 1) { print "the patch axis forks at " v > "/dev/stderr"; exit 1 }
      for (v = child[root]; v != ""; v = child[v]) print v
    }'
}
store_root_patch() { store_axis "${1:-$STORE/config.tel}" "$STORE_PATCH_AXIS" | awk '$2 == "-" { print $1 }'; }

# store_values [<config>] — "<name> <parent|-> <commit>" for each upstream value
store_values() { store_axis "${1:-$STORE/config.tel}" "$STORE_UPSTREAM_AXIS"; }
store_value_name() { store_values "$1" | awk -v c="$2" '$3 == c { print $1 }'; }

# store_documents <home> — every document the store has a record of
store_documents() {
  [ -d "$1/.orthant/data" ] || return 0
  (cd "$1/.orthant/data" && find . -type f -path '*/_/*') | sed -E 's#^.*/_/##; s#\.delta$##' | sort -u
}
# store_patch_documents <home> <patch> — the documents a patch has a record of, anywhere
store_patch_documents() {
  [ -d "$1/.orthant/data/$2" ] || return 0
  (cd "$1/.orthant/data/$2" && find . -type f -path '*/_/*') | sed -E 's#^.*/_/##; s#\.delta$##' | sort -u
}

# --- values ----------------------------------------------------------------------

# store_register <home> <commit> — make a scala/scala3 commit a value of the upstream
# axis, beneath the nearest value which is its ancestor, and above those of that
# value's children which descend from it; prints its name. Nothing is stored at it, so
# no content changes.
store_register() {
  local home="$1" c="$2" cfg="$1/.orthant/config.tel" name vn vp vc parent="" pc="" best="" d rep=" "
  name="$(store_value_name "$cfg" "$c")"
  if [ -n "$name" ]; then echo "$name"; return 0; fi
  while read -r vn vp vc; do
    if is_anc "$vc" "$c"; then
      # the nearest ancestor: the one with the fewest commits between
      d="$(g rev-list --count "$vc..$c")"
      if [ -z "$best" ] || [ "$d" -lt "$best" ]; then best="$d"; parent="$vn"; pc="$vc"; fi
    fi
  done < <(store_values "$cfg")
  [ -n "$parent" ] || die "scala/scala3 commit $c does not descend from the root of the store's upstream axis ($(store_values "$cfg" | awk '$2 == "-" { print $3 }')): it is older than what the patches cover"
  name="${c:0:12}"
  [ -z "$(store_axis "$cfg" "$STORE_UPSTREAM_AXIS" | awk -v n="$name" '$1 == n')" ] || name="$c"
  while read -r vn vp vc; do
    if [ "$vp" = "$parent" ] && is_anc "$c" "$vc"; then rep+="$vn "; fi
  done < <(store_values "$cfg")
  awk -v ax="$STORE_UPSTREAM_AXIS" -v name="$name" -v parent="$parent" -v commit="$c" -v rep="$rep" '
    /^axis$/     { axis = ""; fresh = 1; print; next }
    /^  name /   { if (fresh) { axis = $2; fresh = 0 } print; next }
    /^  prefer / { print; if (axis == ax) { print "  value"; print "    name " name; print "    parent " parent; print "    commit " commit } next }
    /^    name / { cur = $2; print; next }
    /^    parent / { if (axis == ax && index(rep, " " cur " ")) print "    parent " name; else print; next }
    { print }
  ' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
  echo "$name"
}

# --- views -----------------------------------------------------------------------

# store_view [<commit>...] — a scratch copy of the store in which each commit is a
# value. Sets VIEW (remove it with store_drop) and VIEW_NAME[<commit>].
VIEW=""
declare -gA VIEW_NAME=()
store_view() {
  local c
  need_orthant
  VIEW="$(mktemp -d "${TMPDIR:-/tmp}/proscala-view.XXXXXX")"
  mkdir -p "$VIEW/.orthant"
  if [ -d "$STORE/data" ]; then cp -R "$STORE/data" "$VIEW/.orthant/data"; fi
  # the view is not in the repository, so it is told where its source is
  awk -v root="$PROSCALA_ROOT" '
    /^tree /         { print "tree work"; next }
    /^    repository / { next }
    /^  source$/     { print; print "    repository " root; next }
    { print }' "$STORE/config.tel" > "$VIEW/.orthant/config.tel"
  grep -q '^    repository ' "$VIEW/.orthant/config.tel" || die "the store's upstream axis has no source"
  for c in "$@"; do store_view_add "$c"; done
}
store_view_add() { VIEW_NAME[$1]="$(store_register "$VIEW" "$1")"; }
store_drop() { if [ -n "$VIEW" ] && [ -d "$VIEW" ]; then rm -rf "$VIEW"; fi; VIEW=""; }

# store_prune — forget each value of the view's upstream axis at which nothing is
# stored (a target which was only looked at), giving its children to its parent
store_prune() {
  local cfg="$VIEW/.orthant/config.tel" vn vp vc drop=" "
  while read -r vn vp vc; do
    [ "$vp" != - ] || continue
    if [ -z "$(find "$VIEW/.orthant/data" -type d -name "$vn" -print -quit 2>/dev/null)" ]; then drop+="$vn "; fi
  done < <(store_values "$cfg")
  [ "$drop" != " " ] || return 0
  store_values "$cfg" > "$cfg.values"
  awk -v ax="$STORE_UPSTREAM_AXIS" -v drop="$drop" '
    function live(v) { while (index(drop, " " v " ")) v = par[v]; return v }
    function emit(   i) {
      if (n == 0) return
      if (!(axis == ax && index(drop, " " vname " ")))
        for (i = 1; i <= n; i++) {
          if (axis == ax && block[i] ~ /^    parent /) print "    parent " live(par[vname]); else print block[i]
        }
      n = 0
    }
    NR == FNR    { par[$1] = $2; next }
    /^axis$/     { emit(); axis = ""; fresh = 1; print; next }
    /^  value$/  { emit(); n = 1; block[1] = $0; vname = ""; next }
    /^  [a-z]/   { emit(); if (fresh && $1 == "name") { axis = $2; fresh = 0 } print; next }
    n > 0        { block[++n] = $0; if ($1 == "name") vname = $2; next }
    { print }
    END          { emit() }
  ' "$cfg.values" "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
  rm -f "$cfg.values"
  # Orthant's working tree may be checked out at a value just forgotten, which every
  # later command would then make a value again, by Orthant's own (slow) ancestry
  rm -rf "$VIEW/.orthant/work"
}

# store_save — write the view back over the store: what was checked in, in it
store_save() {
  local tree
  store_prune
  tree="$(awk '$1 == "tree" { print $2; exit }' "$STORE/config.tel")"
  rm -rf "$STORE/data"
  if [ -d "$VIEW/.orthant/data" ]; then cp -R "$VIEW/.orthant/data" "$STORE/data"; fi
  awk -v tree="$tree" '
    /^tree /           { print "tree " tree; next }
    /^    repository / { print "    repository ."; next }
    { print }' "$VIEW/.orthant/config.tel" > "$STORE/config.tel.tmp" && mv "$STORE/config.tel.tmp" "$STORE/config.tel"
}

# o <args> — orthant, in the view (and not reading what a loop around it reads)
o() { (cd "$VIEW" && "$ORTHANT" "$@" </dev/null); }

# store_export <patch> <value> <dir> — the documents at a point, into an empty <dir>;
# succeeds only if none of them wants attention there (a hunk which no longer finds
# its lines as they were: stale, in conflict, or without its file)
store_export() {
  rm -rf "$3"
  if o export "$3" "$1" "$2" --strict >/dev/null 2>&1; then mkdir -p "$3"; return 0; fi
  rm -rf "$3"
  o export "$3" "$1" "$2" >/dev/null 2>"$VIEW/export.err" \
    || die "orthant cannot derive the patch $1 at $2: $(cat "$VIEW/export.err")"
  mkdir -p "$3"
  return 1
}

# store_put <patch> <value> <dir> [<orthant checkin option>...] — make the content at a
# point, of every document the store knows or <dir> has, what <dir> has (a document
# <dir> lacks is absent there; PUT_ABSENT may list, one to a line, files of upstream's
# which are to be absent too). Checks in only what differs; PUT_COUNT is how many
# documents did. Fails if Orthant refuses the check-in, with its reasons in
# $VIEW/put.out.
PUT_COUNT=0
store_put() {
  local p="$1" v="$2" src="$3"; shift 3
  local f c changed=() w="$VIEW/work"
  o checkout "$p" "$v" --direct --force >/dev/null 2>"$VIEW/put.err" \
    || die "orthant cannot check out $p at $v: $(cat "$VIEW/put.err")"
  while IFS= read -r f; do
    if [ -f "$src/$f" ]; then
      if ! cmp -s "$src/$f" "$w/$f"; then mkdir -p "$(dirname "$w/$f")"; cp "$src/$f" "$w/$f"; changed+=("$f"); fi
    elif [ -f "$w/$f" ]; then
      rm -f "$w/$f"; changed+=("$f")
    fi
  done < <({ store_documents "$VIEW"; if [ -d "$src" ]; then (cd "$src" && find . -type f | sed 's#^\./##'); fi; } | sort -u)
  # A file of upstream's which no patch has touched is not a document yet, so the loop
  # above did not see it. To take one away it is first taken up, as upstream has it.
  if [ -n "${PUT_ABSENT:-}" ]; then
    c="$(store_values "$VIEW/.orthant/config.tel" | awk -v n="$v" '$1 == n { print $3 }')"
    store_documents "$VIEW" > "$VIEW/put.docs"
    while IFS= read -r f; do
      [ -n "$f" ] && [ ! -e "$src/$f" ] && [ ! -e "$w/$f" ] && g cat-file -e "$c:$f" 2>/dev/null || continue
      # one which is a document, and not there, an earlier patch has taken away already
      ! grep -qxF -- "$f" "$VIEW/put.docs" || continue
      mkdir -p "$(dirname "$w/$f")"; g cat-file blob "$c:$f" > "$w/$f"
      o checkin "$f" >"$VIEW/put.out" 2>&1 || return 1
      rm -f "$w/$f"; changed+=("$f")
    done <<< "$PUT_ABSENT"
  fi
  PUT_COUNT="${#changed[@]}"
  if [ "${#changed[@]}" -gt 0 ]; then
    o checkin --remove "$@" "${changed[@]}" >"$VIEW/put.out" 2>&1 || return 1
  fi
  return 0
}
# store_put_or_die <patch> <value> <dir> [<option>...]
store_put_or_die() {
  store_put "$@" || { cat >&2 "$VIEW/put.out"; die "orthant refused to check in $1 at $2"; }
}

# store_confirm <patch> <value> — record that the patch's stale hunks at a point are
# right as they are shown: they are stored there, against the lines upstream now has
store_confirm() {
  o checkout "$1" "$2" --direct --force >/dev/null 2>"$VIEW/put.err" \
    || die "orthant cannot check out $1 at $2: $(cat "$VIEW/put.err")"
  o confirm >"$VIEW/put.out" 2>&1 || { cat >&2 "$VIEW/put.out"; die "orthant could not confirm $1 at $2"; }
}

# store_add_patch <patch> <after> — a new patch in the view's chain, after another (or
# after the root): what followed that one now follows the new one
store_add_patch() {
  local p="$1" after="$2" cfg="$VIEW/.orthant/config.tel" next
  next="$(store_axis "$cfg" "$STORE_PATCH_AXIS" | awk -v a="$after" '$2 == a { print $1 }')"
  o axis value "$STORE_PATCH_AXIS" "$p" "$after" >"$VIEW/put.out" 2>&1 \
    || { cat >&2 "$VIEW/put.out"; die "orthant would not add the patch $p"; }
  [ -n "$next" ] || return 0
  awk -v ax="$STORE_PATCH_AXIS" -v nxt="$next" -v p="$p" '
    /^axis$/       { axis = ""; fresh = 1; print; next }
    /^  name /     { if (fresh) { axis = $2; fresh = 0 } print; next }
    /^    name /   { cur = $2; print; next }
    /^    parent / { if (axis == ax && cur == nxt) print "    parent " p; else print; next }
    { print }' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# store_remove_patch <patch> — take a patch out of the view's chain, with all it holds
store_remove_patch() {
  local p="$1" cfg="$VIEW/.orthant/config.tel" parent
  parent="$(store_axis "$cfg" "$STORE_PATCH_AXIS" | awk -v p="$p" '$1 == p { print $2 }')"
  [ -n "$parent" ] && [ "$parent" != - ] || die "'$p' is not a patch of the store"
  awk -v ax="$STORE_PATCH_AXIS" -v p="$p" -v parent="$parent" '
    function emit(   i) { if (n && !(axis == ax && vname == p)) for (i = 1; i <= n; i++) print block[i]; n = 0 }
    /^axis$/       { emit(); axis = ""; fresh = 1; print; next }
    /^  value$/    { emit(); n = 1; block[1] = $0; vname = ""; next }
    /^  [a-z]/     { emit(); if (fresh && $1 == "name") { axis = $2; fresh = 0 } print; next }
    n > 0          { if ($1 == "name") vname = $2
                     if (axis == ax && $1 == "parent" && $2 == p) block[++n] = "    parent " parent; else block[++n] = $0
                     next }
    { print }
    END            { emit() }' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
  rm -rf "$VIEW/.orthant/data/$p"
}

# store_lineage <config> <value> — the value and those above it, to the root
store_lineage() {
  store_values "$1" | awk -v v="$2" '{ par[$1] = $2 } END { while (v != "" && v != "-") { print v; v = par[v] } }'
}
# store_has <patch> <lineage-file> — whether the view holds anything for a patch at
# any of those values: if not, the patch does nothing there
store_has() {
  local n
  [ -d "$VIEW/.orthant/data/$1" ] || return 1
  while IFS= read -r n; do [ ! -d "$VIEW/.orthant/data/$1/$n" ] || return 0; done < "$2"
  return 1
}

# --- choosing patches for a target -------------------------------------------------

# store_derive <target> <planfile>
# Derive every patch at <target>, a value of the view.
# Writes "<p>\t<status>\t<detail>" lines to <planfile>, with status one of:
#   plain     the patch is there, every hunk of it finding its lines as they were
#   stale     it is there, but upstream changed lines it changes or sits beside: what
#             it does there wants a person's eye (as a three-way merge did)
#   out       the patch's bounds exclude the target (detail: the bound)
#   missing   in range, but the store has nothing for it at the target
# STORE_PRE[<p>] / STORE_POST[<p>] are the git trees before and after each patch, and
# STORE_TREE the last. A patch which is out has the tree before it: if what the store
# holds says otherwise (upstream moved beneath the bound's cancelling hunks), the view
# is put right, and the detail says so.
declare -gA STORE_PRE=() STORE_POST=()
STORE_TREE=""
store_derive() {
  local t="$1" plan="$2" v p r idx dir before prev tree st detail f clean docs n all
  local -A mode=()
  v="${VIEW_NAME[$t]}"
  STORE_PRE=() STORE_POST=()
  idx="$VIEW/index"; dir="$VIEW/at"
  rm -f "$idx"
  GIT_INDEX_FILE="$idx" g read-tree "$t"
  docs="$VIEW/documents"; store_documents "$VIEW" > "$docs"
  while IFS=$'\t' read -r n f; do mode[$f]="$n"; done < <(g ls-tree -r "$t" \
    | awk -F'\t' 'NR == FNR { doc[$0] = 1; next } ($2 in doc) { split($1, a, " "); print a[1] "\t" $2 }' "$docs" -)
  prev="$(g rev-parse "$t^{tree}")"
  # every patch at once: Orthant derives the chain in one call. If any of them wants
  # attention, each is asked for alone, to tell which
  store_along "$v"; all="$STORE_ALONG_CLEAN"
  before="$VIEW/along/$(store_root_patch "$VIEW/.orthant/config.tel")"; mkdir -p "$before"
  store_lineage "$VIEW/.orthant/config.tel" "$v" > "$VIEW/lineage"
  : > "$plan"
  while IFS= read -r p; do
    r="$(in_range "$p" "$t")"
    if ! store_has "$p" "$VIEW/lineage"; then
      # nothing of the patch reaches this commit
      if [ "$r" = in ]; then st=missing; detail="-"; else st=out; detail="$r"; fi
      STORE_PRE[$p]="$prev"; STORE_POST[$p]="$prev"
      printf '%s\t%s\t%s\n' "$p" "$st" "$detail" >> "$plan"
      continue
    fi
    dir="$VIEW/along/$p"; mkdir -p "$dir"
    if [ "$all" = 1 ] || o export "$VIEW/strict" "$p" "$v" --strict >/dev/null 2>&1; then clean=1; else clean=0; fi
    rm -rf "$VIEW/strict"
    tree="$(store_index "$idx" "$dir" "$docs")"
    detail="-"
    if [ "$r" != in ]; then
      st=out; detail="$r"
      if [ "$tree" != "$prev" ]; then
        store_put_or_die "$p" "$v" "$before"
        store_along "$v"; all="$STORE_ALONG_CLEAN"; mkdir -p "$dir" "$before"
        tree="$(store_index "$idx" "$dir" "$docs")"
        [ "$tree" = "$prev" ] || die "cannot make the patch $p absent at $t, as its bound ($r) says it is"
        detail="$r (not so in the store at this commit: put right in the view)"
      fi
    elif [ "$tree" = "$prev" ]; then st=missing
    elif [ "$clean" = 1 ]; then st=plain
    else st=stale
    fi
    STORE_PRE[$p]="$prev"; STORE_POST[$p]="$tree"
    printf '%s\t%s\t%s\n' "$p" "$st" "$detail" >> "$plan"
    prev="$tree"
    before="$dir"
  done < <(store_patches "$VIEW/.orthant/config.tel")
  STORE_TREE="$prev"
  return 0
}

# store_along <value> — the documents after every patch at a value, each patch's in
# $VIEW/along/<patch>; STORE_ALONG_CLEAN is 1 if none of them wants attention there
STORE_ALONG_CLEAN=0
store_along() {
  rm -rf "$VIEW/along"
  if o export "$VIEW/along" "$1" --along "$STORE_PATCH_AXIS" --strict >/dev/null 2>&1; then STORE_ALONG_CLEAN=1; return 0; fi
  STORE_ALONG_CLEAN=0
  rm -rf "$VIEW/along"
  o export "$VIEW/along" "$1" --along "$STORE_PATCH_AXIS" >/dev/null 2>"$VIEW/export.err" \
    || die "orthant cannot derive the patches at $1: $(cat "$VIEW/export.err")"
}

# store_plan <target> <planfile> — the same, in a new view (left in VIEW)
store_plan() {
  store_view "$1"
  store_derive "$1" "$2"
}

# store_index <index> <dir> <documents-file> — make the index have each document as
# <dir> has it (and not have those <dir> lacks); prints the tree
store_index() {
  local idx="$1" dir="$2" docs="$3"
  (
    cd "$dir"
    find . -type f | sed 's#^\./##' | sort > "$idx.have"
    paste <(sed "s#^#$dir/#" "$idx.have" | g hash-object -w --no-filters --stdin-paths) "$idx.have" | while IFS=$'\t' read -r h f; do
      printf '%s %s\t%s\n' "${mode[$f]:-100644}" "$h" "$f"
    done
    comm -23 "$docs" "$idx.have" | while IFS= read -r f; do
      printf '0 0000000000000000000000000000000000000000\t%s\n' "$f"
    done
  ) | GIT_INDEX_FILE="$idx" g update-index --index-info
  GIT_INDEX_FILE="$idx" g write-tree
}

plan_count() { awk -F'\t' -v s="$2" '$2 == s' "$1" | wc -l | tr -d ' '; }
plan_names() { awk -F'\t' -v s="$2" '$2 == s { print $1 }' "$1" | tr '\n' ' '; }

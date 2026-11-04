#!/usr/bin/env bash
#
# Publish a release's descriptors to this repository's orphan `ivy` branch, where crux
# (propensive/crux) reads a Proscala release as an Ivy-pattern repository: for every build in the
# release, the directory `<version>/` holding `<artifactId>-<version>.ivy.xml` for each loose jar,
# derived from the POM in that build's `proscala-<version>-maven.zip` by pom-to-ivy.py (which also
# names the fork's modules `org.scala-lang`, the organisation every build asks for).
#
# Usage: etc/ivy-publish.sh <dir>     the release's assets: proscala-*-maven.zip and the loose jars
#
# Run by the release workflow once the GitHub release exists, with the job's token in GH_TOKEN. A
# version already on the branch is left alone (a tag's descriptors are immutable: Coursier caches
# them as such).

set -euo pipefail

ASSETS=${1:?usage: ivy-publish.sh <assets dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${GITHUB_REPOSITORY:-propensive/proscala}
BRANCH=ivy

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if git ls-remote --exit-code --heads "https://github.com/$REPO.git" "$BRANCH" >/dev/null 2>&1; then
  git clone --quiet --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$WORK/branch"
else
  git clone --quiet --depth 1 --no-checkout "https://github.com/$REPO.git" "$WORK/branch"
  git -C "$WORK/branch" checkout --quiet --orphan "$BRANCH"
  git -C "$WORK/branch" rm -rfq --cached . 2>/dev/null || true
  find "$WORK/branch" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
fi

versions=()
for zip in "$ASSETS"/proscala-*-maven.zip; do
  [[ -e "$zip" ]] || continue
  name=$(basename "$zip" -maven.zip); version=${name#proscala-}
  if [[ -d "$WORK/branch/$version" ]]; then echo "ivy-publish: $version already published"; continue; fi
  rm -rf "$WORK/maven"; unzip -q "$zip" -d "$WORK/maven"
  mkdir -p "$WORK/branch/$version"
  count=0
  while IFS= read -r pom; do
    base=$(basename "$pom" .pom)                     # <artifactId>-<version>
    [[ -f "$ASSETS/$base.jar" ]] || continue         # only what the release attaches as a loose jar
    python3 -I "$HERE/pom-to-ivy.py" "$pom" "$WORK/branch/$version/$base.ivy.xml"
    count=$((count + 1))
  done < <(find "$WORK/maven" -name '*.pom' | sort)
  echo "ivy-publish: $count descriptors for $version"
  versions+=("$version")
done

(( ${#versions[@]} > 0 )) || { echo "ivy-publish: nothing new"; exit 0; }
git -C "$WORK/branch" add -A
git -C "$WORK/branch" -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "Descriptors for ${versions[*]}"
git -C "$WORK/branch" -c credential.helper='!gh auth git-credential' push --quiet origin "HEAD:$BRANCH"
echo "ivy-publish: pushed ${versions[*]} to the $BRANCH branch"

#!/bin/sh
# release.sh: cut a pap release, the tag consumers pin (decisions 0001, 0008).
#
# Usage: scripts/release.sh <version> [--dry-run]
#        mise run release <version> [--dry-run]
#
# Builds pap-<version>.tar.gz from origin/main as it is on GitHub now: the
# tree at that commit, every path of it whatever .gitattributes marks
# export-ignore, symlinks dereferenced, plus a VERSION file, under one
# pap-<version>/ directory, so mise's github backend finds bin/pap. Refuses
# to go on if the archive's paths are not the tree's. Then
# creates the GitHub release v<version> at that commit with the archive
# attached. The tag is made by GitHub, not pushed: the pre-push guard
# refuses every push from main (decision 0002), and a tag made from the
# commit on origin cannot carry unpushed work. The notes are GitHub's
# generated ones under a "Written with" section from scripts/written-with.sh,
# over the range from the previous tag to that commit. --dry-run builds the
# archive, prints its path and sha256 and the section, and creates nothing.
#
# One tag series for the repository: the pap plugin and the toolkit share
# the version from 0.5.0 (decision 0001). Refuses a version that is not
# x.y.z, whose tag already exists on origin, or that
# plugins/pap/.claude-plugin/plugin.json and the pap entry in
# .claude-plugin/marketplace.json do not both carry at that commit, or
# whose section under "## pap" in CHANGELOG.md at that commit still reads
# "Unreleased": date it before releasing.
# Requires git, tar, jq and gh (authenticated), which the section reads pull
# request bodies with.

set -eu

die() { printf 'release: %s\n' "$*" >&2; exit 1; }

version="" dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    -*) die "usage: release.sh <version> [--dry-run]" ;;
    *) [ -z "$version" ] || die "one version only"; version="$arg" ;;
  esac
done
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
  die "version must be x.y.z, got '${version}'"
tag="v$version"

cd "$(dirname "$0")/.."
git fetch --quiet --tags origin main
sha="$(git rev-parse origin/main)"
[ -z "$(git ls-remote --tags origin "refs/tags/$tag")" ] || die "$tag already exists on origin"
plugin="$(git show "$sha:plugins/pap/.claude-plugin/plugin.json" | jq -r .version)"
market="$(git show "$sha:.claude-plugin/marketplace.json" | jq -r '.plugins[] | select(.name == "pap") | .version')"
[ "$plugin" = "$version" ] && [ "$market" = "$version" ] ||
  die "origin/main carries pap $plugin in plugin.json and $market in marketplace.json, not $version; bump both first"
heading="$(git show "$sha:CHANGELOG.md" | awk -v h="### [$version]" '
  /^## / { pap = ($0 == "## pap") }
  pap && index($0, h) == 1 { print; exit }')"
case "$heading" in
  *Unreleased*) die "CHANGELOG.md at origin/main reads '$heading'; date the $version section first" ;;
esac

out="$(mktemp -d)"
name="pap-$version"
# The tree through a scratch index, not `git archive`: an archive leaves out
# every path .gitattributes marks export-ignore, which is .github and
# .devcontainer at any depth. 0.5.0 and 0.6.0 were built that way and
# shipped without the ruleset and labels `pap repo` reads, and without the
# base layer's workflow, Renovate configuration and devcontainer. The
# checkout's own index and working tree are not touched.
GIT_INDEX_FILE="$out/index" git read-tree "$sha"
GIT_INDEX_FILE="$out/index" git checkout-index --all --prefix="$out/raw/"
rm -f "$out/index"
# cp -L, not tar -h: the archive carries plain files, neither symlinks nor
# the hard links tar -h makes of two paths to one file.
cp -RL "$out/raw" "$out/$name"
# The archive is the tree: refuse one that has lost or gained a path.
want="$(git -c core.quotePath=false ls-tree -r --name-only "$sha" | LC_ALL=C sort)"
have="$(cd "$out/$name" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)"
[ "$want" = "$have" ] || die "the archive does not hold the tree at $sha; paths in one and not the other:
$({ printf '%s\n' "$want"; printf '%s\n' "$have"; } | LC_ALL=C sort | uniq -u)"
printf '%s\n' "$version" > "$out/$name/VERSION"
tar -C "$out" -czf "$out/$name.tar.gz" "$name"
rm -rf "${out:?}/raw" "${out:?}/$name"
asset="$out/$name.tar.gz"

printf 'Built %s from %s\n' "$asset" "$sha"
if command -v sha256sum >/dev/null 2>&1; then sha256sum "$asset"; else shasum -a 256 "$asset"; fi
# From the previous tag, or the whole history for a first release.
range="$sha"
if prev="$(git describe --tags --abbrev=0 "$sha" 2>/dev/null)"; then range="$prev..$sha"; fi
notes="$out/written-with.md"
{ sh scripts/written-with.sh "$range"; printf '\n'; } > "$notes"
if [ "$dry_run" = true ]; then
  cat "$notes"
  printf 'Dry run: no release created.\n'
  exit 0
fi

# gh puts --notes-file above the generated notes.
gh release create "$tag" "$asset" --target "$sha" --title "$tag" --notes-file "$notes" --generate-notes
printf 'Released %s. Consumers pin it in .config/mise/conf.d/pap.toml:\n' "$tag"
printf '  "github:blairforce1/pap" = { version = "%s", asset_pattern = "pap-*.tar.gz" }\n' "$version"

#!/bin/sh
# release.sh: cut a pap release, the tag consumers pin (decisions 0001, 0008).
#
# Usage: scripts/release.sh <version> [--dry-run]
#        mise run release <version> [--dry-run]
#
# Builds pap-<version>.tar.gz from origin/main as it is on GitHub now: the
# tree at that commit, symlinks dereferenced, plus a VERSION file, under one
# pap-<version>/ directory, so mise's github backend finds bin/pap. Then
# creates the GitHub release v<version> at that commit with the archive
# attached. The tag is made by GitHub, not pushed: the pre-push guard
# refuses every push from main (decision 0002), and a tag made from the
# commit on origin cannot carry unpushed work. --dry-run builds the archive,
# prints its path and sha256, and creates nothing.
#
# One tag series for the repository: the pap plugin and the toolkit share
# the version from 0.5.0 (decision 0001). Refuses a version that is not
# x.y.z, whose tag already exists on origin, or that
# plugins/pap/.claude-plugin/plugin.json and the pap entry in
# .claude-plugin/marketplace.json do not both carry at that commit.
# Requires git, tar, jq and, without --dry-run, gh (authenticated).

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
git fetch --quiet origin main
sha="$(git rev-parse origin/main)"
[ -z "$(git ls-remote --tags origin "refs/tags/$tag")" ] || die "$tag already exists on origin"
plugin="$(git show "$sha:plugins/pap/.claude-plugin/plugin.json" | jq -r .version)"
market="$(git show "$sha:.claude-plugin/marketplace.json" | jq -r '.plugins[] | select(.name == "pap") | .version')"
[ "$plugin" = "$version" ] && [ "$market" = "$version" ] ||
  die "origin/main carries pap $plugin in plugin.json and $market in marketplace.json, not $version; bump both first"

out="$(mktemp -d)"
name="pap-$version"
mkdir "$out/raw"
git archive "$sha" | tar -x -C "$out/raw"
# cp -L, not tar -h: the archive carries plain files, neither symlinks nor
# the hard links tar -h makes of two paths to one file.
cp -RL "$out/raw" "$out/$name"
printf '%s\n' "$version" > "$out/$name/VERSION"
tar -C "$out" -czf "$out/$name.tar.gz" "$name"
rm -rf "${out:?}/raw" "${out:?}/$name"
asset="$out/$name.tar.gz"

printf 'Built %s from %s\n' "$asset" "$sha"
if command -v sha256sum >/dev/null 2>&1; then sha256sum "$asset"; else shasum -a 256 "$asset"; fi
if [ "$dry_run" = true ]; then
  printf 'Dry run: no release created.\n'
  exit 0
fi

gh release create "$tag" "$asset" --target "$sha" --title "$tag" --generate-notes
printf 'Released %s. Consumers pin it in .config/mise/conf.d/pap.toml:\n' "$tag"
printf '  "github:blairforce1/pap" = { version = "%s", asset_pattern = "pap-*.tar.gz" }\n' "$version"

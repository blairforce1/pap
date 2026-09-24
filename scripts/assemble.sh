#!/bin/sh
# assemble.sh: build a throwaway repository from template layers.
#
# Usage: scripts/assemble.sh <layer>... <target-dir>
#
# Copies each named layer under templates/ into <target-dir>, dereferencing
# symlinks, and prints the files written, one path per line. A layer's own
# top-level README.md documents the layer and is not copied. Refuses, and
# writes nothing, when two layers carry the same path (decision 0003 rule 1),
# when a layer does not exist, or when <target-dir> exists and is not empty.
# The seed of `pap init`.

set -eu

die() { printf 'assemble: %s\n' "$*" >&2; exit 1; }

[ "$#" -ge 2 ] || die "usage: assemble.sh <layer>... <target-dir>"

templates="$(cd "$(dirname "$0")/../templates" && pwd)"

# The last argument is the target; the rest are layers.
layers=""
target=""
i=0
for arg in "$@"; do
  i=$((i + 1))
  if [ "$i" -eq "$#" ]; then target="$arg"; else layers="$layers $arg"; fi
done

if [ -e "$target" ]; then
  [ -d "$target" ] || die "$target exists and is not a directory"
  [ -z "$(ls -A "$target")" ] || die "$target is not empty"
fi

list="$(mktemp)"
trap 'rm -f "$list"' EXIT INT TERM

for layer in $layers; do
  case "$layer" in */* | .*) die "not a layer name: $layer" ;; esac
  [ -d "$templates/$layer" ] || die "no such layer: templates/$layer"
  (cd "$templates/$layer" && find . \( -type f -o -type l \) ! -path ./README.md) |
    sed "s|^\./||; s|^|$layer |" >> "$list"
done

dups="$(cut -d' ' -f2- "$list" | sort | uniq -d)"
if [ -n "$dups" ]; then
  printf '%s\n' "$dups" | while IFS= read -r path; do
    owners="$(awk -v p="$path" '{ l = $1; sub(/^[^ ]+ /, ""); if ($0 == p) print l }' "$list" | tr '\n' ' ')"
    printf 'assemble: collision: %s is in layers: %s\n' "$path" "${owners% }" >&2
  done
  die "refusing: layers add, never replace (decision 0003)"
fi

mkdir -p "$target"
while IFS=' ' read -r layer path; do
  mkdir -p "$target/$(dirname "$path")"
  cp -L "$templates/$layer/$path" "$target/$path"
done < "$list"

cut -d' ' -f2- "$list" | sort

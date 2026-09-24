#!/bin/sh
# assemble.test.sh: tests for scripts/assemble.sh.
#
# Usage: sh tests/assemble.test.sh
#
# Assembles the real layers into temporary directories, and a synthetic pair
# of colliding layers in a copy of the script beside its own templates/.
# Prints one TAP-style line per case and exits 1 if any case fails. Touches
# nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
asm="$here/scripts/assemble.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM

n=0
failed=0
result() { # result <ok 0|1> <label> [detail]
  n=$((n + 1))
  if [ "$1" = 0 ]; then
    printf 'ok %d - %s\n' "$n" "$2"
  else
    printf 'not ok %d - %s\n' "$n" "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3" | sed 's/^/# /'
    failed=$((failed + 1))
  fi
}

# Base only.
out="$(sh "$asm" base "$T/b" 2>&1)"; rc=$?
result "$rc" "base: exits 0" "$out"
[ -f "$T/b/.editorconfig" ] && [ -f "$T/b/lefthook.yml" ]
result $? "base: files copied to the target root"
[ -f "$T/b/scripts/guard-branch.sh" ] && [ ! -L "$T/b/scripts/guard-branch.sh" ] &&
  cmp -s "$T/b/scripts/guard-branch.sh" "$here/scripts/guard-branch.sh"
result $? "base: symlinked scripts are dereferenced to their content"
[ -x "$T/b/scripts/guard-branch.sh" ]
result $? "base: executable bit kept"
[ ! -e "$T/b/README.md" ]
result $? "base: the layer README is not copied"
expected="$(cd "$here/templates/base" && find . \( -type f -o -type l \) ! -path ./README.md | sed 's|^\./||' | sort)"
[ "$out" = "$expected" ]
result $? "base: prints every file written, one per line" "$out"

# Base, dotnet and go together.
out="$(sh "$asm" base dotnet go "$T/bdg" 2>&1)"; rc=$?
result "$rc" "base+dotnet+go: no collision, exits 0" "$out"
[ -f "$T/bdg/global.json" ] && [ -f "$T/bdg/.golangci.yml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/base.toml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/dotnet.toml" ] &&
  [ -f "$T/bdg/.config/mise/conf.d/go.toml" ]
result $? "base+dotnet+go: every layer's files present"
[ "$(printf '%s\n' "$out" | wc -l)" -eq "$(find "$T/bdg" -type f | wc -l)" ]
result $? "base+dotnet+go: printed list matches the files on disk"

# A synthetic collision.
mkdir -p "$T/fake/scripts" "$T/fake/templates/one/.config" "$T/fake/templates/two/.config"
cp "$asm" "$T/fake/scripts/"
echo one > "$T/fake/templates/one/.config/shared.toml"
echo two > "$T/fake/templates/two/.config/shared.toml"
echo a > "$T/fake/templates/one/only-one"
out="$(sh "$T/fake/scripts/assemble.sh" one two "$T/c" 2>&1)"; rc=$?
[ "$rc" = 1 ]
result $? "collision: exits 1" "$out"
printf '%s\n' "$out" | grep -q 'collision: .config/shared.toml is in layers: one two'
result $? "collision: names the path and both layers" "$out"
[ ! -e "$T/c" ]
result $? "collision: writes nothing"

# Refusals.
out="$(sh "$asm" base nosuch "$T/n" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'no such layer: templates/nosuch' && [ ! -e "$T/n" ]
result $? "unknown layer: refused, nothing written" "$out"
mkdir "$T/full" && touch "$T/full/x"
out="$(sh "$asm" base "$T/full" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'is not empty'
result $? "non-empty target: refused" "$out"
out="$(sh "$asm" "$T/only" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q usage
result $? "no layer: usage" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

#!/bin/sh
# release.test.sh: tests for scripts/release.sh's CHANGELOG refusal.
#
# Usage: sh tests/release.test.sh
#
# Builds a repository with a bare origin in a temporary directory, carrying
# release.sh, both manifests at 1.0.0 and a CHANGELOG, and runs release.sh
# --dry-run, which creates no release. Prints one TAP-style line per case
# and exits 1 if any case fails. Needs git, tar and jq; touches nothing
# outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"

for tool in git tar jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T" TMPDIR="$T"

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
g() { git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# changelog <pap 1.0.0 heading suffix>: a spec-review 1.0.0 section left
# Unreleased, which the refusal must ignore.
changelog() {
  cat > "$T/repo/CHANGELOG.md" <<LOG
# Changelog

## spec-review

### [1.0.0] - Unreleased

## pap

### [Unreleased]

### [1.0.0] - $1
LOG
}

# commit <message> [push]
commit() {
  g add -A && g commit -q -m "$1"
  [ "${2:-}" = push ] && g push -q origin main
  return 0
}

git init -q --bare -b main "$T/origin.git"
git init -q -b main "$T/repo"
g remote add origin "$T/origin.git"
mkdir -p "$T/repo/scripts" "$T/repo/plugins/pap/.claude-plugin" "$T/repo/.claude-plugin"
cp "$here/scripts/release.sh" "$T/repo/scripts/"
printf '{"version": "1.0.0"}\n' > "$T/repo/plugins/pap/.claude-plugin/plugin.json"
printf '{"plugins": [{"name": "pap", "version": "1.0.0"}]}\n' > "$T/repo/.claude-plugin/marketplace.json"

release() { sh "$T/repo/scripts/release.sh" 1.0.0 --dry-run 2>&1; }

changelog Unreleased
commit "undated" push
out="$(release)"
status=$?
[ "$status" = 1 ] && printf '%s' "$out" | grep -q "reads '### \[1.0.0\] - Unreleased'"
result $? "refuses a pap section that reads Unreleased" "$out"

changelog 2026-01-01
commit "dated, not pushed"
out="$(release)"
status=$?
[ "$status" = 1 ]
result $? "reads the CHANGELOG at origin/main, not the checkout" "$out"

g push -q origin main
out="$(release)"
status=$?
[ "$status" = 0 ] && printf '%s' "$out" | grep -q '^Dry run: no release created.'
result $? "passes a dated section under an [Unreleased] one" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

#!/bin/sh
# release.test.sh: tests for scripts/release.sh's CHANGELOG refusal and
# the "Written with" section its --dry-run prints.
#
# Usage: sh tests/release.test.sh
#
# Builds a repository with a bare origin in a temporary directory, carrying
# release.sh, both manifests at 1.0.0 and a CHANGELOG, and runs release.sh
# --dry-run, which creates no release. A stub gh on PATH serves fixture pull
# request bodies, so nothing touches the network. Prints one TAP-style line
# per case and exits 1 if any case fails. Needs git, tar and jq; touches
# nothing outside the temporary directory.
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
# gh pr view <n> --json body -q .body: the fixture body for pull request n.
mkdir -p "$T/bin" "$T/bodies"
cat > "$T/bin/gh" <<STUB
#!/bin/sh
cat "$T/bodies/\$3"
STUB
chmod +x "$T/bin/gh"
PATH="$T/bin:$PATH"

mkdir -p "$T/repo/scripts" "$T/repo/plugins/pap/.claude-plugin" "$T/repo/.claude-plugin"
cp "$here/scripts/release.sh" "$here/scripts/written-with.sh" "$T/repo/scripts/"
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

# The previous release's pull request is outside the range. #2 is a squash
# merge that kept one of its two Anthropic co-authors; its Provenance: line
# names both. #3's prompt names a model that did not write it.
printf 'x\n' > "$T/repo/one" && commit "feat: before the tag (#1)

Co-authored-by: Claude Haiku 4.5 <noreply@anthropic.com>"
g tag v0.9.0
printf 'Provenance: Claude Haiku 4.5 via Claude Code\n' > "$T/bodies/1"
printf 'x\n' > "$T/repo/two" && commit "feat: two models, one trailer (#2)

Co-authored-by: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
printf 'Summary\n\nProvenance: Claude Opus 5.5 via Claude Code (rule chosen by a Claude Fable 5.1 subagent), skill change\n' > "$T/bodies/2"
printf 'x\n' > "$T/repo/three" && commit "feat: a quoted prompt (#3)

Co-authored-by: Claude Opus 5.5 <noreply@anthropic.com>
Co-authored-by: A Person <person@example.invalid>"
printf 'Provenance: Claude Opus 5.5 via Claude Code, prompt "compare with Sonnet 5"\n' > "$T/bodies/3"
printf 'x\n' > "$T/repo/four" && commit "chore: no pull request number"
g push -q --tags origin main
out="$(release)"
status=$?
want='## Written with
* Claude Opus 5.5 in 2 pull requests
* Claude Fable 5.1 in 1 pull request'
case "$out" in *"$want

Dry run"*) [ "$status" = 0 ] ;; *) false ;; esac
result $? "prints the Written with section from trailers and Provenance lines" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

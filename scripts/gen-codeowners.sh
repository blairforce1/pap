#!/bin/sh
# gen-codeowners.sh: writes .github/CODEOWNERS from the "Protected paths"
# section of product/invariants.md, so the paths no agent may change without
# a recorded human approval (process section 3.2) are the paths GitHub and
# the pr-checks workflow treat as protected.
#
# Usage: gen-codeowners.sh [--owner <owner>] [--check | -]
#
#   --owner  The GitHub user or team that owns every path, with or without
#            the leading @. Refused when the section names other owners.
#   --check  Write nothing; exit 1 if .github/CODEOWNERS in the index (what
#            the next commit carries) differs from what would be generated.
#            Used by the pre-commit hook and `mise run check:codeowners`.
#   -        Write to stdout instead of .github/CODEOWNERS.
#
# The owner of every path, the first of these that is given:
#
#   1. An `Owner:` (or `Owners:`) line in the section, not a bullet, naming
#      one or more users or teams: `Owner: @alice`, `Owners: @alice,
#      @acme/platform`. Each name starts with @, so prose after the colon
#      is refused and never read as owners; Markdown backticks are allowed.
#      This is the one the pre-commit hook and `mise run check:codeowners`
#      can read:
#      they pass no --owner, so an owner given only on the command line
#      fails their --check.
#   2. --owner.
#   3. The owner segment of the origin remote, github.com/<owner>/<repo>
#      over ssh or https. Right for a repository under a personal account.
#      An organisation is not a valid code owner, so in an organisation's
#      repository name a user or team on the line in 1. `pap repo status`
#      reports an owner GitHub does not accept.
#
# Every backticked path on a bullet line of the section becomes one line
# owned by the owner. A path that does not start with `/` or `**` is
# anchored at the root with a leading `/`: invariants.md means the
# repository's CLAUDE.md, not every CLAUDE.md. CODEOWNERS has no negation or
# character ranges, so a path with `!`, `[` or whitespace is refused.
#
# Exits 1 with one line on stderr when the file, the section, its paths or
# an owner are missing, when the Owner line cannot be read or there are two,
# or when --owner disagrees with it. Running it twice produces the same
# file.

set -eu

src='product/invariants.md'
out='.github/CODEOWNERS'

die() {
  printf 'gen-codeowners: %s\n' "$1" >&2
  exit 1
}

owner=''
mode='write'
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) [ $# -ge 2 ] || die '--owner needs a value'; owner="$2"; shift 2 ;;
    --owner=*) owner="${1#--owner=}"; shift ;;
    --check) mode=check; shift ;;
    -) mode=stdout; shift ;;
    *) die "unknown argument '$1'; usage: gen-codeowners.sh [--owner <owner>] [--check | -]" ;;
  esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die 'not inside a git repository'
cd "$root"

[ -f "$src" ] || die "$src not found"
grep -q '^## Protected paths[[:space:]]*$' "$src" \
  || die "no '## Protected paths' section in $src"

# The section's own owners, one "@name" per word, or nothing.
owner_lines="$(awk '
  /^## / { inside = ($0 ~ /^## Protected paths[[:space:]]*$/); next }
  inside && /^Owners?:/' "$src")"
named=''
if [ -n "$owner_lines" ]; then
  [ "$(printf '%s\n' "$owner_lines" | wc -l)" -eq 1 ] \
    || die "more than one Owner line under '## Protected paths' in $src"
  for o in $(printf '%s\n' "$owner_lines" | sed 's/^Owners\{0,1\}:[[:space:]]*//' | tr ',`' '  '); do
    printf '%s\n' "$o" | grep -Eq '^@[A-Za-z0-9][A-Za-z0-9-]*(/[A-Za-z0-9_.-]+)?$' \
      || die "cannot read an owner from '$owner_lines' in $src; name users or teams as @login or @org/team"
    named="$named $o"
  done
  named="${named# }"
  [ -n "$named" ] \
    || die "cannot read an owner from '$owner_lines' in $src; name users or teams as @login or @org/team"
fi

if [ -n "$named" ]; then
  [ -z "$owner" ] || [ "@${owner#@}" = "$named" ] \
    || die "$src names the owner ($named); change it there, not with --owner"
  owner="$named"
elif [ -n "$owner" ]; then
  owner="@${owner#@}"
else
  # git@github.com:o/r.git, ssh://git@github.com/o/r, https://[user@]github.com/o/r
  owner="$(git remote get-url origin 2>/dev/null \
    | sed -nE 's#^(ssh://)?([^@/]+@)?github\.com[:/]([^/]+)/[^/]+/?$#\3#p; s#^https?://([^@/]+@)?github\.com/([^/]+)/[^/]+/?$#\2#p' \
    | head -n 1)" || true
  [ -n "$owner" ] || die "no owner: add an 'Owner: @login' line under '## Protected paths' in $src, pass --owner <owner>, or set an origin remote on github.com/<owner>/<repo>"
  owner="@${owner#@}"
fi

paths="$(awk '
  /^## / { inside = ($0 ~ /^## Protected paths[[:space:]]*$/); next }
  inside && /^[[:space:]]*[-*] / {
    line = $0
    while (match(line, /`[^`]+`/)) {
      print substr(line, RSTART + 1, RLENGTH - 2)
      line = substr(line, RSTART + RLENGTH)
    }
  }' "$src" | awk '!seen[$0]++')"

[ -n "$paths" ] || die "no backticked paths under '## Protected paths' in $src"

body="$(printf '%s\n' "$paths" | while IFS= read -r p; do
  case "$p" in
    '!'* | *'['* | *[[:space:]]*) die "cannot express '$p' in CODEOWNERS" ;;
    /* | '**'*) ;;
    *) p="/$p" ;;
  esac
  printf '%s %s\n' "$p" "$owner"
done)" || exit 1

content="$(printf '%s\n' \
  '# Generated by scripts/gen-codeowners.sh from the "Protected paths" section' \
  "# of $src. Do not edit by hand: change $src and" \
  '# run scripts/gen-codeowners.sh.' \
  '' \
  "$body")"

case "$mode" in
  stdout)
    printf '%s\n' "$content"
    ;;
  check)
    staged="$(git show ":$out" 2>/dev/null)" \
      || die "$out is not in the index; run scripts/gen-codeowners.sh and git add $out"
    [ "$staged" = "$content" ] \
      || die "$out is stale for $src; run scripts/gen-codeowners.sh and git add $out"
    ;;
  write)
    mkdir -p "$(dirname "$out")"
    printf '%s\n' "$content" > "$out"
    ;;
esac

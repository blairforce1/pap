#!/bin/sh
# written-with.sh: print the "Written with" section of a release's notes.
#
# Usage: scripts/written-with.sh <range>
#   <range> is a git revision range, "v0.5.0..v0.6.0", or one commit for a
#   first release.
#
# Each squash-merged pull request in the range is a commit whose subject
# ends "(#N)". For each, the models named in its Co-authored-by trailers
# and in the Provenance: line of its body (read with gh) are counted once;
# the section lists each model with its count of pull requests.
#
# Trailers alone undercount: a squash merge keeps one co-author per email,
# and every Claude model shares noreply@anthropic.com, so a pull request
# written by two models keeps one trailer (#50 lost its Fable 5.1). The
# Provenance: line names every model, so a pull request counts the union
# of both, and the line wins wherever it names more.
# Requires git and gh (authenticated).

set -eu

[ $# = 1 ] || { printf 'usage: written-with.sh <range>\n' >&2; exit 1; }

# models: read text on stdin, print one "Claude <Family> <version>" per
# model named. Quoted text is dropped first: a prompt may name a model it
# was not written by.
models() {
  sed 's/"[^"]*"//g' |
    grep -Eo '(Claude )?(Fable|Opus|Sonnet|Haiku) [0-9]+(\.[0-9]+)?' |
    sed 's/^Claude //; s/^/Claude /' || true
}

git log --format='%H %s' "$1" | while read -r sha subject; do
  pr="$(printf '%s\n' "$subject" | sed -En 's/.*\(#([0-9]+)\)$/\1/p')"
  [ -n "$pr" ] || continue
  {
    git log -1 --format='%(trailers:key=Co-authored-by,valueonly)' "$sha" |
      grep -i '<noreply@anthropic\.com>' || true
    gh pr view "$pr" --json body -q .body | grep '^Provenance:' || true
  } | models | sort -u
done | sort | uniq -c | sort -k1,1nr -k2 | {
  printf '## Written with\n'
  n=0
  while read -r count model; do
    n=$((n + 1))
    [ "$count" = 1 ] && prs="pull request" || prs="pull requests"
    printf '* %s in %s %s\n' "$model" "$count" "$prs"
  done
  [ "$n" -gt 0 ] || printf 'No model is named in this release.\n'
}

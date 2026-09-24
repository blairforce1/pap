#!/bin/sh
# renovate-copy.test.sh: pap's own .github/renovate.jsonc is a byte-for-byte
# copy of the base template's, so pap runs the file it ships. A copy, not a
# symlink: the hosted Renovate reads configuration through the GitHub API,
# which does not follow symlinks (found on #34).
#
# Usage: sh tests/renovate-copy.test.sh

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
if [ -L "$here/.github/renovate.jsonc" ]; then
  printf 'not ok 1 - .github/renovate.jsonc is a symlink; Renovate will not read it\n'; exit 1
elif cmp -s "$here/.github/renovate.jsonc" "$here/templates/base/.github/renovate.jsonc"; then
  printf 'ok 1 - .github/renovate.jsonc matches templates/base/.github/renovate.jsonc\n'
else
  printf 'not ok 1 - .github/renovate.jsonc differs from templates/base/.github/renovate.jsonc; copy it\n'; exit 1
fi
printf '1..1\n'

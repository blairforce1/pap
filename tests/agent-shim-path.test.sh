#!/bin/sh
# agent-shim-path.test.sh: pap claude puts the gh shim first on PATH for
# Claude Code's shells (decision 0023, rules 23.1 and 23.4). Claude Code's
# Bash tool runs commands non-interactively, so mise's [env] never adds the
# repository's scripts/shim; only pap claude's PATH reaches them.
#
# Usage: sh tests/agent-shim-path.test.sh
#
# A copy of pap is installed in a scratch tree, with bin/pap a wrapper that
# fakes `pap agent-token` and runs the copied pap for everything else, so the
# shim's sibling pap is the fake. A fake claude runs `sh -c` with no mise and
# no interactive shell in a fake adopting repository; a fake gh prints the
# GH_TOKEN it got. Never touches the real HOME, gh config or keyring.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck source=tests/clean-env.sh
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig"
: > "$GIT_CONFIG_GLOBAL"
# What gh auth setup-git writes: the real gh by path, which skips the shim,
# after a store helper that would answer first.
git config --file "$GIT_CONFIG_GLOBAL" credential.helper store
git config --file "$GIT_CONFIG_GLOBAL" credential.https://github.com.helper "!$T/realgh/gh auth git-credential"

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

# The install: what a release tarball holds, as far as pap claude and the
# shim look (bin/pap, scripts/shim/gh, templates/base).
I="$T/install"
mkdir -p "$I/bin" "$I/lib" "$I/scripts/shim" "$I/templates/base"
cp "$here/bin/pap" "$I/lib/pap"
cp "$here/scripts/shim/gh" "$I/scripts/shim/gh"
cat > "$I/bin/pap" <<EOF
#!/bin/sh
if [ "\${1:-}" = agent-token ]; then echo ghs_faketoken; exit 0; fi
exec sh "$I/lib/pap" "\$@"
EOF
chmod +x "$I/bin/pap" "$I/scripts/shim/gh"

mkdir -p "$T/home" "$T/xdg" "$T/fake" "$T/realgh" "$T/repo/scripts"
# Asked by git for a credential, the real gh answers with the owner's
# token, as gh's keyring fallback does with an empty config directory.
cat > "$T/realgh/gh" <<'EOF'
#!/bin/sh
if [ "$1 $2" = "auth git-credential" ]; then
  cat >/dev/null; printf 'username=x-access-token\npassword=gho_OWNER_FROM_KEYRING\n'; exit 0
fi
echo "real gh GH_TOKEN=${GH_TOKEN:-<unset>} $*"
EOF
# What Claude Code's Bash tool does: CLAUDECODE set, a plain sh -c.
cat > "$T/fake/claude" <<'EOF'
#!/bin/sh
cd "$FAKE_REPO" && CLAUDECODE=1 GIT_TERMINAL_PROMPT=0 sh -c 'command -v gh; gh api user; git config --get credential.https://github.com.useHttpPath; printf "url=https://github.com/example-owner/companion.git\n\n" | git credential fill | grep "^password="' > "$FAKE_CLAUDE" 2>&1
EOF
printf '#!/bin/sh\nexit 0\n' > "$T/repo/scripts/guard-branch.sh"
chmod +x "$T/realgh/gh" "$T/fake/claude" "$T/repo/scripts/guard-branch.sh"
git -C "$T/repo" init -q
git -C "$T/repo" remote add origin https://github.com/example-owner/repo.git

# PATH without any copy of the shim: under `mise run test` pap's own
# scripts/shim is on PATH, and must not stand in for pap claude's. The fake
# gh and pap come ahead of any real ones.
p=""
IFS_was="$IFS"
IFS=:
for d in $PATH; do
  [ -n "$d" ] || continue
  l2=""
  { read -r _ && read -r l2; } 2>/dev/null < "$d/gh" || true
  case "$l2" in "# pap-gh-shim:"*) continue ;; esac
  p="$p:$d"
done
IFS="$IFS_was"
base="$T/fake:$T/realgh:$I/bin${p}"

export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" FAKE_CLAUDE="$T/claude.log" FAKE_REPO="$T/repo"
cd "$T" && env -u GH_TOKEN PATH="$base" sh "$I/bin/pap" claude >/dev/null 2>&1; rc=$?
out="$(cat "$FAKE_CLAUDE" 2>&1)"
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "$I/scripts/shim/gh" ]
result $? "pap claude: in a non-interactive agent shell, command -v gh is this pap's shim" "rc=$rc $out"
printf '%s\n' "$out" | grep -qx 'real gh GH_TOKEN=ghs_faketoken api user'
result $? "pap claude: gh runs the shim, which sets GH_TOKEN from pap agent-token and runs the real gh" "$out"
[ "$(printf '%s\n' "$out" | sed -n 3p)" = true ]
result $? "pap claude: git sends the repository path to the credential helper (useHttpPath)" "$out"
[ "$(printf '%s\n' "$out" | sed -n 4p)" = password=ghs_faketoken ]
result $? "pap claude: git's credential comes from the shim, past a store helper and gh by path in the global config" "$out"

[ "$failed" = 0 ] || exit 1

#!/bin/sh
# agent-boundary.test.sh: tests for pap claude, decision 0023's rule 23.4:
# Claude Code runs with GH_CONFIG_DIR set to the agent's gh directory,
# which never holds a sign-in, and with the GitHub token variables unset.
# The shim's check of it is in agent-token.test.sh, doctor's items in
# pap.test.sh, the hook's rules in guard-route.test.sh.
#
# Usage: sh tests/agent-boundary.test.sh
#
# A fake claude logs its environment and arguments; a uname stub picks the
# platform. Never touches the real HOME, gh config or keyring. Prints one
# TAP-style line per case and exits 1 if any case fails.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig"
: > "$GIT_CONFIG_GLOBAL"

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

mkdir -p "$T/home" "$T/linux" "$T/mac" "$T/fake"
printf '#!/bin/sh\necho Linux\n' > "$T/linux/uname"
printf '#!/bin/sh\necho Darwin\n' > "$T/mac/uname"
cat > "$T/fake/claude" <<'EOF'
#!/bin/sh
echo "GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} GH_ENTERPRISE_TOKEN=${GH_ENTERPRISE_TOKEN-<unset>} GITHUB_ENTERPRISE_TOKEN=${GITHUB_ENTERPRISE_TOKEN-<unset>} KEEP=${KEEP-<unset>}" > "$FAKE_CLAUDE"
for a in "$@"; do printf '[%s]\n' "$a" >> "$FAKE_CLAUDE"; done
EOF
chmod +x "$T"/linux/uname "$T"/mac/uname "$T/fake/claude"
export HOME="$T/home" FAKE_CLAUDE="$T/claude.log"
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

agent="$T/xdg/gh-agent"
env PATH="$T/fake:$T/linux:$PATH" XDG_CONFIG_HOME="$T/xdg" GH_CONFIG_DIR="$T/xdg/gh" \
  GH_TOKEN=ghp_owner GITHUB_TOKEN=ghp_owner2 GH_ENTERPRISE_TOKEN=ghp_e GITHUB_ENTERPRISE_TOKEN=ghp_e2 KEEP=yes \
  sh "$pap" claude --resume 'two words' '' >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] &&
  [ "$(cat "$FAKE_CLAUDE")" = "GH_CONFIG_DIR=$agent GH_TOKEN=<unset> GITHUB_TOKEN=<unset> GH_ENTERPRISE_TOKEN=<unset> GITHUB_ENTERPRISE_TOKEN=<unset> KEEP=yes
[--resume]
[two words]
[]" ]
result $? "pap claude: GH_CONFIG_DIR the agent directory, the four token variables unset, the rest of the environment and every argument passed" "rc=$rc $(cat "$FAKE_CLAUDE" 2>&1)"
[ -d "$agent" ] && [ "$(mode "$agent")" = 700 ] && [ -z "$(ls -A "$agent")" ]
result $? "pap claude: the agent directory is created mode 700 and empty" "$(ls -la "$agent" 2>&1)"

chmod 755 "$agent"
env PATH="$T/fake:$T/linux:$PATH" XDG_CONFIG_HOME="$T/xdg" sh "$pap" claude >/dev/null 2>&1
[ "$(mode "$agent")" = 700 ]
result $? "pap claude: an existing agent directory is put back to mode 700" "$(mode "$agent")"

env -u XDG_CONFIG_HOME PATH="$T/fake:$T/mac:$PATH" sh "$pap" claude >/dev/null 2>&1; rc=$?
mac="$HOME/Library/Application Support/gh-agent"
[ "$rc" = 0 ] && [ -d "$mac" ] && head -n 1 "$FAKE_CLAUDE" | grep -q "^GH_CONFIG_DIR=$mac "
result $? "pap claude on macOS: ~/Library/Application Support/gh-agent, beside pap's config" "rc=$rc $(head -n 1 "$FAKE_CLAUDE")"

env -u XDG_CONFIG_HOME PATH="$T/fake:$T/linux:$PATH" sh "$pap" claude >/dev/null 2>&1
head -n 1 "$FAKE_CLAUDE" | grep -q "^GH_CONFIG_DIR=$HOME/.config/gh-agent "
result $? "pap claude on Linux without XDG_CONFIG_HOME: ~/.config/gh-agent" "$(head -n 1 "$FAKE_CLAUDE")"

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

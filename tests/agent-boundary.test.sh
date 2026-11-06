#!/bin/sh
# agent-boundary.test.sh: tests for decision 0023's second slice, rule
# 23.4: pap claude, the gh shim's refusal of a set GH_CONFIG_DIR in an
# agent shell, and pap agent-owner init. Doctor's owner items are in
# pap.test.sh, the hook's rule in guard-route.test.sh, and the owner
# routing of /pap:reviewed and /pap:accept in their own suites.
#
# Usage: sh tests/agent-boundary.test.sh
#
# Never touches the network, the real HOME, the real gh config or the real
# global git config. A fake gh keeps each config directory's github.com
# sign-in as a marker file in that directory (gh's default directory is
# $T/default-gh) and logs every call with its environment; a fake claude
# logs its environment and arguments; a uname stub says Linux. Prints one
# TAP-style line per case and exits 1 if any case fails. Needs git.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

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

mkdir -p "$T/home" "$T/xdg" "$T/fake" "$T/realgh" "$T/shim" "$T/default-gh"
printf '#!/bin/sh\necho Linux\n' > "$T/fake/uname"
cat > "$T/realgh/gh" <<'EOF'
#!/bin/sh
# Fake gh. The directory it reads is GH_CONFIG_DIR, else gh's default
# ($FAKE_DEFAULT); a marker file there is a github.com sign-in.
dir="${GH_CONFIG_DIR:-$FAKE_DEFAULT}"
echo "GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} CLAUDECODE=${CLAUDECODE-<unset>} args=$*" >> "$FAKE_LOG"
case "$1 $2" in
  "auth status") [ -f "$dir/signed-in" ] ;;
  "auth login")
    [ -z "${FAKE_LOGIN_FAIL:-}" ] || exit 1
    # A login that exits 0 and leaves no sign-in behind.
    [ -n "${FAKE_LOGIN_NOOP:-}" ] || : > "$dir/signed-in" ;;
  "auth logout")
    rm -f "$dir/signed-in"
    # A shared keyring entry: the logout takes the owner's sign-in too.
    [ -z "${FAKE_SHARED:-}" ] || rm -f "$FAKE_OWNER/signed-in" ;;
  "api user") echo example-owner ;;
  *) exit 0 ;;
esac
EOF
cat > "$T/fake/claude" <<'EOF'
#!/bin/sh
echo "GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} KEEP=${KEEP-<unset>}" > "$FAKE_CLAUDE"
for a in "$@"; do printf '[%s]\n' "$a" >> "$FAKE_CLAUDE"; done
EOF
chmod +x "$T/fake/uname" "$T/fake/claude" "$T/realgh/gh"
cp "$here/scripts/shim/gh" "$T/shim/gh"

export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" SHELL=/bin/bash
export FAKE_LOG="$T/gh.log" FAKE_DEFAULT="$T/default-gh" FAKE_CLAUDE="$T/claude.log" FAKE_OWNER="$T/xdg/gh-owner"
export PATH="$T/fake:$T/realgh:$PATH"
unset CLAUDECODE GH_CONFIG_DIR GH_TOKEN GITHUB_TOKEN REMOTE_CONTAINERS 2>/dev/null || true
conf="$T/xdg/pap/agent.conf"

# --- pap claude ----------------------------------------------------------------

env GH_CONFIG_DIR="$T/xdg/gh-owner" GH_TOKEN=ghp_owner GITHUB_TOKEN=ghp_owner2 KEEP=yes \
  sh "$pap" claude --resume 'two words' '' >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] &&
  [ "$(cat "$FAKE_CLAUDE")" = "GH_CONFIG_DIR=<unset> GH_TOKEN=<unset> GITHUB_TOKEN=<unset> KEEP=yes
[--resume]
[two words]
[]" ]
result $? "pap claude: GH_CONFIG_DIR, GH_TOKEN and GITHUB_TOKEN unset, the rest of the environment and every argument passed" "rc=$rc $(cat "$FAKE_CLAUDE" 2>&1)"

# --- the shim ------------------------------------------------------------------

mkrepo() { git init -q -b main "$1"; git -C "$1" remote add origin "https://github.com/example-owner/$(basename "$1").git"; }
mkrepo "$T/repo"
mkdir -p "$T/repo/scripts"
cp "$here/scripts/guard-branch.sh" "$T/repo/scripts/guard-branch.sh"
mkrepo "$T/plain"
shim_run() { # shim_run <dir> [env...]: gh through the shim, from <dir>
  dir="$1"; shift
  : > "$FAKE_LOG"
  (cd "$dir" && env PATH="$T/shim:$PATH" "$@" gh pr list 2>&1)
}
for d in repo plain; do
  out="$(shim_run "$T/$d" CLAUDECODE=1 GH_CONFIG_DIR="$T/xdg/gh-owner")"; rc=$?
  [ "$rc" = 1 ] && [ ! -s "$FAKE_LOG" ] &&
    printf '%s\n' "$out" | grep -qx 'gh (pap shim): GH_CONFIG_DIR is set in this agent shell, so gh would act with a stored sign-in; quit Claude Code and start it with pap claude (rule 23.4)'
  result $? "shim: CLAUDECODE and GH_CONFIG_DIR set ($d): refused naming pap claude, gh never runs" "rc=$rc $out $(cat "$FAKE_LOG")"
done
out="$(shim_run "$T/plain" GH_CONFIG_DIR="$T/xdg/gh-owner")"; rc=$?
[ "$rc" = 0 ] && grep -q "^GH_CONFIG_DIR=$T/xdg/gh-owner .*args=pr list$" "$FAKE_LOG"
result $? "shim: GH_CONFIG_DIR without CLAUDECODE (the owner's terminal) runs gh" "rc=$rc $out $(cat "$FAKE_LOG")"
out="$(shim_run "$T/plain" CLAUDECODE=1 GH_CONFIG_DIR=)"; rc=$?
[ "$rc" = 0 ] && grep -q 'args=pr list$' "$FAKE_LOG"
result $? "shim: an empty GH_CONFIG_DIR is not set" "rc=$rc $out"

# --- pap agent-owner init ------------------------------------------------------

owner="$T/xdg/gh-owner"
reset_gh() { # reset_gh: the default directory signed in, no owner directory, nothing recorded
  rm -rf "$owner" "$T/xdg/pap"
  : > "$T/default-gh/signed-in"
  : > "$FAKE_LOG"
  unset FAKE_LOGIN_FAIL FAKE_LOGIN_NOOP FAKE_SHARED
}
init() { out="$(printf '%s\n' "$1" | sh "$pap" agent-owner init 2>&1)"; rc=$?; }
recorded() { grep -qx "owner_gh_config_dir=$owner" "$conf" 2>/dev/null; }
logged_out() { grep -q 'args=auth logout' "$FAKE_LOG"; }

reset_gh
out="$(printf 'y\n' | CLAUDECODE=1 sh "$pap" agent-owner init 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'run this in your own terminal, not in an agent session' &&
  [ ! -s "$FAKE_LOG" ] && [ ! -e "$conf" ]
result $? "agent-owner init: refused in an agent shell, gh never runs, nothing recorded" "rc=$rc $out"

reset_gh
FAKE_LOGIN_FAIL=1; export FAKE_LOGIN_FAIL
init y
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'gh auth login did not finish; nothing else was changed' &&
  ! logged_out && [ -f "$T/default-gh/signed-in" ] && ! recorded
result $? "agent-owner init: a failed login records nothing and never signs the default directory out, even on y" "rc=$rc $out $(cat "$FAKE_LOG")"

reset_gh
FAKE_LOGIN_NOOP=1; export FAKE_LOGIN_NOOP
init y
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'is not signed in to github.com; nothing else was changed' &&
  ! logged_out && [ -f "$T/default-gh/signed-in" ] && ! recorded
result $? "agent-owner init: a login that leaves no sign-in is caught; nothing recorded, the default directory never signed out" "rc=$rc $out $(cat "$FAKE_LOG")"

reset_gh
init ''
[ "$rc" = 0 ] && ! logged_out && [ -f "$T/default-gh/signed-in" ]
result $? "agent-owner init: a bare Enter at the y/N question signs nothing out" "rc=$rc $out"

reset_gh
GH_TOKEN=ghs_agent; export GH_TOKEN
init n
unset GH_TOKEN
[ "$rc" = 0 ] && recorded && [ -f "$owner/signed-in" ] && [ -f "$T/default-gh/signed-in" ] && ! logged_out &&
  grep -qx "GH_CONFIG_DIR=$owner GH_TOKEN=<unset> GITHUB_TOKEN=<unset> CLAUDECODE=<unset> args=auth login --hostname github.com --insecure-storage" "$FAKE_LOG" &&
  printf '%s\n' "$out" | grep -qxF "  export GH_CONFIG_DIR=\"$owner\"" &&
  printf '%s\n' "$out" | grep -q 'the default directory left signed in' &&
  ! printf '%s\n' "$out" | grep -q home.nix
result $? "agent-owner init, n: logs in to the owner directory with GH_TOKEN unset and file storage, records it, leaves the default, prints the export" "rc=$rc $out $(cat "$FAKE_LOG")"
[ "$(stat -c %a "$owner" 2>/dev/null || stat -f %Lp "$owner")" = 700 ]
result $? "agent-owner init: the owner directory is mode 700"

reset_gh
init y
first_owner_ok="$(grep -n "^GH_CONFIG_DIR=$owner .*args=auth status --hostname github.com$" "$FAKE_LOG" | head -n 1 | cut -d: -f1)"
logout_at="$(grep -n 'args=auth logout' "$FAKE_LOG" | cut -d: -f1)"
[ "$rc" = 0 ] && [ -n "$first_owner_ok" ] && [ -n "$logout_at" ] && [ "$logout_at" -gt "$first_owner_ok" ] &&
  grep -qx 'GH_CONFIG_DIR=<unset> GH_TOKEN=<unset> GITHUB_TOKEN=<unset> CLAUDECODE=<unset> args=auth logout --hostname github.com' "$FAKE_LOG" &&
  [ ! -f "$T/default-gh/signed-in" ] && [ -f "$owner/signed-in" ] &&
  [ "$(sed -n "$((logout_at + 1))p" "$FAKE_LOG")" = "GH_CONFIG_DIR=$owner GH_TOKEN=<unset> GITHUB_TOKEN=<unset> CLAUDECODE=<unset> args=auth status --hostname github.com" ] &&
  printf '%s\n' "$out" | grep -q 'the default directory is signed out; .* still works'
result $? "agent-owner init, y: the default directory is signed out only after the owner's sign-in is confirmed, then confirmed again" "rc=$rc $out $(cat "$FAKE_LOG")"

reset_gh
FAKE_SHARED=1; export FAKE_SHARED
init y
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'lost its sign-in with the logout; run pap agent-owner init again'
result $? "agent-owner init: a logout that takes the owner's sign-in too is caught and named" "rc=$rc $out"
unset FAKE_SHARED

reset_gh
rm -f "$T/default-gh/signed-in"
init ''
[ "$rc" = 0 ] && ! logged_out && printf '%s\n' "$out" | grep -q "default directory holds no github.com sign-in"
result $? "agent-owner init: with the default directory already clean, nothing is asked or logged out" "rc=$rc $out"

reset_gh
mkdir -p "$T/nix/store/x-bash"
printf '# home-manager\n' > "$T/nix/store/x-bash/bashrc"
ln -s "$T/nix/store/x-bash/bashrc" "$HOME/.bashrc"
init n
rm "$HOME/.bashrc"
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qxF "  home.sessionVariables.GH_CONFIG_DIR = \"$owner\";" &&
  printf '%s\n' "$out" | grep -qxF "  export GH_CONFIG_DIR=\"$owner\"" && [ "$(cat "$T/nix/store/x-bash/bashrc")" = '# home-manager' ]
result $? "agent-owner init: a home-manager rc file gets the home.nix form too, and is never edited" "rc=$rc $out"

reset_gh
out="$(printf 'n\n' | sh "$pap" agent-owner init --dir relative/dir 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'must be an absolute path' && [ ! -s "$FAKE_LOG" ]
result $? "agent-owner init: a relative --dir is refused" "rc=$rc $out"
reset_gh
out="$(printf 'n\n' | sh "$pap" agent-owner init --dir "$T/my gh" 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx "owner_gh_config_dir=$T/my gh" "$conf" && [ -f "$T/my gh/signed-in" ] &&
  printf '%s\n' "$out" | grep -qxF "  export GH_CONFIG_DIR=\"$T/my gh\""
result $? "agent-owner init --dir: a path with a space is used, recorded and quoted" "rc=$rc $out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

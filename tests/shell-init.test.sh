#!/bin/sh
# shell-init.test.sh: tests for pap shell-init's claude function.
#
# Usage: sh tests/shell-init.test.sh
#
# Evals the printed function in bash and, when it is installed, zsh, with a
# stub claude that logs its arguments and GH_CONFIG_DIR, inside and outside a
# repository that adopts PAP (an executable scripts/guard-branch.sh). Prints
# one TAP-style line per case and exits 1 if any case fails. Needs git and
# bash; touches nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }
command -v bash >/dev/null 2>&1 || { printf 'Bail out! bash not found\n'; exit 1; }

# pwd -P: macOS's temporary directory is under a symlink.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T"
export HOME="$T/home" XDG_CONFIG_HOME="$T/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"

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

# Two copies of pap: the one that prints the function, and one to delete.
for d in self gone; do
  mkdir "$T/$d"
  cp -a "$here/bin" "$here/scripts" "$T/$d/"
done
pap="$T/self/bin/pap"

# $T/bin: a stub claude. $T/stale: a pap that must never run. $T/onpath: a
# pap whose usage names pap claude.
mkdir "$T/bin" "$T/stale" "$T/onpath"
cat > "$T/bin/claude" <<'S'
#!/bin/sh
echo "claude $# $* GH_CONFIG_DIR=${GH_CONFIG_DIR:-<unset>}" >> "$LOG"
S
cat > "$T/stale/pap" <<'S'
#!/bin/sh
[ $# -eq 0 ] || echo "stale pap $*" >> "$LOG"
S
cat > "$T/onpath/pap" <<'S'
#!/bin/sh
[ $# -gt 0 ] || { echo "Usage: pap claude [<claude args>...]" >&2; exit 64; }
echo "path pap $*" >> "$LOG"
S
chmod +x "$T/bin/claude" "$T/stale/pap" "$T/onpath/pap"
export LOG="$T/log"

# An adopting repository and a plain one.
mkdir -p "$T/adopt/scripts" "$T/plain"
git init -q "$T/adopt" && git init -q "$T/plain"
printf '#!/bin/sh\n' > "$T/adopt/scripts/guard-branch.sh"
chmod +x "$T/adopt/scripts/guard-branch.sh"

# run <shell> <init file> <dir> <PATH prefix>: source the init, call
# claude --resume "a b", print the log; stderr goes to $T/err.
run() {
  : > "$LOG"
  # shellcheck disable=SC2016 # $1 expands in the child shell
  (cd "$3" && PATH="$4:$T/bin:$PATH" "$1" -c '. "$1"; claude --resume "a b"' _ "$2" 2> "$T/err")
  cat "$LOG"
}
init="$T/init"
sh "$pap" shell-init bash > "$init"

ad="$T/xdg/gh-agent"
shells=bash
if command -v zsh >/dev/null 2>&1; then shells="bash zsh"; fi
for s in $shells; do
  out="$(run "$s" "$init" "$T/plain" "$T/stale")"
  [ "$out" = "claude 2 --resume a b GH_CONFIG_DIR=<unset>" ]
  result $? "$s, outside a PAP repository: plain claude, arguments intact" "$out"
  out="$(run "$s" "$init" "$T/adopt" "$T/stale")"
  [ "$out" = "claude 2 --resume a b GH_CONFIG_DIR=$ad" ]
  result $? "$s, in a PAP repository: pap claude through the recorded pap, not a stale one on PATH" "$out"
done
if ! command -v zsh >/dev/null 2>&1; then
  n=$((n + 1))
  printf 'ok %d - # SKIP zsh cases: zsh is not installed\n' "$n"
fi

sh "$T/gone/bin/pap" shell-init bash > "$T/init-gone"
rm -rf "$T/gone"
out="$(run bash "$T/init-gone" "$T/adopt" "$T/onpath")"
[ "$out" = "path pap claude --resume a b" ]
result $? "recorded pap gone: the pap on PATH that has pap claude" "$out"
out="$(run bash "$T/init-gone" "$T/adopt" "$T/stale")"
[ "$out" = "claude 2 --resume a b GH_CONFIG_DIR=<unset>" ] &&
  grep -q "^claude: this repository adopts PAP but $T/gone/bin/pap is gone" "$T/err"
result $? "recorded pap gone, no pap claude on PATH: a warning and plain claude" "$out $(cat "$T/err")"

[ "$(sh "$pap" shell-init bash)" = "$(sh "$pap" shell-init zsh | sed 's/shell-init zsh/shell-init bash/')" ]
result $? "bash and zsh get the same function"
sh "$pap" shell-init fish > /dev/null 2> "$T/err"
rc=$?
[ "$rc" = 64 ] && grep -q 'pap shell-init bash|zsh' "$T/err"
result $? "an unknown shell is a usage error" "$rc $(cat "$T/err")"

printf '1..%d\n' "$n"
[ "$failed" -eq 0 ]

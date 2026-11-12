#!/bin/sh
# pap.test.sh: tests for bin/pap init, sync and doctor.
#
# Usage: sh tests/pap.test.sh
#
# Builds a pap source repository in a temporary directory from this
# checkout's bin/, scripts/ and templates/, tagged v0.1.0, then v0.2.0 (a
# line appended to the base .editorconfig and a new file), then v0.3.0 (the
# [*] indent_size changed). pap runs against it through PAP_SOURCE, with a
# stub mise on PATH that logs what it is asked to do and answers
# `ls --current --json` from a fixture. Prints one TAP-style line per case
# and exits 1 if any case fails. Needs git; touches nothing outside the
# temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
# git looks for no repository above $T.
export GIT_CEILING_DIRECTORIES="$T"
# The machine's system git config (macOS runners set an osxkeychain
# helper) is not this suite's to read.
export GIT_CONFIG_NOSYSTEM=1

# The pap under test: a plain copy, neither a release nor a git checkout, so
# the checkout's own tags (a release tag on main) cannot change what it does.
mkdir "$T/self"
cp -a "$here/bin" "$here/scripts" "$here/templates" "$here/.claude-plugin" "$T/self/"
pap="$T/self/bin/pap"

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
g() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

# The pap source, three tagged versions.
mkdir "$T/src"
cp -a "$here/bin" "$here/scripts" "$here/templates" "$T/src/"
git init -q -b main "$T/src"
g -C "$T/src" add -A && g -C "$T/src" commit -qm v0.1.0 && g -C "$T/src" tag v0.1.0
printf '\n# Added in v0.2.0.\n' >> "$T/src/templates/base/.editorconfig"
echo new > "$T/src/templates/base/.config/added-in-v0.2.0"
g -C "$T/src" add -A && g -C "$T/src" commit -qm v0.2.0 && g -C "$T/src" tag v0.2.0
awk '!d && /^indent_size = 2$/ { $0 = "indent_size = 4"; d = 1 } { print }' \
  "$T/src/templates/base/.editorconfig" > "$T/ec" && mv "$T/ec" "$T/src/templates/base/.editorconfig"
g -C "$T/src" add -A && g -C "$T/src" commit -qm v0.3.0 && g -C "$T/src" tag v0.3.0

# A stub mise: logs every call, answers doctor's two questions.
mkdir "$T/stub"
cat > "$T/stub/mise" <<'EOF'
#!/bin/sh
echo "$*" >> "$STUB_LOG"
case "$*" in
  --version) echo "2026.5.12 linux-x64" ;;
  "trust --show") echo "$PWD: trusted" ;;
  "ls --current --json") cat "$STUB_LS" ;;
esac
EOF
chmod +x "$T/stub/mise"
export STUB_LOG="$T/mise.log" STUB_LS="$T/ls.json" PAP_SOURCE="$T/src"
export MISE_DATA_DIR="$T/misedata"
# Decision 0023's agent app, as doctor sees it: a key in a fake keyring, a
# client id in a config under $T, GitHub at an address only the fake curl
# answers, and no global git config of the machine's.
export XDG_CONFIG_HOME="$T/xdg" XDG_RUNTIME_DIR="$T/run" FAKE_KEYRING="$T/keyring" FAKE_GH="$T/fakegh"
# Claude Code's own files are read from here, never from the machine's: the
# plugin command pap doctor prints depends on them.
export CLAUDE_CONFIG_DIR="$T/claude"
mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
export PAP_GITHUB_API=http://github.invalid GIT_CONFIG_GLOBAL="$T/gitconfig"
unset REMOTE_CONTAINERS CLAUDECODE GH_CONFIG_DIR GH_TOKEN GITHUB_TOKEN 2>/dev/null || true
mkdir -p "$T/xdg/pap" "$T/run" "$T/fakegh" "$T/xdg/gh" "$T/xdg/gh-agent"
# Rule 23.4: the owner signed in in gh's default directory, token in the
# keyring (hosts.yml names the user only); the agent's directory empty.
printf 'client_id=Iv1.example\n' > "$T/xdg/pap/agent.conf"
printf 'github.com:\n    user: example-owner\n' > "$T/xdg/gh/hosts.yml"
chmod 700 "$T/xdg/gh-agent"
printf 'not a real key\n' > "$FAKE_KEYRING"
: > "$GIT_CONFIG_GLOBAL"
PATH="$T/stub:$(printf '%s' "$PATH" | tr ':' '\n' | grep -v 'mise/shims' | paste -sd: -)"
export PATH

run() { (cd "$T/app" && sh "$pap" "$@" 2>&1); }

# --- init on an empty repository ---------------------------------------------

git init -q -b main "$T/app"
out="$(run init --version 0.1.0 base dotnet go)"; rc=$?
result "$rc" "init: exits 0 on an empty repository" "$out"
[ -f "$T/app/.editorconfig" ] && [ -f "$T/app/global.json" ] && [ -f "$T/app/.golangci.yml" ]
result $? "init: every layer's files written"
[ ! -e "$T/app/README.md" ] && [ -f "$T/app/scripts/guard-branch.sh" ] && [ ! -L "$T/app/scripts/guard-branch.sh" ] &&
  [ -x "$T/app/scripts/shim/gh" ] && [ ! -L "$T/app/scripts/shim/gh" ]
result $? "init: layer READMEs left out, symlinks dereferenced"
grep -qx 'version = "0.1.0"' "$T/app/.config/pap.toml" &&
  grep -qx 'layers = \["base", "dotnet", "go"\]' "$T/app/.config/pap.toml"
result $? "init: version and layers recorded in .config/pap.toml" "$(cat "$T/app/.config/pap.toml" 2>&1)"
[ "$(tr '\n' ';' < "$STUB_LOG")" = "trust;install;run setup;" ]
result $? "init: runs mise trust, install, run setup in order" "$(cat "$STUB_LOG")"
printf '%s\n' "$out" | grep -q 'No GitHub origin yet' &&
  printf '%s\n' "$out" | grep -q 'No product/invariants.md yet'
result $? "init: says what to do next about the repository and CODEOWNERS" "$out"
[ ! -e "$T/app/.config/mise/conf.d/pap.toml" ]
result $? "init: an unreleased pap writes no pin for itself"

# A released pap: its own tree at v0.1.0 with a VERSION file, no fetch.
cp -a "$T/src" "$T/rel" && git -C "$T/rel" checkout -q v0.1.0 && echo 0.1.0 > "$T/rel/VERSION"
git init -q -b main "$T/relapp"
out="$(cd "$T/relapp" && PAP_SOURCE=/nonexistent sh "$T/rel/bin/pap" init base 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -q '"github:blairforce1/pap" = { version = "0.1.0", asset_pattern = "pap-\*.tar.gz" }' \
  "$T/relapp/.config/mise/conf.d/pap.toml"
result $? "init: a released pap uses its own templates and pins itself" "$out"

g -C "$T/app" add -A && g -C "$T/app" commit -qm init
out="$(run init --version 0.1.0 base dotnet go)"; rc=$?
[ "$rc" = 0 ] && [ -z "$(git -C "$T/app" status --porcelain)" ]
result $? "init: running it again changes nothing" "$out$(git -C "$T/app" status --porcelain)"

echo dirty > "$T/app/dirty"
out="$(run sync --version 0.2.0)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'uncommitted changes'
result $? "sync: refuses a dirty working tree" "$out"
rm "$T/app/dirty"

# --- sync keeps a local edit and brings the template's change --------------

awk '{ print } /^root = true$/ { print "# Local edit: kept by sync." }' \
  "$T/app/.editorconfig" > "$T/ec" && mv "$T/ec" "$T/app/.editorconfig"
g -C "$T/app" commit -qam "local edit"
out="$(run sync --version 0.2.0)"; rc=$?
result "$rc" "sync: exits 0 on a clean merge" "$out"
grep -q '^# Local edit: kept by sync\.$' "$T/app/.editorconfig"
result $? "sync: the local edit survived"
grep -q '^# Added in v0\.2\.0\.$' "$T/app/.editorconfig" && [ -f "$T/app/.config/added-in-v0.2.0" ]
result $? "sync: the template's change and new file arrived"
printf '%s\n' "$out" | grep -qx 'M  .editorconfig' && printf '%s\n' "$out" | grep -qx 'A  .config/added-in-v0.2.0'
result $? "sync: lists what it merged and added" "$out"
grep -qx 'version = "0.2.0"' "$T/app/.config/pap.toml"
result $? "sync: records the new version"
[ "$(git -C "$T/app" status --porcelain | wc -l)" -eq 3 ]
result $? "sync: touches only the merged file, the new file and the record" "$(git -C "$T/app" status --porcelain)"

# --- a clash surfaces as conflict markers ----------------------------------

g -C "$T/app" add -A && g -C "$T/app" commit -qm "sync v0.2.0"
awk '!d && /^indent_size = 2$/ { $0 = "indent_size = 3"; d = 1 } { print }' \
  "$T/app/.editorconfig" > "$T/ec" && mv "$T/ec" "$T/app/.editorconfig"
g -C "$T/app" commit -qam "local indent"
out="$(run sync --version 0.3.0)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qx 'C  .editorconfig'
result $? "conflict: exits 1 and names the file" "$out"
grep -qx '<<<<<<< .editorconfig (here)' "$T/app/.editorconfig" &&
  grep -qx 'indent_size = 3' "$T/app/.editorconfig" &&
  grep -qx '=======' "$T/app/.editorconfig" &&
  grep -qx 'indent_size = 4' "$T/app/.editorconfig" &&
  grep -qx '>>>>>>> template v0.3.0' "$T/app/.editorconfig"
result $? "conflict: ordinary git conflict markers, both sides kept" "$(grep -n -A4 '<<<<<<<' "$T/app/.editorconfig")"
grep -qx 'version = "0.3.0"' "$T/app/.config/pap.toml"
result $? "conflict: the new version is recorded, so the next sync merges from it"
g -C "$T/app" checkout -q -- .

# --- unreleased: pap run from a checkout with no release tag ----------------

printf '# Added after v0.3.0, unreleased.\n' >> "$T/src/templates/base/.gitignore"
g -C "$T/src" commit -qam unreleased
sha_u="$(git -C "$T/src" rev-parse HEAD)"
git init -q -b main "$T/unrel"
out="$(cd "$T/unrel" && sh "$T/src/bin/pap" init base 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'version = "unreleased"' "$T/unrel/.config/pap.toml" &&
  grep -qx "commit = \"$sha_u\"" "$T/unrel/.config/pap.toml" &&
  grep -qx '# Added after v0.3.0, unreleased.' "$T/unrel/.gitignore"
result $? "unreleased: init applies the checkout's commit and records it" "$out$(cat "$T/unrel/.config/pap.toml" 2>&1)"
[ ! -e "$T/unrel/.config/mise/conf.d/pap.toml" ] && printf '%s\n' "$out" | grep -q "Recorded unreleased ${sha_u%"${sha_u#????????????}"}"
result $? "unreleased: says so, and writes no pin" "$out"

g -C "$T/unrel" add -A && g -C "$T/unrel" commit -qm init
out="$(cd "$T/unrel" && sh "$pap" sync --version 0.3.0 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'version = "0.3.0"' "$T/unrel/.config/pap.toml" &&
  ! grep -q '^commit' "$T/unrel/.config/pap.toml" &&
  ! grep -q 'unreleased' "$T/unrel/.gitignore"
result $? "unreleased: sync fetches the recorded commit as the base and leaves the unreleased state" \
  "$out$(cat "$T/unrel/.config/pap.toml" 2>&1)"

g -C "$T/unrel" add -A && g -C "$T/unrel" commit -qm sync
printf 'version = "unreleased"\ncommit = "%s"\nlayers = ["base"]\n' 0123456789012345678901234567890123456789 > "$T/unrel/.config/pap.toml"
g -C "$T/unrel" commit -qam "a commit never pushed"
out="$(cd "$T/unrel" && sh "$pap" sync --version 0.2.0 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'needs its commit pushed'
result $? "unreleased: sync refuses a recorded commit it cannot fetch" "$out"

echo dirty >> "$T/src/templates/base/.editorconfig"
git init -q -b main "$T/unrel2"
out="$(cd "$T/unrel2" && sh "$T/src/bin/pap" init base 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'uncommitted template changes'
result $? "unreleased: init refuses a checkout with uncommitted template changes" "$out"
g -C "$T/src" checkout -q -- .

# --- the recorded commit: the merge-base with origin/main -------------------

# init_from <pap checkout> <app>: init base in a new repository <app>.
init_from() {
  git init -q -b main "$T/$2"
  out="$(cd "$T/$2" && sh "$T/$1/bin/pap" init base 2>&1)"; rc=$?
}
recorded() { sed -n 's/^commit = "\(.*\)"$/\1/p' "$T/$1/.config/pap.toml"; }

git clone -q "$T/src" "$T/co"
init_from co onmain
[ "$rc" = 0 ] && [ "$(recorded onmain)" = "$sha_u" ] && ! printf '%s\n' "$out" | grep -q warning
result $? "recorded commit: init on main records HEAD" "$out"

g -C "$T/co" switch -qc change/x
printf '# On the branch only.\n' >> "$T/co/templates/base/trivy.yaml"
g -C "$T/co" commit -qam branch
init_from co onbranch
[ "$rc" = 0 ] && [ "$(recorded onbranch)" = "$sha_u" ] &&
  grep -qx '# On the branch only.' "$T/onbranch/trivy.yaml" &&
  printf '%s\n' "$out" | grep -q 'Note: this checkout changes the templates'
result $? "recorded commit: init on a branch ahead of main applies HEAD and records the merge-base" "$out"

git clone -q "$T/co" "$T/co-noorigin" && git -C "$T/co-noorigin" remote remove origin
sha_b="$(git -C "$T/co-noorigin" rev-parse HEAD)"
init_from co-noorigin noorigin
[ "$rc" = 0 ] && [ "$(recorded noorigin)" = "$sha_b" ] &&
  printf '%s\n' "$out" | grep -q 'warning: .* has no origin/main'
result $? "recorded commit: init with no origin records HEAD and warns" "$out"

# sync from each: the base is the recorded commit, fetched from PAP_SOURCE
# (the merge-base and main's HEAD) or from a checkout that has it.
for app in onmain onbranch; do
  g -C "$T/$app" add -A && g -C "$T/$app" commit -qm init
  out="$(cd "$T/$app" && sh "$pap" sync --version 0.3.0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && grep -qx 'version = "0.3.0"' "$T/$app/.config/pap.toml" &&
    ! grep -q 'unreleased' "$T/$app/.gitignore"
  result $? "recorded commit: sync from $app's record to v0.3.0" "$out"
done
grep -qx '# On the branch only.' "$T/onbranch/trivy.yaml"
result $? "recorded commit: the branch's template change past the merge-base is kept as a local edit"
g -C "$T/noorigin" add -A && g -C "$T/noorigin" commit -qm init
out="$(cd "$T/noorigin" && PAP_SOURCE="$T/co-noorigin" sh "$pap" sync --version 0.3.0 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'version = "0.3.0"' "$T/noorigin/.config/pap.toml" &&
  ! grep -q 'On the branch only' "$T/noorigin/trivy.yaml"
result $? "recorded commit: sync from a HEAD recorded with no origin" "$out"

# --- doctor ------------------------------------------------------------------

# ls.json <installed> <active version>: a fixture in mise's --json shape,
# one tool pinned here and one pinned globally, which doctor ignores.
ls_json() {
  cat > "$STUB_LS" <<EOF
{
  "lefthook": [
    {
      "version": "$2",
      "requested_version": "2.1.14",
      "install_path": "/x/lefthook/$2",
      "source": {
        "type": "mise.toml",
        "path": "$T/app/.config/mise/conf.d/base.toml"
      },
      "installed": $1,
      "active": true
    }
  ],
  "node": [
    {
      "version": "24.0.0",
      "requested_version": "22",
      "install_path": "/x/node/24.0.0",
      "source": {
        "type": "mise.toml",
        "path": "$HOME/.config/mise/config.toml"
      },
      "installed": false,
      "active": true
    }
  ]
}
EOF
}
# doctor runs on a PATH of stubs and links, never the machine's own tools:
# $T/stub (mise), $T/tools (gh, jq, claude, flock), $T/linux (a uname that
# says Linux, so the hints are the same on a macOS runner) and $T/sys, links
# to the system commands pap itself needs. A case drops a directory to make
# a tool missing. No stub reaches the network.
mkdir "$T/tools" "$T/linux" "$T/mac" "$T/apt" "$T/dnf" "$T/sys" "$T/sysnogit" "$T/forbid"
cat > "$T/tools/gh" <<'EOF'
#!/bin/sh
echo "gh $*" >> "$STUB_LOG"
case "$*" in
  "auth status") exit "${STUB_GH_AUTH:-0}" ;;
  # gh's default directory: signed in unless STUB_GH_DEFAULT=1. Any other
  # directory: not signed in.
  "auth status --hostname github.com")
    [ -z "${GH_CONFIG_DIR:-}" ] || exit 1
    exit "${STUB_GH_DEFAULT:-0}" ;;
esac
EOF
cat > "$T/tools/claude" <<'EOF'
#!/bin/sh
echo "claude $*" >> "$STUB_LOG"
case "$*" in
  "plugin list")
    [ "${STUB_PLUGINS-x}" != fail ] || exit 1
    printf '%s\n' "${STUB_PLUGINS-  > pap@blairforce1-pap
  > spec-review@blairforce1-pap}" ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$T/tools/jq"
# The keyrings: secret-tool reads the fake keyring; security answers its
# base64, as pap stores it on macOS. openssl is the machine's (it decodes
# that base64 and touches nothing else); curl is never reached here.
cat > "$T/tools/secret-tool" <<'EOF'
#!/bin/sh
[ "$1" = lookup ] && [ -s "$FAKE_KEYRING" ] && cat "$FAKE_KEYRING"
EOF
cat > "$T/tools/security" <<'EOF'
#!/bin/sh
[ -s "$FAKE_KEYRING" ] && openssl base64 -A < "$FAKE_KEYRING"
EOF
printf '#!/bin/sh\nexit 7\n' > "$T/tools/curl"
printf '#!/bin/sh\nexit 0\n' > "$T/tools/flock"
printf '#!/bin/sh\necho Linux\n' > "$T/linux/uname"
printf '#!/bin/sh\necho Darwin\n' > "$T/mac/uname"
printf '#!/bin/sh\nexit 0\n' > "$T/apt/apt-get"
printf '#!/bin/sh\nexit 0\n' > "$T/dnf/dnf"
# What doctor --fix must never run, each logged if it is.
# shellcheck disable=SC2016 # $* and $STUB_LOG expand in the stub, not here.
for f in sudo apt-get apt dnf brew; do
  printf '#!/bin/sh\necho "FORBIDDEN %s $*" >> "$STUB_LOG"\n' "$f" > "$T/forbid/$f"
done
chmod +x "$T"/tools/* "$T"/linux/* "$T"/mac/* "$T"/apt/* "$T"/dnf/* "$T"/forbid/*
ln -s "$(command -v openssl)" "$T/tools/openssl"
for c in sh git cut grep awk sed cat head tr dirname basename env date id mkdir chmod mv ls rm mktemp tail stat; do
  ln -s "$(command -v "$c")" "$T/sys/$c"
  [ "$c" = git ] || ln -s "$(command -v "$c")" "$T/sysnogit/$c"
done
dpath="$T/stub:$T/tools:$T/linux:$T/sys"
doctor() { (cd "$T/app" && env -u MISE_SHELL PATH="$dpath" "$@" sh "$pap" doctor 2>&1); }
fixdoctor() { (cd "$T/app" && env -u MISE_SHELL PATH="$dpath" "$@" sh "$pap" doctor --fix 2>&1); }

ls_json false 2.1.14
out="$(doctor)"; rc=$?
[ "$rc" = 1 ] &&
  printf '%s\n' "$out" | grep -q 'missing  mise activated' &&
  printf '%s\n' "$out" | grep -q 'missing  pre-commit hook installed' &&
  printf '%s\n' "$out" | grep -q 'missing  pre-push hook installed' &&
  printf '%s\n' "$out" | grep -q 'missing  blame.ignoreRevsFile set' &&
  printf '%s\n' "$out" | grep -q 'missing  lefthook 2.1.14'
result $? "doctor, fresh clone: mise not activated, no hooks, tools missing; exits 1" "$out"
printf '%s\n' "$out" | grep -q node
[ $? = 1 ]
result $? "doctor: ignores tools pinned outside the repository" "$out"

hooks="$(git -C "$T/app" rev-parse --git-path hooks)"
case "$hooks" in /*) ;; *) hooks="$T/app/$hooks" ;; esac
mkdir -p "$hooks"
printf '#!/bin/sh\n# lefthook\n' > "$hooks/pre-commit"
printf '#!/bin/sh\n# lefthook\n' > "$hooks/pre-push"
git -C "$T/app" config blame.ignoreRevsFile .git-blame-ignore-revs
ls_json true 2.1.14
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'This machine is ready' &&
  ! printf '%s\n' "$out" | grep -Eq '^  (missing|drift)'
result $? "doctor, set up: every item ok; exits 0" "$out"
out="$(doctor PATH="$MISE_DATA_DIR/shims:$dpath")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'ok       mise activated  (shims on PATH)'
result $? "doctor: mise shims on PATH count as activated" "$out"

# The main checkout (decision 0027, features/cycle-pr-guard.feature), read
# while every other item is ok, so a drift here is the one that exits 1.
doctor_in() { d_in="$1"; shift; (cd "$d_in" && env -u MISE_SHELL PATH="$dpath" MISE_SHELL=bash "$@" sh "$pap" doctor 2>&1); }
bad() { printf '%s\n' "$out" | grep -Ec '^  (missing|drift)'; }
out="$(doctor_in "$T/app")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx '  ok       main checkout on main'
result $? "cycle-pr-guard-10: doctor in the main checkout, on main: ok" "$out"
git -C "$T/app" switch -q -c change/add-thing
out="$(doctor_in "$T/app")"; rc=$?
[ "$rc" = 1 ] && [ "$(bad)" = 1 ] &&
  printf '%s\n' "$out" | grep -qxF "  drift    main checkout on main  ($T/app is on change/add-thing; once no session is using it: git switch main)"
result $? "cycle-pr-guard-10: on change/add-thing: drift, naming the branch and git switch main; exits 1" "$out"
git -C "$T/app" switch -q --detach
out="$(doctor_in "$T/app")"; rc=$?
[ "$rc" = 1 ] && [ "$(bad)" = 1 ] &&
  printf '%s\n' "$out" | grep -qF "  drift    main checkout on main  ($T/app is detached"
result $? "cycle-pr-guard-10: at a detached commit: drift, saying it is detached; exits 1" "$out"
git -C "$T/app" switch -q -c change/other
git -C "$T/app" worktree add -q "$T/app-wt" change/add-thing
out="$(doctor_in "$T/app-wt")"; rc=$?
[ "$rc" = 1 ] && [ "$(bad)" = 1 ] &&
  printf '%s\n' "$out" | grep -qF "  drift    main checkout on main  ($T/app is on change/other;"
result $? "cycle-pr-guard-10: in the linked work tree, the main checkout on change/other: drift, naming the branch and the main checkout's path; exits 1" "$out"
git -C "$T/app" switch -q main
out="$(doctor_in "$T/app-wt")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx '  ok       main checkout on main'
result $? "cycle-pr-guard-10: in the linked work tree, itself on a change branch, with the main checkout on main: ok" "$out"
git -C "$T/app" worktree remove --force "$T/app-wt"
git -C "$T/app" branch -q -D change/add-thing change/other
git init -q -b main "$T/plain"
g -C "$T/plain" commit -q --allow-empty -m init
git -C "$T/plain" switch -q -c change/adopt-thing
out="$(doctor_in "$T/plain")"
printf '%s\n' "$out" | grep -qx '  skipped  main checkout on main  (this repository does not adopt PAP)'
result $? "cycle-pr-guard-10: on change/adopt-thing in a repository that does not adopt PAP: skipped" "$out"
mkdir -p "$T/norepo"
out="$(doctor_in "$T/norepo" GIT_CEILING_DIRECTORIES="$T")"; rc=$?
[ "$rc" -le 1 ] && printf '%s\n' "$out" | grep -qx '  skipped  main checkout on main  (not in a git repository)' &&
  printf '%s\n' "$out" | grep -qx '  skipped  git hooks and settings  (not in a git repository)' &&
  printf '%s\n' "$out" | grep -qx 'shell' && ! printf '%s\n' "$out" | grep -q 'not inside a git repository'
result $? "cycle-pr-guard-11: doctor in a directory in no git repository reads the machine and reports the main checkout as skipped" "exit $rc; $out"

# A branch whose upstream was deleted, as after a merged pull request:
# reported with the tidy hint, and not a failure.
git -C "$T/app" remote add origin "$T/nowhere.git"
git -C "$T/app" branch -q stale
git -C "$T/app" config branch.stale.remote origin
git -C "$T/app" config branch.stale.merge refs/heads/stale
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] &&
  printf '%s\n' "$out" | grep -q 'stale    1 branch(es) with a gone upstream  (run mise run tidy)'
result $? "doctor: counts branches with a gone upstream, suggests tidy; exits 0" "$out"

printf '#!/bin/sh\nexit 0\n' > "$hooks/pre-push"
ls_json true 2.1.13
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 1 ] &&
  printf '%s\n' "$out" | grep -q "drift    pre-push hook installed" &&
  printf '%s\n' "$out" | grep -q 'drift    lefthook 2.1.14  (active is 2.1.13)' &&
  printf '%s\n' "$out" | grep -q 'ok       pre-commit hook installed'
result $? "doctor, drifted: a foreign hook and an active version off its pin; exits 1" "$out"

# --- doctor: the sign-ins (rule 23.4) ------------------------------------------

printf '#!/bin/sh\n# lefthook\n' > "$hooks/pre-push"
ls_json true 2.1.14
has() { printf '%s\n' "$out" | grep -qF "$1"; }
ad="$T/xdg/gh-agent"
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] && has "ok       your gh sign-in in $T/xdg/gh" &&
  has "ok       your gh token in the keyring  (none in $T/xdg/gh/hosts.yml)" &&
  has "ok       agent gh directory $ad  (mode 700, no sign-in)" &&
  has "ok       this shell  (your terminal; gh uses its default directory)"
result $? "doctor, your terminal: signed in, token in the keyring, agent directory empty and 700; exits 0" "$out"
out="$(doctor MISE_SHELL=bash STUB_GH_DEFAULT=1)"; rc=$?
[ "$rc" = 1 ] && has "missing  your gh sign-in in $T/xdg/gh  (in your own terminal: gh auth login)"
result $? "doctor: gh's default directory not signed in is missing" "$out"
printf 'github.com:\n    oauth_token: fake\n    user: example-owner\n' > "$T/xdg/gh/hosts.yml"
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] && has "warn     your gh token in the keyring  (it is in plain text in $T/xdg/gh/hosts.yml: gh auth logout --hostname github.com, then gh auth login without --insecure-storage)"
result $? "doctor: a plain-text token in hosts.yml is a warning naming the fix" "$out"
printf 'github.com:\n    user: example-owner\n' > "$T/xdg/gh/hosts.yml"
chmod 755 "$ad"
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 1 ] && has "drift    agent gh directory $ad  (mode 755, not 700: chmod 700 '$ad')"
result $? "doctor: an agent directory not 700 is drift" "$out"
chmod 700 "$ad"
printf 'github.com:\n    user: example-owner\n' > "$ad/hosts.yml"
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 1 ] && has "drift    agent gh directory $ad  (it holds a sign-in, which it never should: rm '$ad/hosts.yml')"
result $? "doctor: an agent directory holding a sign-in is drift" "$out"
rm "$ad/hosts.yml"; rmdir "$ad"
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 1 ] && has "missing  agent gh directory $ad  (start Claude Code with pap claude, which creates it)"
result $? "doctor: no agent directory is missing, naming pap claude" "$out"
mkdir "$ad"; chmod 700 "$ad"
out="$(doctor MISE_SHELL=bash CLAUDECODE=1 GH_CONFIG_DIR="$ad")"
has "ok       this shell  (an agent shell started by pap claude)" &&
  has "skipped  your gh sign-in in $T/xdg/gh  (checked only from your own terminal, never from an agent shell)"
result $? "doctor, an agent shell from pap claude: ok, and your sign-in is not read" "$out"
out="$(doctor MISE_SHELL=bash CLAUDECODE=1)"; rc=$?
[ "$rc" = 1 ] && has "drift    this shell  (an agent shell not started by pap claude (GH_CONFIG_DIR is unset); quit and run pap claude)"
result $? "doctor, an agent shell not started by pap claude is drift" "$out"
out="$(doctor MISE_SHELL=bash CLAUDECODE=1 GH_CONFIG_DIR="$ad")"; rc=$?
[ "$rc" = 1 ] && has "drift    gh is the shim  (gh is $T/tools/gh, past the pap-agent shim; quit and run pap claude)"
result $? "doctor, an agent shell whose gh is not the shim is drift, naming pap claude" "$out"
out="$(doctor MISE_SHELL=bash SHELL=/bin/zsh)"
has "warn     claude is pap's function  (not in this shell, so claude in a PAP repository starts without pap claude and the guard refuses its GitHub calls: add eval \"\$(pap shell-init zsh)\" in ~/.zshrc)"
result $? "doctor: no shell-init in this shell warns, with the eval line for the user's shell" "$out"
out="$(doctor MISE_SHELL=bash PAP_SHELL_INIT="$pap")"
has "ok       claude is pap's function  ($pap)"
result $? "doctor: shell-init's PAP_SHELL_INIT names a pap that exists: ok" "$out"
# An upgrade leaves the open terminals recording the old pap: doctor run by
# a released pap, 0.18.0, against recorded paps that print other versions.
cp -a "$T/self" "$T/drel" && echo 0.18.0 > "$T/drel/VERSION"
for v in 0.9.9 0.18.0 0.19.0 unreleased; do
  mkdir -p "$T/rec/$v"
  # shellcheck disable=SC2016 # $1 is the stub's own
  printf '#!/bin/sh\n[ "$1" = version ] && echo "%s"\n' "$v" > "$T/rec/$v/pap"
done
reldoctor() { (cd "$T/app" && env -u MISE_SHELL PATH="$dpath" MISE_SHELL=bash PAP_SHELL_INIT="$1" sh "$2" doctor 2>&1); }
out="$(reldoctor "$T/rec/0.9.9/pap" "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 1 ] && has "drift    claude is pap's function  (this shell recorded $T/rec/0.9.9/pap, pap 0.9.9, and this pap is 0.18.0: open a new terminal, or run eval \"\$(pap shell-init bash)\" again)"
result $? "doctor: shell-init's pap older than this pap is drift, with both versions and the fix" "$out"
for v in 0.18.0 0.19.0 unreleased; do
  out="$(reldoctor "$T/rec/$v/pap" "$T/drel/bin/pap")"
  has "ok       claude is pap's function  ($T/rec/$v/pap)"
  result $? "doctor: shell-init's pap at $v, this pap 0.18.0: ok" "$out"
done
out="$(reldoctor "$T/rec/0.9.9/pap" "$pap")"
has "ok       claude is pap's function  ($T/rec/0.9.9/pap)"
result $? "doctor: an unreleased pap never calls a recorded release old" "$out"
out="$(doctor MISE_SHELL=bash PAP_SHELL_INIT="$T/gone/pap")"
has "warn     claude is pap's function  (it runs $T/gone/pap, which is gone"
result $? "doctor: shell-init's pap gone warns" "$out"
out="$(doctor MISE_SHELL=bash CLAUDECODE=1 GH_CONFIG_DIR="$ad")"
has "skipped  claude is pap's function  (checked only from your own terminal, never from an agent shell)"
result $? "doctor, an agent shell: the shell function is not checked" "$out"
out="$(doctor MISE_SHELL=bash CLAUDECODE=1 GH_CONFIG_DIR="$ad" PATH="$here/scripts/shim:$dpath")"
has "ok       gh is the shim  ($here/scripts/shim/gh)"
result $? "doctor, an agent shell whose gh is the shim: ok" "$out"

# --- doctor: the tools, and their install hints ------------------------------

# Back to set up, so each case below fails on its one missing tool.
printf '#!/bin/sh\n# lefthook\n' > "$hooks/pre-push"
ls_json true 2.1.14
out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] &&
  printf '%s\n' "$out" | grep -q 'ok       gh signed in' &&
  printf '%s\n' "$out" | grep -q 'ok       jq on PATH' &&
  printf '%s\n' "$out" | grep -q 'ok       pap plugin installed' &&
  printf '%s\n' "$out" | grep -q 'ok       spec-review plugin installed' &&
  printf '%s\n' "$out" | grep -q 'ok       flock on PATH'
result $? "doctor: gh signed in, jq, claude, both plugins and flock all ok; exits 0" "$out"

# missing <label> <expected line> [env...]: doctor on a PATH without one
# tool exits 1 and prints the line.
missing() {
  label="$1" line="$2"; shift 2
  out="$(doctor MISE_SHELL=bash "$@")"; rc=$?
  [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qF "$line"
  result $? "$label" "$out"
}
mkdir "$T/nogh" "$T/nojq" "$T/noclaude" "$T/noflock"
for t in gh jq claude flock secret-tool security openssl curl; do
  for d in nogh nojq noclaude noflock; do
    [ "$d" = "no$t" ] || cp -P "$T/tools/$t" "$T/$d/"
  done
done

missing "doctor: gh missing, with mise install and the apt command" \
  'missing  gh on PATH  (run mise install, or sudo apt install gh)' PATH="$T/stub:$T/nogh:$T/apt:$T/linux:$T/sys"
printf '%s\n' "$out" | grep -qF 'skipped  gh signed in  (no gh)'
result $? "doctor: gh missing skips the sign-in check" "$out"
missing "doctor: gh not signed in names gh auth login" \
  'missing  gh signed in  (run gh auth login)' STUB_GH_AUTH=1
missing "doctor: jq missing, with the dnf command" \
  'missing  jq on PATH  (run mise install, or sudo dnf install jq)' PATH="$T/stub:$T/nojq:$T/dnf:$T/linux:$T/sys"
missing "doctor: jq missing on macOS, with the brew command" \
  'missing  jq on PATH  (run mise install, or brew install jq)' PATH="$T/stub:$T/nojq:$T/mac:$T/sys"
missing "doctor: jq missing on a Linux with neither apt nor dnf, with a link" \
  'missing  jq on PATH  (run mise install, or https://jqlang.org/download/)' PATH="$T/stub:$T/nojq:$T/linux:$T/sys"
missing "doctor: claude missing, with the native installer" \
  'missing  claude on PATH  (curl -fsSL https://claude.ai/install.sh | bash)' PATH="$T/stub:$T/noclaude:$T/linux:$T/sys"
printf '%s\n' "$out" | grep -qF 'skipped  pap plugins installed  (no claude)'
result $? "doctor: claude missing skips the plugin check" "$out"
missing "doctor: claude missing on macOS, with the brew cask" \
  'missing  claude on PATH  (brew install --cask claude-code, or curl -fsSL https://claude.ai/install.sh | bash)' PATH="$T/stub:$T/noclaude:$T/mac:$T/sys"
missing "doctor: spec-review plugin missing, with the install command" \
  'missing  spec-review plugin installed  (claude plugin install spec-review --marketplace blairforce1/pap)' \
  STUB_PLUGINS='  > pap@blairforce1-pap'
missing "doctor: pap plugin missing, with the install command" \
  'missing  pap plugin installed  (claude plugin install pap --marketplace blairforce1/pap)' \
  STUB_PLUGINS='  > spec-review@blairforce1-pap'
# The command is the one that works on this machine, read from Claude Code's
# own files: a marketplace it knows is not added again, and a plugin its
# file holds is updated, not installed. These cases read JSON, so they take
# the real jq ahead of the stub.
mkdir "$T/realjq"
ln -s "$(command -v jq)" "$T/realjq/jq"
printf '{"extraKnownMarketplaces":{"blairforce1-pap":{"source":{"source":"directory","path":"~/src/pap"}}}}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
missing "doctor: pap plugin missing where the user settings list the marketplace as a directory, with an install that does not add it again" \
  'missing  pap plugin installed  (claude plugin install pap@blairforce1-pap)' \
  STUB_PLUGINS='  > spec-review@blairforce1-pap' PATH="$T/realjq:$dpath"
printf '{"version":2,"plugins":{"pap@blairforce1-pap":[{"installPath":"/nowhere"}]}}\n' > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
missing "doctor: a pap plugin Claude Code's file holds, from a directory marketplace, with the update command and the directory" \
  'missing  pap plugin installed  (bring ~/src/pap, the directory it updates from, up to date, then: claude plugin update pap@blairforce1-pap)' \
  STUB_PLUGINS='  > spec-review@blairforce1-pap' PATH="$T/realjq:$dpath"
printf '{"blairforce1-pap":{"source":{"source":"github","repo":"blairforce1/pap"},"installLocation":"/nowhere"}}\n' > "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
missing "doctor: a pap plugin Claude Code's file holds, from a marketplace that is no directory, with the update command alone" \
  'missing  pap plugin installed  (claude plugin update pap@blairforce1-pap)' \
  STUB_PLUGINS='  > spec-review@blairforce1-pap' PATH="$T/realjq:$dpath"
rm -f "$CLAUDE_CONFIG_DIR/settings.json" "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json" "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
out="$(doctor MISE_SHELL=bash STUB_PLUGINS=fail)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qF 'skipped  pap plugins installed  (claude plugin list failed'
result $? "doctor: claude plugin list failing skips the plugin check; exits 0" "$out"
# The pap plugin's version against the pap that runs doctor, read from the
# file plugin_cmd reads. doctor is run by a released pap, 0.18.0, and by the
# unreleased one; these cases read JSON, so they take the real jq.
pdoctor() { (cd "$T/app" && env -u MISE_SHELL PATH="$T/realjq:$dpath" MISE_SHELL=bash sh "$1" doctor 2>&1); }
pver() { printf '{"version":2,"plugins":{"pap@blairforce1-pap":[{"scope":"user","version":"%s"}]}}\n' "$1" > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"; }
bare() { printf '%s\n' "$out" | grep -qx '  ok       pap plugin installed'; }
pver 0.5.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 1 ] && ! printf '%s\n' "$out" | grep -q 'ok  *pap plugin installed' &&
  has 'drift    pap plugin installed  (the plugin is 0.5.0 and this pap is 0.18.0; restart Claude Code after: claude plugin update pap@blairforce1-pap)'
result $? "doctor: a pap plugin older than this pap is drift, not ok, with both versions, the update command and the restart; exits 1" "$out"
printf '{"extraKnownMarketplaces":{"blairforce1-pap":{"source":{"source":"directory","path":"~/src/pap"}}}}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 1 ] && has 'drift    pap plugin installed  (the plugin is 0.5.0 and this pap is 0.18.0; restart Claude Code after: bring ~/src/pap, the directory it updates from, up to date, then: claude plugin update pap@blairforce1-pap)'
result $? "doctor: an older pap plugin from a directory marketplace names the directory to bring up to date" "$out"
rm -f "$CLAUDE_CONFIG_DIR/settings.json"
pver 0.19.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && has "warn     pap plugin installed  (the plugin is 0.19.0 and this pap is 0.18.0, the older one: mise use -g github:blairforce1/pap@0.19.0, or the repository's pin)"
result $? "doctor: a pap plugin newer than this pap warns, with both versions and the pap to move to; exits 0" "$out"
pver 0.18.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && has 'ok       pap plugin installed  (0.18.0)'
result $? "doctor: a pap plugin at this pap's version is ok, with the version; exits 0" "$out"
pver 0.5.0
out="$(pdoctor "$pap")"; rc=$?
[ "$rc" = 0 ] && bare
result $? "doctor: an unreleased pap compares no plugin version: ok, as before" "$out"
for v in "" unknown 0.18; do
  pver "$v"
  out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
  [ "$rc" = 0 ] && bare
  result $? "doctor: a pap plugin whose version reads '$v' is not compared: ok, as before" "$out"
done
# Installed in more than one scope: the oldest readable version is the one
# judged, and the line says another copy exists.
pvers() { printf '{"version":2,"plugins":{"pap@blairforce1-pap":[{"scope":"project","version":"%s"},{"scope":"user","version":"%s"}]}}\n' "$1" "$2" > "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"; }
pvers 0.18.0 0.5.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 1 ] && has 'drift    pap plugin installed  (installed in more than one scope, the oldest reported: the plugin is 0.5.0 and this pap is 0.18.0; restart Claude Code after: claude plugin update pap@blairforce1-pap)'
result $? "doctor: a pap plugin in two scopes, one older than this pap and one equal, is drift naming the older; exits 1" "$out"
pvers 0.18.0 0.18.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && has 'ok       pap plugin installed  (installed in more than one scope, the oldest reported: 0.18.0)'
result $? "doctor: a pap plugin in two scopes, both at this pap's version, is ok; exits 0" "$out"
pvers 0.19.0 0.20.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && has "warn     pap plugin installed  (installed in more than one scope, the oldest reported: the plugin is 0.19.0 and this pap is 0.18.0, the older one: mise use -g github:blairforce1/pap@0.19.0, or the repository's pin)"
result $? "doctor: a pap plugin in two scopes, both newer than this pap, warns naming the older of the two; exits 0" "$out"
pvers unknown 0.5.0
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 1 ] && has 'drift    pap plugin installed  (installed in more than one scope, the oldest reported: the plugin is 0.5.0 and this pap is 0.18.0;'
result $? "doctor: a scope whose version cannot be read is left out of the choice" "$out"
pvers unknown ""
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && bare
result $? "doctor: a pap plugin in two scopes, neither version readable, is not compared: ok, as before" "$out"
rm -f "$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
out="$(pdoctor "$T/drel/bin/pap")"; rc=$?
[ "$rc" = 0 ] && bare
result $? "doctor: a pap plugin Claude Code's file does not hold is not compared: ok, as before" "$out"
out="$(doctor MISE_SHELL=bash PATH="$T/stub:$T/noflock:$T/mac:$T/sys")"; rc=$?
[ "$rc" = 0 ] &&
  printf '%s\n' "$out" | grep -qF 'warn     flock on PATH  (brew install flock; heavy builds run without the machine lock)'
result $? "doctor: flock missing is a warning with the brew command; exits 0" "$out"
missing "doctor: mise missing on macOS, with the brew command" \
  'missing  mise on PATH  (brew install mise)' PATH="$T/tools:$T/mac:$T/sys"
missing "doctor: mise missing on Linux, with the install link" \
  'missing  mise on PATH  (https://mise.jdx.dev/getting-started.html)' PATH="$T/tools:$T/linux:$T/sys"
missing "doctor: git missing, with the apt command; the repository checks skipped" \
  'missing  git on PATH  (sudo apt install git)' PATH="$T/stub:$T/tools:$T/apt:$T/linux:$T/sysnogit"
printf '%s\n' "$out" | grep -qF 'skipped  git hooks and settings  (no git)' &&
  printf '%s\n' "$out" | grep -qF 'skipped  pinned tools  (no git'
result $? "doctor: git missing skips the hooks and the pins" "$out"

# --- doctor: the agent app (decision 0023) -----------------------------------

# $T/agent: the real jq and a fake curl that is GitHub, ahead of the stubs.
mkdir "$T/agent"
ln -s "$(command -v jq)" "$T/agent/jq"
cat > "$T/agent/curl" <<'EOF'
#!/bin/sh
cat >/dev/null
out="" url="" data=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -d) data="$2"; shift 2 ;;
    -X | -w | -H | --connect-timeout | --max-time | --config) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
f="$FAKE_GH/$(printf '%s' "${url#http://github.invalid/}" | tr '/' '_')"
# A scoped mint for a repository listed in deny-<name>: not in the installation.
r="$(printf '%s' "$data" | jq -r '.repositories[0]? // empty' 2>/dev/null)"
[ -z "$r" ] || [ ! -f "$FAKE_GH/deny-$r" ] || f="$FAKE_GH/deny-$r"
if [ -f "$f" ]; then head -n 1 "$f" | tr -d '\n'; tail -n +2 "$f" > "$out"
else printf 404; echo '{"message":"Not Found"}' > "$out"; fi
EOF
chmod +x "$T/agent/curl"
apath="$T/stub:$T/agent:$T/tools:$T/linux:$T/sys"
was_origin="$(git -C "$T/app" remote get-url origin)"
openssl genrsa -out "$FAKE_KEYRING" 2048 2>/dev/null

out="$(doctor MISE_SHELL=bash)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qF 'ok       key in the keyring  (secret-tool)' &&
  printf '%s\n' "$out" | grep -qF 'skipped  origin, credential helper, installation  (origin is not on GitHub)'
result $? "doctor, agent app: key and client id ok, a non-GitHub origin skips the rest" "$out"

git -C "$T/app" remote set-url origin git@github.com:example-owner/app.git
printf '200\n{"id":4242}\n' > "$FAKE_GH/users_example-owner_installation"
printf '201\n{"token":"ghs_fake","expires_at":"%s"}\n' "$(jq -nr 'now + 3600 | floor | todate')" \
  > "$FAKE_GH/app_installations_4242_access_tokens"
git config --file "$GIT_CONFIG_GLOBAL" credential.https://github.com.helper '!/opt/gh/bin/gh auth git-credential'
out="$(doctor MISE_SHELL=bash PATH="$apath")"; rc=$?
[ "$rc" = 1 ] &&
  printf '%s\n' "$out" | grep -qF 'missing  origin is HTTPS  (git remote set-url origin https://github.com/example-owner/app.git)' &&
  printf '%s\n' "$out" | grep -qF "drift    gh is git's credential helper for github.com  (it calls !/opt/gh/bin/gh by path, past the shim" &&
  printf '%s\n' "$out" | grep -qF 'ok       pap-agent installation covers example-owner/app  (a token scoped to it mints)'
result $? "doctor, agent app: an SSH origin with the set-url fix, a helper by path, the installation" "$out"
printf '422\n{"message":"There is at least one repository that does not exist or is not accessible to the parent installation."}\n' > "$FAKE_GH/deny-app"
rm -rf "$T/run" && mkdir "$T/run"
out="$(doctor MISE_SHELL=bash PATH="$apath")"; rc=$?
[ "$rc" = 1 ] &&
  printf '%s\n' "$out" | grep -qF "missing  pap-agent installation covers example-owner/app  (pap-agent's installation on example-owner does not cover example-owner/app; add the repository on the installation's page" &&
  ! printf '%s\n' "$out" | grep -q ghs_
result $? "doctor, agent app: an installation that does not cover this repository names it, and no token is printed" "$out"
rm "$FAKE_GH/deny-app"
out="$(fixdoctor MISE_SHELL=bash PATH="$apath")"
[ "$(git -C "$T/app" remote get-url origin)" = git@github.com:example-owner/app.git ] &&
  ! grep -qi insteadof "$GIT_CONFIG_GLOBAL" &&
  printf '%s\n' "$out" | grep -qF 'warn     SSH GitHub URLs read as HTTPS  (git config --global --add url."https://github.com/".insteadOf git@github.com:'
result $? "doctor --fix: never changes the remote nor writes the insteadOf rewrite; reports it with the commands" "$out"

git -C "$T/app" remote set-url origin https://github.com/example-owner/app.git
git config --file "$GIT_CONFIG_GLOBAL" credential.https://github.com.helper '!gh auth git-credential'
out="$(doctor MISE_SHELL=bash PATH="$apath")"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qF 'ok       origin is HTTPS' &&
  printf '%s\n' "$out" | grep -qF "ok       gh is git's credential helper for github.com"
result $? "doctor, agent app: HTTPS origin and gh by name as the helper; exits 0" "$out"
git config --file "$GIT_CONFIG_GLOBAL" --add credential.helper store
out="$(doctor MISE_SHELL=bash PATH="$apath")"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qF "drift    gh is git's credential helper for github.com  (other helpers are asked too"
result $? "doctor, agent app: another helper beside gh is drift, a stored credential could answer first" "$out"
# A general helper first, then github.com's reset and gh, as gh auth
# setup-git writes them. The shim's refusal says quit=1, so a helper after
# gh is not asked then; doctor still wants gh alone.
cat > "$GIT_CONFIG_GLOBAL" <<'EOF'
[credential]
  helper = store
[credential "https://github.com"]
  helper =
  helper = !gh auth git-credential
EOF
out="$(doctor MISE_SHELL=bash PATH="$apath")"
printf '%s\n' "$out" | grep -qF "ok       gh is git's credential helper for github.com"
result $? "doctor, agent app: an empty helper before gh clears the others, as gh auth setup-git writes it" "$out"

rm -rf "$T/run" && mkdir "$T/run"
git -C "$T/app" remote set-url origin https://github.com/other-owner/app.git
missing "doctor, agent app: no installation for the owner names it" \
  'missing  pap-agent installation covers other-owner/app  (pap-agent is not installed on other-owner' PATH="$apath"

: > "$FAKE_KEYRING"
missing "doctor, agent app: a missing key names the import" \
  'missing  key in the keyring  (pap agent-key import <pem> --client-id <id>' PATH="$apath"
out="$(doctor MISE_SHELL=bash PATH="$apath" REMOTE_CONTAINERS=true)"
printf '%s\n' "$out" | grep -qF 'skipped  key in the keyring  (dev container: the gh shim steps aside and gh keeps your sign-in, by decision 0023)'
result $? "doctor, agent app: a dev container with no key says the shim steps aside" "$out"

# Back as the cases below expect it.
git -C "$T/app" remote set-url origin "$was_origin"
printf 'not a real key\n' > "$FAKE_KEYRING"
: > "$GIT_CONFIG_GLOBAL"

# --- doctor --fix --------------------------------------------------------------

# fixed_only: every call logged is mise trust, mise install or one of
# doctor's read-only questions; nothing else ran.
fixed_only() {
  grep -qx trust "$STUB_LOG" && grep -qx install "$STUB_LOG" &&
    ! grep -vxE 'trust|install|--version|trust --show|ls --current --json|gh auth status( --hostname github.com)?|claude plugin list' "$STUB_LOG"
}
: > "$STUB_LOG"
out="$(fixdoctor STUB_GH_AUTH=1 PATH="$T/forbid:$T/stub:$T/nojq:$T/linux:$T/sys")"; rc=$?
[ "$rc" = 1 ] && fixed_only &&
  printf '%s\n' "$out" | grep -q '^fix: mise trust && mise install$' &&
  printf '%s\n' "$out" | grep -qF 'missing  gh signed in  (run gh auth login)' &&
  printf '%s\n' "$out" | grep -qF 'missing  jq on PATH  (run mise install, or sudo apt install jq)'
result $? "doctor --fix: runs mise trust and mise install only, on PATH with sudo and apt; prints the rest" "$out
$(cat "$STUB_LOG")"
: > "$STUB_LOG"
out="$(fixdoctor STUB_GH_AUTH=1 PATH="$T/forbid:$T/stub:$T/noflock:$T/mac:$T/sys")"; rc=$?
[ "$rc" = 1 ] && fixed_only && printf '%s\n' "$out" | grep -qF 'warn     flock on PATH  (brew install flock'
result $? "doctor --fix: on macOS runs no brew" "$out
$(cat "$STUB_LOG")"
: > "$STUB_LOG"
out="$(fixdoctor PATH="$T/forbid:$T/tools:$T/linux:$T/sys")"; rc=$?
[ "$rc" = 1 ] && ! grep -vxE 'gh auth status( --hostname github.com)?|claude plugin list' "$STUB_LOG" &&
  printf '%s\n' "$out" | grep -q '^fix: no mise, so nothing to run'
result $? "doctor --fix without mise: runs nothing, says so" "$out
$(cat "$STUB_LOG")"

# --- init when the clone setup fails ------------------------------------------

# A mise whose install fails, as it does with no network. 0.6.0 went on to
# print "Next:" and exit 0 with no tools and no hooks installed: set -e does
# not stop a script for a failure in the middle of an && list.
mkdir "$T/failstub"
cat > "$T/failstub/mise" <<'EOF'
#!/bin/sh
echo "$*" >> "$STUB_LOG"
[ "$1" = install ] && { echo "mise ERROR Failed to install tools" >&2; exit 1; }
exit 0
EOF
chmod +x "$T/failstub/mise"
git init -q -b main "$T/failapp"
: > "$STUB_LOG"
out="$(cd "$T/failapp" && PATH="$T/failstub:$PATH" sh "$pap" init --version 0.1.0 base 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'pap: clone setup failed' &&
  ! printf '%s\n' "$out" | grep -q '^Next:'
result $? "init: a failed mise install stops it, exit 1, with no Next: steps" "exit $rc; $out"
[ "$(tr '\n' ';' < "$STUB_LOG")" = "trust;install;" ]
result $? "init: mise run setup is not run after a failed install" "$(cat "$STUB_LOG")"
[ -f "$T/failapp/.editorconfig" ] && grep -qx 'version = "0.1.0"' "$T/failapp/.config/pap.toml"
result $? "init: the layers stay applied and recorded, for the setup to be finished by hand"
printf '%s\n' "$out" | grep -q '^pap: clone setup failed\..*commit and run pap init again.*pap repo apply.*pap codeowners.*pap doctor$'
result $? "init: the failure names both ways to finish" "$out"

# The first way: commit what init wrote, and run it again with a mise that
# works.
: > "$STUB_LOG"
g -C "$T/failapp" add -A && g -C "$T/failapp" commit -qm "init, setup failed"
out="$(cd "$T/failapp" && sh "$pap" init --version 0.1.0 base 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(tr '\n' ';' < "$STUB_LOG")" = "trust;install;run setup;" ] &&
  [ -z "$(git -C "$T/failapp" status --porcelain)" ] && printf '%s\n' "$out" | grep -q '^Next:'
result $? "init: run again after a commit, it changes no file and finishes the setup" "exit $rc; $out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

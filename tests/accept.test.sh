#!/bin/sh
# accept.test.sh: tests for plugins/pap/skills/accept/accept.sh, the script
# behind /pap:accept.
#
# Usage: sh tests/accept.test.sh
#
# Builds a bare origin and a clone in a temporary directory, with decision
# records on main and one only on a local branch, and puts a fake gh on
# PATH that answers `api user` and records `pr create`. Covers each
# refusal (nothing written, no branch), and acceptance: only the Status
# line changes, on a new change/accept-<ids> branch pushed to origin, with
# a draft class:docs pull request. Prints one TAP-style line per case and
# exits 1 if any case fails. Needs git; no network; touches nothing outside
# the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/plugins/pap/skills/accept/accept.sh"

command -v git > /dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM

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

mkdir "$T/stub"
cat > "$T/stub/gh" << 'EOF'
#!/bin/sh
echo "gh $*" >> "$FAKE_LOG"
echo "gh GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} CLAUDECODE=${CLAUDECODE-<unset>}" >> "$FAKE_ENV"
case "$1 $2" in
  "api user") echo example-lead ;;
  "auth git-credential") cat > /dev/null; printf 'username=x-access-token\npassword=fake-owner\n' ;;
  "pr create")
    while [ $# -gt 0 ]; do
      [ "$1" = --body-file ] && cp "$2" "$FAKE_BODY"
      shift
    done
    echo https://github.com/example/repo/pull/9 ;;
  *) echo "fake gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/stub/gh"
export FAKE_LOG="$T/gh.log" FAKE_BODY="$T/body.md" FAKE_ENV="$T/gh.env"
PATH="$T/stub:$PATH"
export PATH
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
# Rule 23.4: the owner's gh directory, recorded where pap agent-owner init
# puts it; and the environment of an agent shell, which the script must
# not pass on to gh or the push.
export XDG_CONFIG_HOME="$T/xdg"
mkdir -p "$T/xdg/pap" "$T/owner gh"
printf 'owner_gh_config_dir=%s\n' "$T/owner gh" > "$T/xdg/pap/agent.conf"
export CLAUDECODE=1 GH_TOKEN=ghs_agent_token GITHUB_TOKEN=ghs_agent_token2

# record <id> <status>: a decision record in the shape PAP's take.
record() {
  cat > "decisions/$1-example-$1.md" << EOF
# $1. An example decision

- **Status:** $2
- **Date:** 2026-01-01
- **Revisit:** when it is wrong

## Context

Nothing proposed here is real.

## Decision

1. **The first rule holds.** It says what it
   means, over two lines.
2. **The second
   rule wraps.** And so on.

## Consequences

- **Status:** proposed is quoted here and must not change.
EOF
}

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/repo" 2> /dev/null
cd "$T/repo" || exit 1
git config user.name test
git config user.email test@example.invalid
git config commit.gpgsign false
mkdir decisions .github
echo '/decisions/** @example-lead' > .github/CODEOWNERS
record 0001 proposed
record 0002 proposed
record 0003 accepted
record 0004 'measured:confirmed (2026-02-01)'
git add decisions .github
git commit -q -m records
git push -q origin main
# 0005 exists only on a branch that has not merged.
git checkout -q -b change/new-record
record 0005 proposed
git add decisions
git commit -q -m 'a new record'
git checkout -q main
# The push's own environment, which its git hooks get, and the credential
# git would ask for it: the origin here is a path, so the hook asks for one
# itself, through the helpers the push was given.
cat > .git/hooks/pre-push << 'EOF'
#!/bin/sh
echo "push GH_CONFIG_DIR=${GH_CONFIG_DIR-<unset>} GH_TOKEN=${GH_TOKEN-<unset>} GITHUB_TOKEN=${GITHUB_TOKEN-<unset>} CLAUDECODE=${CLAUDECODE-<unset>}" >> "$FAKE_ENV"
# Only a push given a helper asks: the suite's own pushes have none.
case "${GIT_CONFIG_PARAMETERS:-}" in
  *"gh auth git-credential"*)
    printf 'protocol=https\nhost=github.com\n\n' | GIT_TERMINAL_PROMPT=0 git credential fill | sed -n 's/^password=/cred /p' >> "$FAKE_ENV" ;;
esac
EOF
chmod +x .git/hooks/pre-push

run() { : > "$FAKE_LOG"; : > "$FAKE_ENV"; out="$(sh "$script" "$@" 2>&1)"; rc=$?; }
branches() { git for-each-ref --format='%(refname:short)' 'refs/heads/change/accept-*' 'refs/remotes/origin/change/accept-*'; }
clean() { [ -z "$(branches)" ] && [ ! -s "$FAKE_LOG" ] && [ -z "$(git status --porcelain)" ]; }

run
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: usage' && clean
result $? "no ids: usage, nothing written" "exit $rc; $out"
run 18
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "'18' is not a four-digit record number" && clean
result $? "an id that is not four digits is refused" "exit $rc; $out"
run '0001;id'
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'is not a four-digit record number' && clean
result $? "an id with a shell character is refused before any use" "exit $rc; $out"
run 0099
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: no decision record 0099' && clean
result $? "an unknown id is refused, nothing written" "exit $rc; $out"
run 0003
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "^refused: decision 0003 is 'accepted', not proposed" && clean
result $? "an accepted record is refused, nothing written" "exit $rc; $out"
run 0004
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "decision 0004 is 'measured:confirmed (2026-02-01)', not proposed" && clean
result $? "a measured record is refused" "exit $rc; $out"
run 0005
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: decision 0005 is not on main (found on another branch)' && clean
result $? "a record not on the default branch is refused" "exit $rc; $out"
run 0001 0003
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'decision 0003' && clean
result $? "one bad id among several: none is accepted" "exit $rc; $out"

# Acceptance, ids passed as one word as the skill passes them.
day="$(date +%Y-%m-%d)"
run "0002 0001"
wt="$T/repo-accept-0001-0002"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^Opened https://github.com/example/repo/pull/9 (draft) from change/accept-0001-0002'
result $? "accepts: prints the pull request URL" "exit $rc; $out"
printf '%s' "$out" | grep -q '^  0001\. An example decision' &&
  printf '%s' "$out" | grep -q '^    - The first rule holds\.' &&
  printf '%s' "$out" | grep -q '^    - The second rule wraps\.'
result $? "shows each title and the Decision items' leads" "$out"
[ "$(git -C "$wt" branch --show-current)" = change/accept-0001-0002 ] &&
  git ls-remote --exit-code "$T/origin.git" refs/heads/change/accept-0001-0002 > /dev/null
result $? "commits on change/accept-0001-0002, pushed to origin"
diff="$(git -C "$wt" diff -U0 origin/main HEAD -- decisions | grep '^[-+]' | grep -v '^\(---\|+++\) ')"
expect="$(printf -- '-- **Status:** proposed\n+- **Status:** accepted (example-lead, %s)\n' "$day")"
[ "$diff" = "$(printf '%s\n%s' "$expect" "$expect")" ] &&
  [ "$(git -C "$wt" diff --name-only origin/main HEAD | sort | tr '\n' ' ')" = "decisions/0001-example-0001.md decisions/0002-example-0002.md " ]
result $? "rewrites only the Status line of each record" "$diff"
grep -q '^- \*\*Status:\*\* proposed is quoted here' "$wt/decisions/0001-example-0001.md"
result $? "a later line that starts like the Status line is untouched"
[ "$(git -C "$wt" log -1 --format=%s)" = "docs(decisions): accept 0001, 0002" ]
result $? "commit subject names the ids" "$(git -C "$wt" log -1 --format=%s)"
grep -q -- '--draft --title docs(decisions): accept 0001, 0002 --body-file .* --label class:docs$' "$FAKE_LOG" &&
  ! grep -q 'owner-reviewed\|merge\|pr ready' "$FAKE_LOG"
result $? "opens a draft class:docs pull request, adds no other label, merges nothing" "$(cat "$FAKE_LOG")"
grep -q '^Change: none$' "$FAKE_BODY" && grep -q '^Record: none$' "$FAKE_BODY" &&
  grep -q '^- \[ \] No protected path touched' "$FAKE_BODY" && grep -q '^Head to approve: [0-9a-f]\{7\}$' "$FAKE_BODY" &&
  ! grep -q '^Approved-by:' "$FAKE_BODY"
result $? "body: protected-path box unticked with the head to approve, no Approved-by line" "$(cat "$FAKE_BODY")"

owner_env="GH_CONFIG_DIR=$T/owner gh GH_TOKEN=<unset> GITHUB_TOKEN=<unset> CLAUDECODE=<unset>"
[ "$(grep -c '^gh ' "$FAKE_ENV")" = 3 ] && [ "$(sed -n 's/^gh //p' "$FAKE_ENV" | sort -u)" = "$owner_env" ] &&
  [ "$(sed -n 's/^cred //p' "$FAKE_ENV")" = fake-owner ]
result $? "both gh calls and the push's credential run as the owner: owner's GH_CONFIG_DIR, no GH_TOKEN, GITHUB_TOKEN or CLAUDECODE" "$(cat "$FAKE_ENV")"
[ "$(sed -n 's/^push //p' "$FAKE_ENV")" = "GH_CONFIG_DIR=<unset> GH_TOKEN=ghs_agent_token GITHUB_TOKEN=ghs_agent_token2 CLAUDECODE=1" ]
result $? "the push's git hooks keep the caller's environment, not the owner's" "$(cat "$FAKE_ENV")"

# The branch now exists: a second run for the same ids is refused.
git -C "$wt" checkout -q --detach
run 0001 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: change/accept-0001-0002 already exists' && [ ! -s "$FAKE_LOG" ]
result $? "an existing accept branch is refused" "exit $rc; $out"

# No owner directory recorded: refused before anything is fetched or written.
mv "$T/xdg/pap/agent.conf" "$T/agent.conf.away"
run 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: no owner gh directory is recorded.*pap agent-owner init' &&
  [ ! -s "$FAKE_ENV" ] && [ ! -s "$FAKE_LOG" ] && ! git rev-parse -q --verify refs/heads/change/accept-0002 > /dev/null
result $? "no owner directory recorded: refused naming pap agent-owner init, nothing pushed or opened" "exit $rc; $out"
mv "$T/agent.conf.away" "$T/xdg/pap/agent.conf"

# Risk mode: decisions/** is fixed high, so the box says so.
cd "$T/repo" || exit 1
printf 'default: low\n' > .github/risk.yml
git add .github/risk.yml
git commit -q -m 'risk mode'
git push -q origin main
run 0001
[ "$rc" = 0 ] && grep -q '^Risk: high; the owner adds owner-reviewed after review$' "$FAKE_BODY" &&
  ! grep -q '^Head to approve' "$FAKE_BODY"
result $? "risk mode: box unticked with Risk: high" "exit $rc; $out; $(cat "$FAKE_BODY")"

# The Repository line, and --repo. A second fixture repository with its own
# 0001 and 0002; the cwd stays the first one.
git init -q --bare -b main "$T/other-origin.git"
git clone -q "$T/other-origin.git" "$T/other" 2> /dev/null
(
  cd "$T/other" || exit 1
  git config user.name test
  git config user.email test@example.invalid
  git config commit.gpgsign false
  mkdir decisions
  record 0001 proposed
  record 0002 proposed
  record 0003 proposed
  # Not sed -i, which differs between GNU and BSD.
  sed '1s/.*/# 0001. The other repository record/' decisions/0001-example-0001.md > r.tmp &&
    mv r.tmp decisions/0001-example-0001.md
  git add decisions
  git commit -q -m records
  git push -q origin main
)
cd "$T/repo" || exit 1
tb="$(basename "$T")"
accept_refs() { git -C "$1" for-each-ref --format='%(refname:short)' 'refs/heads/change/accept-*' | tr '\n' ' '; }

run 0099
[ "$(printf '%s\n' "$out" | sed -n 1p)" = "Repository: $tb/origin ($T/repo)" ] &&
  printf '%s\n' "$out" | sed -n 2p | grep -q '^refused: no decision record 0099'
result $? "the Repository line is the first line, owner/name and path, even on a refusal" "$out"

run --repo "$T/other" 0099
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "Repository: $tb/other-origin ($T/other)" ]
result $? "--repo names the given checkout on the first line" "exit $rc; $out"

before="$(accept_refs "$T/repo")"
run --repo "$T/other" 0001
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '0001\. The other repository record' &&
  [ "$(accept_refs "$T/other")" = "change/accept-0001 " ] && [ "$(accept_refs "$T/repo")" = "$before" ] &&
  [ "$(git -C "$T/other-accept-0001" branch --show-current)" = change/accept-0001 ]
result $? "--repo acts on the given repository (worktree, branch, PR), not the cwd one" "exit $rc; $out"

# owner/name from the usual origin URL forms.
for u in git@github.com:example/repo.git https://github.com/example/repo https://github.com/example/repo.git/; do
  git -C "$T/other" remote set-url origin "$u"
  run --repo "$T/other"
  [ "$(printf '%s\n' "$out" | sed -n 1p)" = "Repository: example/repo ($T/other)" ]
  result $? "owner/name from origin $u" "$out"
done
git -C "$T/other" remote set-url origin "$T/other-origin.git"

run --repo "$T/nowhere" 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q "^refused: --repo '$T/nowhere' is not a directory" && [ ! -s "$FAKE_LOG" ]
result $? "a --repo that is not a directory is refused" "exit $rc; $out"
mkdir "$T/plain"
run --repo "$T/plain" 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: not inside a git repository' && [ ! -s "$FAKE_LOG" ]
result $? "a --repo that is not a git checkout is refused" "exit $rc; $out"
git init -q "$T/noorigin"
run --repo "$T/noorigin" 0002
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: .* has no origin remote' && [ ! -s "$FAKE_LOG" ]
result $? "a --repo checkout with no origin is refused" "exit $rc; $out"
run --repo
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^refused: --repo needs a path'
result $? "--repo without a path is refused" "exit $rc; $out"

run 0002 --repo "$T/other"
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^Opened .* from change/accept-0002' && [ -d "$T/other-accept-0002" ]
result $? "ids before --repo work" "exit $rc; $out"
git -C "$T/other" checkout -q main
run --repo "$T/other" 0003
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^Opened .* from change/accept-0003' && [ -d "$T/other-accept-0003" ]
result $? "ids after --repo work" "exit $rc; $out"
one="$(sh "$script" "--repo $T/other 0001" 2>&1 | sed -n 1p)"
printf '%s' "$one" | grep -q "^Repository: .* ($T/other)\$"
result $? "--repo inside the single word the skill passes" "$one"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

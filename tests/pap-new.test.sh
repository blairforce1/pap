#!/bin/sh
# pap-new.test.sh: the scenarios of features/pap-new.feature, bound by ID,
# for bin/pap new (changes/pap-new/spec.md). The two release scenarios,
# pap-new-16 and pap-new-40, are bound in tests/release.test.sh.
#
# Usage: sh tests/pap-new.test.sh
#
# Never touches the network, GitHub or the real keyring. Each case gets a
# world of its own under a temporary directory and drives a copy of pap, a
# release 0.1.0, against stand-ins:
#
#   gh      keeps state in $GH_STUB (the sign-in, the repositories, the
#           rulesets), logs every call's arguments to $GH_STUB/log and its
#           environment to $GH_STUB/env, and fails a call whose arguments
#           match a line of $GH_STUB/fail. `gh repo create` makes a bare
#           repository under $W/remotes, which git reaches through an
#           insteadOf rewrite of https://github.com/, so the clone's remote
#           stays the HTTPS URL; that repository's reflog shows each push.
#   git     the real git behind a wrapper that logs every call, and can
#           kill pap at the first commit.
#   mise    logs; `run setup` installs the hooks, `exec --` runs its command.
#   scripts/repo-sync.sh
#           in pap's copy, a stand-in for the GitHub side of `pap repo`
#           (which tests/repo-sync.test.sh covers): status reads, and apply
#           writes, the settings and the main ruleset in $GH_STUB.
#   curl, secret-tool, uname
#           the agent app's endpoint and key, as tests/agent-token.test.sh.
#   claude  records its arguments, directory and environment, then calls gh
#           as a session would, with the session marker set.
#
# PAP_NEW_TTY=1 stands in for the terminal; answers come on stdin. Prints
# one TAP-style line per case and exits 1 if any case fails. Needs git, jq
# and openssl.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"

for tool in git jq openssl; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T" GIT_CONFIG_NOSYSTEM=1
unset NO_COLOR CLAUDE_CONFIG_DIR PAP_SOURCE PAP_GITHUB_API 2>/dev/null || true

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

# The pap under test: a release 0.1.0, so it records a version and needs no
# fetch. Its repo-sync.sh is the stand-in.
mkdir "$T/self"
cp -a "$here/bin" "$here/scripts" "$here/templates" "$here/.claude-plugin" "$T/self/"
echo 0.1.0 > "$T/self/VERSION"
pap="$T/self/bin/pap"
cat > "$T/self/scripts/repo-sync.sh" <<'EOF'
#!/bin/sh
# Stand-in for the GitHub side of pap repo.
cmd="$1" repo="$3"
echo "$cmd $repo" >> "$GH_STUB/sync.log"
case "$cmd" in
  status) [ -f "$GH_STUB/settings/$repo" ] ;;
  apply)
    echo "sync apply" >> "$W/events"
    [ ! -f "$GH_STUB/apply-fails" ] || { echo "repo-sync: 1 failed"; exit 1; }
    mkdir -p "$GH_STUB/settings/${repo%/*}" "$GH_STUB/rulesets/$repo"
    : > "$GH_STUB/settings/$repo"
    [ ! -f "$GH_STUB/apply-no-ruleset" ] || exit 0
    actors='[]'
    [ ! -f "$GH_STUB/apply-bypass" ] || actors='[{"actor_type":"Integration","actor_id":1}]'
    echo '[{"id":7,"name":"main","source_type":"Repository"}]' > "$GH_STUB/rulesets/$repo/list"
    printf '{"id":7,"name":"main","enforcement":"active","bypass_actors":%s}\n' "$actors" > "$GH_STUB/rulesets/$repo/7" ;;
esac
EOF

real_git="$(command -v git)"
export REAL_GIT="$real_git"
mkdir "$T/stub"
cat > "$T/stub/git" <<'EOF'
#!/bin/sh
[ -z "${W:-}" ] || printf '%s\n' "$*" >> "$W/git.log"
if [ -n "${W:-}" ] && [ -f "$W/kill-at-commit" ]; then
  case " $* " in *" commit "*)
    rm -f "$W/kill-at-commit"
    # pap itself, the parent of the subshell that runs this commit.
    kill -KILL "$(ps -o ppid= -p "$PPID" | tr -d ' ')" "$PPID"
    exit 1 ;;
  esac
fi
exec "$REAL_GIT" "$@"
EOF
cat > "$T/stub/gh" <<'EOF'
#!/bin/sh
# The stand-in GitHub. State is files under $GH_STUB.
S="$GH_STUB"
printf '%s\n' "$*" >> "$S/log"
printf 'args=%s GH_CONFIG_DIR=%s GH_TOKEN=%s CLAUDECODE=%s\n' "$*" "${GH_CONFIG_DIR-<unset>}" "${GH_TOKEN-<unset>}" "${CLAUDECODE-<unset>}" >> "$S/env"
if [ -f "$S/fail" ]; then
  while IFS= read -r pat; do
    case "$*" in *"$pat"*) echo "gh: stand-in failure of '$pat'" >&2; exit 1 ;; esac
  done < "$S/fail"
fi
signin="$(cat "$S/signin")"
answer() { # answer <-i?> <code> <body> [header]
  if [ "$1" = true ]; then printf 'HTTP/2.0 %s X\r\nContent-Type: application/json\r\n%s\r\n%s\n' "$2" "${4:+$4
}" "$3"
  elif [ "$2" = 200 ]; then printf '%s\n' "$3"; fi
  [ "$2" = 200 ]
}
case "$1 ${2:-}" in
  "auth token") [ "$signin" != out ] && echo gho_OWNERSECRET; exit ;;
  "auth login" | "auth refresh")
    echo "gh $*" >> "$W/events"
    [ ! -f "$S/signin-after" ] || cp "$S/signin-after" "$S/signin"
    exit 0 ;;
  "repo create")
    for a in "$@"; do slug="$a"; done
    vis=private; case " $* " in *" --public "*) vis=public ;; esac
    echo "gh repo create" >> "$W/events"
    mkdir -p "$S/repos/${slug%/*}" "$W/remotes/${slug%/*}"
    printf '{"private":%s}\n' "$([ "$vis" = private ] && echo true || echo false)" > "$S/repos/$slug"
    "$REAL_GIT" init -q --bare -b main "$W/remotes/$slug.git"
    "$REAL_GIT" -C "$W/remotes/$slug.git" config core.logAllRefUpdates always
    printf '#!/bin/sh\necho push >> "%s/events"\n' "$W" > "$W/remotes/$slug.git/hooks/post-receive"
    chmod +x "$W/remotes/$slug.git/hooks/post-receive"
    if [ -f "$S/push-refusal" ]; then
      printf '#!/bin/sh\ncat "%s/push-refusal" >&2\nexit 1\n' "$S" > "$W/remotes/$slug.git/hooks/pre-receive"
      chmod +x "$W/remotes/$slug.git/hooks/pre-receive"
    fi
    exit 0 ;;
esac
[ "$1" = api ] || exit 0
shift
inc=false path=""
for a in "$@"; do case "$a" in -i) inc=true ;; -*) ;; *) path="$a" ;; esac; done
case "$path" in
  user)
    case "$signin" in
      net) exit 1 ;;
      out) echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 4 ;;
      lacks-workflow) hdr="X-Oauth-Scopes: gist, repo" ;;
      noscopes) hdr="" ;;
      *) hdr="X-Oauth-Scopes: gist, repo, workflow" ;;
    esac
    answer "$inc" 200 "{\"login\":\"olive\",\"plan\":{\"name\":\"$(cat "$S/plan")\"}}" "$hdr" ;;
  users/*)
    if [ -f "$S/orgs/${path#users/}" ]; then answer "$inc" 200 '{"type":"Organization"}'
    else answer "$inc" 404 '{"message":"Not Found"}'; fi ;;
  orgs/*/rulesets) cat "$S/orgs/$(echo "$path" | cut -d/ -f2).rulesets" 2>/dev/null || echo '[]' ;;
  orgs/*/rulesets/*) cat "$S/orgs/$(echo "$path" | cut -d/ -f2).ruleset-${path##*/}" ;;
  orgs/*) answer "$inc" 200 "{\"plan\":{\"name\":\"$(cat "$S/orgs/${path#orgs/}")\"}}" ;;
  repos/*/*/rulesets) r="${path#repos/}"; cat "$S/rulesets/${r%/rulesets}/list" 2>/dev/null || echo '[]' ;;
  repos/*/*/rulesets/*) r="${path#repos/}"; cat "$S/rulesets/${r%%/rulesets/*}/${path##*/}" ;;
  repos/*/*)
    if [ -f "$S/repos/${path#repos/}" ]; then answer "$inc" 200 "$(cat "$S/repos/${path#repos/}")"
    else answer "$inc" 404 '{"message":"Not Found"}'; fi ;;
  *) answer "$inc" 404 '{"message":"Not Found"}' ;;
esac
EOF
cat > "$T/stub/mise" <<'EOF'
#!/bin/sh
echo "$*" >> "$W/mise.log"
case "$1" in
  exec) shift 2; exec "$@" ;;
  install) [ ! -f "$W/mise-fails" ] || { echo "mise ERROR stand-in failure"; exit 1; } ;;
  run)
    echo "mise run setup" >> "$W/events"
    h="$("$REAL_GIT" rev-parse --git-path hooks)"
    mkdir -p "$h"
    for f in pre-commit pre-push; do printf '#!/bin/sh\n# lefthook\n' > "$h/$f"; chmod +x "$h/$f"; done
    "$REAL_GIT" config blame.ignoreRevsFile .git-blame-ignore-revs ;;
esac
exit 0
EOF
cat > "$T/stub/claude" <<'EOF'
#!/bin/sh
echo claude >> "$W/events"
for a in "$@"; do printf '%s\n' "$a"; done > "$W/claude.args"
pwd -P > "$W/claude.pwd"
env > "$W/claude.env"
command -v gh > "$W/claude.gh"
slug="$("$REAL_GIT" config --get remote.origin.url | sed 's|^https://github.com/||; s|\.git$||')"
CLAUDECODE=1 gh api "repos/$slug" > "$W/claude.gh.out" 2>&1
exit 0
EOF
cat > "$T/stub/uname" <<'EOF'
#!/bin/sh
echo Linux
EOF
cat > "$T/stub/secret-tool" <<'EOF'
#!/bin/sh
case "$1" in
  lookup) [ -s "$FAKE_KEYRING" ] && cat "$FAKE_KEYRING" ;;
  *) exit 2 ;;
esac
EOF
cat > "$T/stub/curl" <<'EOF'
#!/bin/sh
# The agent app's endpoint: answers from $FAKE_GH/<METHOD>_<path>.
out="" url="" method=GET argv="$*" data=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -d) data="$2"; shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -w | -H | --connect-timeout | --max-time | --config) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
cat >/dev/null
path="/${url#http://github.invalid/}"
printf 'ARGV %s\nREQ %s %s\n' "$argv" "$method" "$path" >> "$FAKE_GH/log"
f="$FAKE_GH/$(printf '%s_%s' "$method" "$path" | tr '/' '_')"
r="$(printf '%s' "$data" | jq -r '.repositories[0]? // empty' 2>/dev/null)"
if [ -n "$r" ] && [ -f "$FAKE_GH/deny-once-$r" ]; then rm "$FAKE_GH/deny-once-$r"; f="$FAKE_GH/denied"
elif [ -n "$r" ] && [ -f "$FAKE_GH/deny-$r" ]; then f="$FAKE_GH/denied"; fi
if [ -f "$f" ]; then code="$(head -n 1 "$f")"; body="$(tail -n +2 "$f")"
else code=404; body='{"message":"Not Found"}'; fi
printf '%s\n' "$body" > "$out"
printf '%s' "$code"
EOF
chmod +x "$T"/stub/*
openssl genrsa -out "$T/key.pem" 2048 2>/dev/null
base_path="$PATH"

# world: a fresh world in which the owner, olive, is ready to create
# "trial": at her own terminal, signed in with both scopes, on a paid plan,
# the agent app registered with an all-repositories installation on her,
# and the pap, spec-review and pm-console plugins installed.
w=0
world() {
  w=$((w + 1))
  W="$T/w$w"
  mkdir -p "$W/cwd" "$W/home/.claude/plugins" "$W/xdg/pap" "$W/run" "$W/gh/orgs" "$W/api"
  export W HOME="$W/home" XDG_CONFIG_HOME="$W/xdg" XDG_RUNTIME_DIR="$W/run" \
    GH_STUB="$W/gh" FAKE_GH="$W/api" FAKE_KEYRING="$T/key.pem" \
    PAP_GITHUB_API=http://github.invalid PAP_NEW_TTY=1 PATH="$T/stub:$base_path"
  unset CLAUDECODE GH_CONFIG_DIR
  cat > "$HOME/.gitconfig" <<EOF
[user]
  name = Olive Owner
  email = olive@example.invalid
[commit]
  gpgsign = false
[init]
  defaultBranch = main
[url "$W/remotes/"]
  insteadOf = https://github.com/
EOF
  echo ok > "$W/gh/signin"
  echo pro > "$W/gh/plan"
  printf 'client_id=Iv1.test\nslug=olive-pap-agent\n' > "$W/xdg/pap/agent.conf"
  installation olive all
  printf '201\n{"token":"ghs_AGENTSECRET","expires_at":"2999-01-01T00:00:00Z"}\n' > "$W/api/POST__app_installations_42_access_tokens"
  printf '422\n{"message":"not accessible"}\n' > "$W/api/denied"
  jq -n --arg p "$here/plugins" '{version: 2, plugins: {
    "pap@blairforce1-pap": [{installPath: ($p + "/pap")}],
    "spec-review@blairforce1-pap": [{installPath: ($p + "/spec-review")}],
    "pm-console@blairforce1-pap": [{installPath: ($p + "/pm-console")}],
    "other@elsewhere": [{installPath: ($p + "/pap")}]}}' > "$HOME/.claude/plugins/installed_plugins.json"
  : > "$W/events"
  : > "$W/gh/log"
}
installation() { # installation <owner> <all|selected>
  kind=users
  [ ! -f "$W/gh/orgs/$1" ] || kind=orgs
  printf '200\n{"id":42,"repository_selection":"%s","html_url":"https://github.com/settings/installations/42"}\n' "$2" \
    > "$W/api/GET__${kind}_$1_installation"
}
org() { echo "${2:-team}" > "$W/gh/orgs/$1"; installation "$1" all; }

# run <stdin text> <pap new arguments...>: sets out and rc.
run() {
  in="$1"
  shift
  # shellcheck disable=SC2059 # the answers are a format: \n is Enter
  out="$(cd "$W/cwd" && printf "$in" | sh "$pap" new "$@" 2>&1)"
  rc=$?
}
has() { printf '%s\n' "$out" | grep -q -- "$1"; }
hasnt() { ! has "$1"; }
pushes() {
  f="$W/remotes/${1:-olive}/trial.git/logs/refs/heads/main"
  if [ -f "$f" ]; then wc -l < "$f" | tr -d ' '; else echo 0; fi
}
commits() { git -C "$W/remotes/${1:-olive}/trial.git" rev-list --count main 2>/dev/null || echo 0; }
count() { grep -c -- "$1" "$2" 2>/dev/null || true; }
# nothing_created: nothing in the current directory, nothing on GitHub.
nothing_created() {
  [ -z "$(ls -A "$W/cwd")" ] && [ ! -d "$W/remotes" ] && [ ! -d "$W/gh/repos" ] &&
    [ ! -f "$W/gh/sync.log" ] && [ ! -f "$W/claude.args" ]
}
preflight_stop() { [ "$rc" = 1 ] && has '^stop  *preflight$'; }
welcomed() { [ "$rc" = 0 ] && [ "$(cat "$W/claude.pwd" 2>/dev/null)" = "$W/cwd/trial" ]; }
# stopped_at <state> [extra pap new arguments]: a run of pap new "trial"
# stopped with the greenfield repository in <state>, then the cause of the
# stop taken away so a re-run can go on.
stopped_at() {
  st="$1"
  shift
  case "$st" in
    committed) echo "repo create" > "$W/gh/fail" ;;
    created) printf 'remote: error: GH013: Repository rule violations found for refs/heads/main.\n' > "$W/gh/push-refusal" ;;
    pushed) : > "$W/mise-fails" ;;
    "set up") : > "$W/gh/apply-fails" ;;
    "settings applied") : > "$W/api/deny-trial" ;;
  esac
  run '\n' trial "$@"
  first_rc="$rc" first_out="$out"
  rm -f "$W/gh/fail" "$W/gh/push-refusal" "$W/mise-fails" "$W/gh/apply-fails" "$W/api/deny-trial"
  rm -f "$W"/remotes/*/trial.git/hooks/pre-receive
  : > "$W/events"
  : > "$W/gh/log"
  rm -f "$W/gh/sync.log" "$W/api/log"
}

# --- Preflight creates nothing ------------------------------------------------

long="$(printf '%0101d' 0 | tr 0 a)"
for name in "not a name" "tri/al" "." ".." "-trial" "$long"; do
  world
  t0="$(date +%s)"
  run '' "$name"
  t1="$(date +%s)"
  preflight_stop && has 'cause: the name rule' && nothing_created && [ $((t1 - t0)) -lt 2 ]
  result $? "pap-new-3: the name '$(printf '%s' "$name" | cut -c1-20)' is refused by the name rule, in under 2 seconds" "$out"
done
world
run '' "$(printf '%0100d' 0 | tr 0 a)" --yes
hasnt 'the name rule'
result $? "pap-new-3: a name of 100 letters passes the name rule" "$out"

world
run '' trial --owner bad_owner
preflight_stop && has "cause: the owner 'bad_owner' is not a GitHub login" && nothing_created
result $? "pap-new-17: an owner that is not a GitHub login is refused" "$out"

world
run '' trial --layers rust
preflight_stop && has "cause: the layers: 'rust' is not a layer" && has 'the layers are base dotnet go risk' && nothing_created
result $? "pap-new-20: an unknown layer is refused, naming the layers" "$out"
world
run '' trial --layers ../x
preflight_stop && has "cause: the layers: '../x' is not a layer" && nothing_created
result $? "pap-new-20: a layer that is a path is refused" "$out"
world
run '' trial --layers go
preflight_stop && has 'cause: the layers: base is not among' && nothing_created
result $? "pap-new-20: layers without base are refused" "$out"
world
run '' trial --visibility internal
preflight_stop && has "cause: the visibility 'internal'" && has 'private or public' && nothing_created
result $? "pap-new-20: an unknown visibility is refused, naming the values" "$out"

agent_refused() {
  preflight_stop && has "the owner's to run" && has 'run again: pap new trial' &&
    hasnt 'gh auth login' && ! grep -q '^auth' "$W/gh/log" && nothing_created && [ $((t1 - t0)) -lt 2 ]
}
world
echo out > "$W/gh/signin"
t0="$(date +%s)"; CLAUDECODE=1 run '' trial; t1="$(date +%s)"
agent_refused
result $? "pap-new-4: an agent shell by the session marker is refused before any sign-in offer" "$out"
world
echo out > "$W/gh/signin"
t0="$(date +%s)"; GH_CONFIG_DIR="$W/xdg/gh-agent" run '' trial; t1="$(date +%s)"
agent_refused && has "agent's gh directory"
result $? "pap-new-4: an agent shell by the agent's gh directory, without the marker, is refused" "$out"
world
echo out > "$W/gh/signin"
t0="$(date +%s)"; PATH="$T/self/scripts/shim:$PATH" run '' trial; t1="$(date +%s)"
agent_refused && has "agent's gh"
result $? "pap-new-4: an agent shell by the agent's gh first on the path, without the marker, is refused" "$out"

world
PAP_NEW_TTY='' run '' trial --yes
preflight_stop && has 'needs a terminal' && nothing_created
result $? "pap-new-21: a run with no terminal stops in preflight, and no welcome session starts" "$out"

world
echo net > "$W/gh/signin"
run '\n\n' trial
preflight_stop && has 'cause: GitHub could not be reached (the network' && hasnt 'gh auth login' && ! grep -q '^auth login' "$W/gh/log"
result $? "pap-new-25: GitHub out of reach names the network and offers no sign-in" "$out"

world
echo out > "$W/gh/signin"
echo ok > "$W/gh/signin-after"
run '\n\n' trial
has "Run 'gh auth login --hostname github.com --scopes repo,workflow' now" &&
  grep -q 'args=auth login .* GH_CONFIG_DIR=<unset> GH_TOKEN=<unset>' "$W/gh/env" &&
  has 'ok *the owner sign-in (olive) has the repo and workflow scopes' && welcomed
result $? "pap-new-5: a signed-out owner is offered gh auth login in the owner's gh directory, and the sign-in is rechecked" "$out"

world
echo lacks-workflow > "$W/gh/signin"
echo ok > "$W/gh/signin-after"
run '\n\n' trial
has "Run 'gh auth refresh --hostname github.com --scopes workflow' now" &&
  grep -q 'args=auth refresh .* GH_CONFIG_DIR=<unset> GH_TOKEN=<unset>' "$W/gh/env" &&
  has 'ok *the owner sign-in (olive) has the repo and workflow scopes' && welcomed
result $? "pap-new-6: a missing workflow scope is offered the refresh in the owner's gh directory, and the sign-in is rechecked" "$out"
grep -qx 'auth refresh --hostname github.com --scopes workflow' "$W/gh/log" && ! grep -q 'delete_repo' "$W/gh/log"
result $? "pap-new-39: the scope refresh asks for workflow and for nothing else" "$(cat "$W/gh/log")"

world
echo out > "$W/gh/signin"
run 'n\n' trial
preflight_stop && has 'cause: the owner sign-in: the offer of' && ! grep -q '^auth login' "$W/gh/log" && nothing_created
result $? "pap-new-18: a declined sign-in offer stops the run naming the owner sign-in" "$out"

world
echo noscopes > "$W/gh/signin"
run '\n' trial
has 'warn *the owner sign-in (olive) reports no scopes, so they could not be checked' &&
  has 'may have the first push refused' && has 'the agent installation on olive is all-repositories' && welcomed
result $? "pap-new-7: unreadable scopes are reported with the first-push warning and let through" "$out"

world
rm "$W/xdg/pap/agent.conf"
run '\n' trial
preflight_stop && has 'cause: the agent app is unregistered' && has 'pap agent-setup' && nothing_created
result $? "pap-new-8: an unregistered agent app stops the run naming pap agent-setup" "$out"

world
rm "$W/api/GET__users_olive_installation"
run '\n' trial
preflight_stop && has 'has no installation on olive' && has 'https://github.com/apps/olive-pap-agent/installations/new' && nothing_created
result $? "pap-new-19: an agent app not installed on the owner stops the run naming the install page" "$out"

world
installation olive selected
run 'n\n' trial
has 'warn *the agent installation on olive is selected-repositories' &&
  has 'one prompted step will follow creation: adding trial to the installation' && has '^Summary$'
result $? "pap-new-9: a selected-repositories installation is warned of, and the run goes on to the summary" "$out"

world
run 'n\n' trial --visibility public
has 'a public repository leaves one step for the owner: the Actions policy' && has 'Settings > Actions > Policies' && has '^Summary$'
result $? "pap-new-23: a public repository's prompted step is named before creation, with where it is done" "$out"
world
org acme
run 'n\n' trial --owner acme
has 'an organisation leaves one step for the owner' && has '\.github repository' && has '^Summary$'
result $? "pap-new-23: an organisation's prompted step is named before creation, with where it is done" "$out"

world
org acme
echo '[{"id":3,"name":"org default","target":"branch","enforcement":"active"}]' > "$W/gh/orgs/acme.rulesets"
echo '{"id":3,"name":"org default","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]},"repository_name":{"include":["~ALL"],"exclude":[]}}}' > "$W/gh/orgs/acme.ruleset-3"
run '\n' trial --owner acme
preflight_stop && has "has a ruleset, 'org default', on the default branch of every repository" && nothing_created
result $? "pap-new-24: an organisation ruleset that would refuse the first push stops the run naming it" "$out"

world
echo free > "$W/gh/plan"
run '\n' trial
preflight_stop && has 'cause: a private repository would have no main ruleset' && nothing_created
result $? "pap-new-27: a private repository that can have no main ruleset stops the run" "$out"

world
mkfifo "$W/in"
( cd "$W/cwd" && exec sh "$pap" new trial < "$W/in" > "$W/out" 2>&1 ) &
pid=$!
exec 9> "$W/in"
i=0
while ! grep -q 'Press Enter to go on' "$W/out" 2>/dev/null && [ "$i" -lt 200 ]; do sleep 0.1; i=$((i + 1)); done
out="$(cat "$W/out")"
has 'acting as *olive' && has 'repository *olive/trial' && has 'visibility *private' &&
  has 'layers *base risk dotnet' && has 'first commit *Olive Owner <olive@example.invalid>' && nothing_created
result $? "pap-new-22: the summary shows who, what and the first commit's author, and nothing is created until the owner confirms" "$out"
printf '\n' >&9
exec 9>&-
wait "$pid"
[ -d "$W/cwd/trial/.git" ] && [ -d "$W/remotes/olive/trial.git" ]
result $? "pap-new-22: once the owner confirms, creation goes on" "$(cat "$W/out")"

world
run 'n\n' trial
preflight_stop && has 'cause: the summary was declined' && nothing_created
result $? "pap-new-28: a declined summary stops the run in preflight" "$out"

# --- Creation runs in one order and never past a missing control --------------

world
run '\n' trial
c="$W/cwd/trial"
for s in "Step 1 of 6: first commit" "Step 2 of 6: repository creation" "Step 3 of 6: first push" \
  "Step 4 of 6: clone setup" "Step 5 of 6: repository settings" "Step 6 of 6: agent token"; do
  has "^$s\$" || rc=99
done
[ "$rc" = 0 ]
result $? "pap-new-1: each step is named as it starts" "$out"
[ "$(cat "$W/gh/repos/olive/trial")" = '{"private":true}' ] && grep -qx 'repo create --private -- olive/trial' "$W/gh/log"
result $? "pap-new-1: a private greenfield repository exists for the owner" "$(cat "$W/gh/log")"
grep -qx 'version = "0.1.0"' "$c/.config/pap.toml" && grep -qx 'layers = \["base", "risk", "dotnet"\]' "$c/.config/pap.toml"
result $? "pap-new-1: the applied version and the layers base, risk and dotnet are recorded" "$(cat "$c/.config/pap.toml")"
mkdir "$W/expect" && sh "$T/self/scripts/assemble.sh" base risk dotnet "$W/expect" >/dev/null
tracked="$(git -C "$c" ls-tree -r --name-only main | grep -vx -e README.md -e .config/pap.toml -e .config/mise/conf.d/pap.toml | sort)"
[ "$(commits)" = 1 ] && [ "$(git -C "$c" rev-parse main)" = "$(git -C "$W/remotes/olive/trial.git" rev-parse main)" ] &&
  [ "$(git -C "$c" show main:README.md)" = "# trial" ] &&
  [ "$tracked" = "$(cd "$W/expect" && git init -q . && git add -A && git ls-files | sort)" ] &&
  git -C "$c" show main:lefthook.yml | cmp -s - "$W/expect/lefthook.yml"
result $? "pap-new-1: main holds exactly one commit, the template and a README whose only line is '# trial'" "$(git -C "$c" log --oneline; echo "$tracked" | head)"
[ "$(git -C "$c" config --get remote.origin.url)" = "https://github.com/olive/trial.git" ]
result $? "pap-new-1: the clone's remote is HTTPS on github.com"
[ -z "$(git -C "$c" status --porcelain)" ]
result $? "pap-new-1: the clone's working tree is clean" "$(git -C "$c" status --porcelain)"
[ -f "$W/gh/settings/olive/trial" ] && grep -qx 'apply olive/trial' "$W/gh/sync.log"
result $? "pap-new-1: the repository settings are applied"
welcomed && grep -q "^GH_CONFIG_DIR=$W/xdg/gh-agent\$" "$W/claude.env"
result $? "pap-new-1: a welcome session starts in the clone as the agent" "$out"
has '^pap new: steps done 6 of 6, prompts taken 1, re-run no$'
result $? "pap-new-1: a complete run ends with the one-line count" "$out"

# pap-new-10, on the same run.
[ "$(tr '\n' ' ' < "$W/events")" = "gh repo create push mise run setup sync apply claude " ]
result $? "pap-new-10: the first push comes before clone setup and before the repository settings" "$(cat "$W/events")"
[ "$(pushes)" = 1 ] && [ "$(count ' push ' "$W/git.log")" = 1 ] && [ "$(count '^push$' "$W/events")" = 1 ]
result $? "pap-new-10: it is the only push to main the run makes" "$(grep push "$W/git.log")"
! grep -q -e '--no-verify' -e 'core.hooksPath' -e 'commit .*-n ' "$W/git.log" && ! grep -q -e '^LEFTHOOK' "$W/claude.env"
result $? "pap-new-10: no git call in the run skips a hook" "$(grep -e no-verify -e hooksPath "$W/git.log")"
[ "$(jq '.bypass_actors | length' "$W/gh/rulesets/olive/trial/7")" = 0 ] && has 'the main ruleset is active with no bypass actor'
result $? "pap-new-10: the main ruleset has no bypass actor"

# pap-new-38, on the same run: the owner's and the agent's tokens.
hasnt 'gho_OWNERSECRET' && hasnt 'ghs_AGENTSECRET' &&
  ! grep -rq -e gho_OWNERSECRET -e ghs_AGENTSECRET "$c" &&
  ! grep -q -e gho_OWNERSECRET -e ghs_AGENTSECRET "$W/git.log" "$W/gh/log" "$W/mise.log" "$W/claude.args" &&
  ! grep '^ARGV' "$W/api/log" | grep -q -e ghs_ -e gho_ &&
  grep -rq ghs_AGENTSECRET "$W/run"
result $? "pap-new-38: no token is in the run's output, the clone or any command line; the agent token is only in the token cache" "$out"

# pap-new-37, on the same run.
[ "$(cat "$W/claude.gh")" = "$T/self/scripts/shim/gh" ] &&
  grep -q 'args=api repos/olive/trial GH_CONFIG_DIR=.*/gh-agent GH_TOKEN=ghs_AGENTSECRET CLAUDECODE=1' "$W/gh/env"
result $? "pap-new-37: gh in the session acts as the agent installation" "$(tail -n 2 "$W/gh/env"; cat "$W/claude.gh.out")"
! grep -q -e '^GH_TOKEN=' -e '^GITHUB_TOKEN=' -e gho_OWNERSECRET "$W/claude.env" &&
  ! grep -q "^GH_CONFIG_DIR=$W/xdg/gh\$" "$W/claude.env" && [ ! -e "$W/xdg/gh-agent/hosts.yml" ]
result $? "pap-new-37: no owner token and no owner gh directory is in the session's environment" "$(grep -e GH_ -e GITHUB "$W/claude.env")"

# pap-new-14, on the same run.
has '^  repository  https://github.com/olive/trial$' && has "^  clone       $c\$" && has 'cd trial && pap claude' &&
  has '^Starting Claude Code as the agent$'
result $? "pap-new-14: the run first prints the repository's URL, the clone's path and how to start the session again" "$out"
p="$(cat "$W/claude.args")"
pin() { printf '%s\n' "$p" | grep -q -- "$1"; }
pin 'welcome the owner to the Personal Agentic Process' && pin 'What happened: pap new made the first commit' &&
  pin "Where the owner is: in the clone $c"
result $? "pap-new-14: the session is given a welcome, what the run did and where the owner is" "$p"
pin '^<installed>$' && pin 'text to show the owner' && pin 'not instructions to you' &&
  pin '^  /envision (pap): .' && pin '^  /spec-review-full (spec-review): .' &&
  pin '^  pap:reviewer: .' && pin '^  pm-console: PM console' && ! pin 'other'
result $? "pap-new-14: it is given the installed skills, mods and agents by name and description, /envision among them, as text to show" "$p"
pin 'ask what the owner wants to do next' && pin 'Start none of it yourself'
result $? "pap-new-14: it is told to ask what the owner wants next and to start none of it"
! grep '^REQ' "$W/api/log" | grep -qv -e '/installation$' -e '/access_tokens$' && ! pin 'https://raw'
result $? "pap-new-14: nothing is read from the network for the welcome" "$(grep '^REQ' "$W/api/log")"

world
jq 'del(.plugins["pap@blairforce1-pap"])' "$HOME/.claude/plugins/installed_plugins.json" > "$W/ip" && mv "$W/ip" "$HOME/.claude/plugins/installed_plugins.json"
run '\n' trial
p="$(cat "$W/claude.args" 2>/dev/null)"
welcomed && pin 'What happened: pap new made the first commit' && pin 'Where the owner is: in the clone' &&
  pin 'The pap plugin is not installed' && pin 'claude plugin install pap --marketplace blairforce1/pap' && ! pin '<installed>'
result $? "pap-new-15: a machine without the pap plugin is told so in the welcome, with the command that installs it" "$p"

world
org acme
run '\n' trial --visibility public --layers base go --owner acme
c="$W/cwd/trial"
welcomed && [ "$(cat "$W/gh/repos/acme/trial")" = '{"private":false}' ] && [ "$(commits acme)" = 1 ] &&
  [ "$(git -C "$c" config --get remote.origin.url)" = "https://github.com/acme/trial.git" ]
result $? "pap-new-2: a public greenfield repository exists for the organisation" "$out"
grep -qx 'layers = \["base", "go"\]' "$c/.config/pap.toml"
result $? "pap-new-2: the layers base and go are recorded" "$(cat "$c/.config/pap.toml")"

world
stopped_at created
mkdir -p "$W/cwd/trial/.git/hooks" && printf '#!/bin/sh\nexit 0\n' > "$W/cwd/trial/.git/hooks/pre-push"
run '\n' trial
[ "$rc" = 1 ] && has '^stop  *step 3 of 6, first push$' && has 'git hooks installed (pre-push)' && [ "$(pushes)" = 0 ] && [ "$(commits)" = 0 ]
result $? "pap-new-26: hooks found before the first push stop the run naming them, and nothing is pushed" "$out"

world
stopped_at committed
# shellcheck disable=SC2016 # GitHub's own backticks
printf 'remote: error: refusing to allow an OAuth App to create or update workflow `.github/workflows/test.yml` without `workflow` scope\n' > "$W/gh/push-refusal"
run '\n' trial
[ "$rc" = 1 ] && has '^stop  *step 3 of 6, first push$' && has 'may not push workflow files (the workflow permission is missing)' &&
  has 'run again: pap new trial --owner olive --visibility private --layers base risk dotnet' && [ "$(commits)" = 0 ]
result $? "pap-new-30: a refused first push names the missing permission and gives the command to run again" "$out"
world
: > "$W/mise-fails"
run '\n' trial
[ "$rc" = 1 ] && has '^stop  *step 4 of 6, clone setup$' && has 'main is not yet protected'
result $? "pap-new-30: a stop between the first push and the repository settings says main is not yet protected" "$out"

world
org acme
: > "$W/gh/apply-fails"
run '\n' trial --owner acme
[ "$rc" = 1 ] && has '^stop  *step 5 of 6, repository settings$'
result $? "pap-new-29: a stop names the step and its number of six" "$out"
has 'exists so far: the clone ./trial, holding the first commit; the repository acme/trial on GitHub, with the first commit on main; the clone set up' &&
  has 'cause: applying the repository settings failed'
result $? "pap-new-29: it says what exists so far and the cause" "$out"
has 'run again: pap new trial --owner acme --visibility private --layers base risk dotnet'
result $? "pap-new-29: it gives the command to run again, with the owner"
[ "$(printf '%s\n' "$out" | tail -n 1)" = "pap new: steps done 4 of 6, prompts taken 1, re-run no" ] && [ ! -f "$W/claude.args" ]
result $? "pap-new-29: it ends with a one-line count of steps done and prompts taken" "$(printf '%s\n' "$out" | tail -n 1)"

world
: > "$W/gh/apply-no-ruleset"
run '\n' trial
[ "$rc" = 1 ] && has '^stop  *step 5 of 6, repository settings$' && has 'cause: the main ruleset: olive/trial has no main ruleset' &&
  [ "$(count 'POST' "$W/api/log")" = 0 ] && [ ! -f "$W/claude.args" ]
result $? "pap-new-31: no main ruleset stops at the repository settings; no agent token is requested and no welcome session starts" "$out"
world
: > "$W/gh/apply-bypass"
run '\n' trial
[ "$rc" = 1 ] && has 'cause: the main ruleset: the main ruleset of olive/trial has a bypass actor' &&
  [ "$(count 'POST' "$W/api/log")" = 0 ] && [ ! -f "$W/claude.args" ]
result $? "pap-new-31: a main ruleset with a bypass actor stops the same way" "$out"

world
installation olive selected
: > "$W/api/deny-once-trial"
run '\n\n' trial
has 'warn *the agent installation on olive does not cover trial' && has 'add trial to it: https://github.com/settings/installations/42' &&
  has 'Press Enter to request the agent token again'
result $? "pap-new-11: an uncovered repository is said, with the installation's settings URL, and the run waits for Enter" "$out"
[ "$(count 'REQ POST' "$W/api/log")" = 2 ] && welcomed && has 'prompts taken 2'
result $? "pap-new-11: on Enter the agent token is requested again, and the welcome session starts only once it is minted" "$(cat "$W/api/log")"
world
: > "$W/api/deny-trial"
run '\n' trial
[ "$rc" = 1 ] && has '^stop  *step 6 of 6, agent token$' && [ ! -f "$W/claude.args" ]
result $? "pap-new-11: no welcome session starts while no agent token is minted" "$out"

world
: > "$W/api/deny-trial"
mkfifo "$W/in"
( cd "$W/cwd" && exec sh "$pap" new trial --yes < "$W/in" > "$W/out" 2>&1 ) &
pid=$!
exec 9> "$W/in"
i=0
while ! grep -q 'Press Enter to request' "$W/out" 2>/dev/null && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i + 1)); done
# TERM stands in for Ctrl-C: a background job of a non-interactive shell
# starts with INT ignored. pap traps the two alike.
kill -TERM "$pid"
wait "$pid"; rc=$?
exec 9>&-
out="$(cat "$W/out")"
[ "$rc" = 1 ] && has '^stop  *step 6 of 6, agent token$' && has 'cause: the run was interrupted' &&
  has 'run again: pap new trial --owner olive' && [ ! -f "$W/claude.args" ]
result $? "pap-new-32: an interrupt at the wait for the agent token is a stop with the command to run again; no welcome session starts" "$out"

# --- A re-run goes on from what exists ----------------------------------------

for state in committed created pushed "set up" "settings applied"; do
  world
  stopped_at "$state"
  head_before="$(git -C "$W/cwd/trial" rev-parse main)"
  run '\n' trial
  case "$state" in
    committed) want="gh repo create push mise run setup sync apply claude " ;;
    created) want="push mise run setup sync apply claude " ;;
    pushed) want="mise run setup sync apply claude " ;;
    "set up") want="sync apply claude " ;;
    *) want="claude " ;;
  esac
  [ "$first_rc" = 1 ] && [ "$(tr '\n' ' ' < "$W/events")" = "$want" ] &&
    [ "$(git -C "$W/cwd/trial" rev-parse main)" = "$head_before" ] && [ "$(pushes)" = 1 ] && has 're-run yes'
  result $? "pap-new-12: from '$state', no commit, repository creation or push already made is made again" "$(cat "$W/events"; echo "$first_out" | tail -n 8)"
  welcomed && [ "$(commits)" = 1 ]
  result $? "pap-new-12: from '$state', the run reaches the welcome session and main holds exactly one commit" "$out"
done

world
: > "$W/kill-at-commit"
run '\n' trial
[ "$rc" != 0 ] && [ ! -e "$W/cwd/trial" ] && [ ! -d "$W/gh/repos" ]
result $? "pap-new-33: an interrupted first commit leaves nothing named trial behind" "$out; $(ls -A "$W/cwd")"
run '\n' trial
welcomed && [ "$(commits)" = 1 ] && has 're-run no'
result $? "pap-new-33: the re-run makes the first commit and reaches the welcome session" "$out"

world
stopped_at pushed
rm -rf "$W/cwd/trial"
run '\n' trial
welcomed && has 'ok *cloned olive/trial into ./trial' && [ "$(tr '\n' ' ' < "$W/events")" = "mise run setup sync apply claude " ] &&
  [ "$(git -C "$W/cwd/trial" config --get remote.origin.url)" = "https://github.com/olive/trial.git" ]
result $? "pap-new-34: a pushed repository with no clone is cloned, and the run goes on from clone setup" "$out"
[ "$(pushes)" = 1 ] && ! grep -q '^push$' "$W/events"
result $? "pap-new-34: nothing is pushed"

for more in "only the first commit" "the first commit and later merged pull requests"; do
  world
  run '\n' trial
  if [ "$more" != "only the first commit" ]; then
    # A pull request merged on GitHub: a second commit on the remote's main,
    # not in the clone.
    git clone -q "$W/remotes/olive/trial.git" "$W/other" 2>/dev/null
    (cd "$W/other" && echo more > more.txt && git add more.txt && git commit -qm "feat: more (#1)" && git push -q origin main) >/dev/null 2>&1
  fi
  : > "$W/events"; : > "$W/gh/log"; rm -f "$W/gh/sync.log" "$W/claude.args" "$W/claude.pwd"
  before="$(pushes) $(git -C "$W/cwd/trial" rev-parse main)"
  run '\n' trial
  [ "$(tr '\n' ' ' < "$W/events")" = "claude " ] && [ "$before" = "$(pushes) $(git -C "$W/cwd/trial" rev-parse main)" ] &&
    ! grep -q 'repo create' "$W/gh/log"
  result $? "pap-new-35: with main holding $more, a re-run makes no commit, repository creation or push" "$(cat "$W/events")"
  [ "$(cat "$W/gh/sync.log")" = "status olive/trial" ]
  result $? "pap-new-35: with main holding $more, the repository settings are not written" "$(cat "$W/gh/sync.log")"
  welcomed && grep -q "^GH_CONFIG_DIR=$W/xdg/gh-agent\$" "$W/claude.env" && has 'steps done 6 of 6'
  result $? "pap-new-35: with main holding $more, a welcome session starts in the clone as the agent" "$out"
done

world
stopped_at committed --layers base go
before="$(git -C "$W/cwd/trial" rev-parse main) $(cat "$W/cwd/trial/.config/pap.toml")"
run '\n' trial --layers base dotnet
preflight_stop && has 'cause: the recorded layers are base go, not base dotnet' && has 're-run yes' &&
  [ "$before" = "$(git -C "$W/cwd/trial" rev-parse main) $(cat "$W/cwd/trial/.config/pap.toml")" ] &&
  [ ! -d "$W/gh/repos" ] && [ -z "$(cat "$W/events")" ]
result $? "pap-new-36: a re-run that names other layers stops naming the recorded ones, and nothing is changed" "$out"

not_own() {
  preflight_stop && has "is not this command's own" && has 'Choose another name, or adopt what is there with the brownfield runbook' &&
    has 'agent-onboarding.md#brownfield' && [ -z "$(cat "$W/events")" ] && [ ! -f "$W/gh/sync.log" ]
}
# foreign <owner/name>: a repository on GitHub that pap new did not make.
foreign() {
  mkdir -p "$W/gh/repos/${1%/*}" "$W/remotes/${1%/*}"
  echo '{"private":true}' > "$W/gh/repos/$1"
  git init -q --bare -b main "$W/remotes/$1.git"
}
world
foreign olive/trial
git init -q -b main "$W/theirs" && (cd "$W/theirs" && echo code > main.c && git add -A && git commit -qm "their own" &&
  git push -q "$W/remotes/olive/trial.git" main) >/dev/null 2>&1
run '\n' trial
not_own && has 'the repository olive/trial on GitHub is not' && has "its first commit has no .config/pap.toml" && [ ! -e "$W/cwd/trial" ]
result $? "pap-new-13: a repository on GitHub whose first commit is not the template is left alone" "$out"
world
foreign olive/trial
run '\n' trial
not_own && has 'it is empty and there is no clone here' && [ ! -e "$W/cwd/trial" ]
result $? "pap-new-13: an empty repository on GitHub and no clone is left alone" "$out"
world
mkdir "$W/cwd/trial" && echo notes > "$W/cwd/trial/notes.txt"
run '\n' trial
not_own && has './trial in the current directory is not' && [ "$(ls -A "$W/cwd/trial")" = notes.txt ] && [ ! -d "$W/gh/repos" ]
result $? "pap-new-13: a local directory that is not a git repository is left alone" "$out"
world
git init -q -b main "$W/cwd/trial" && (cd "$W/cwd/trial" && git remote add origin https://github.com/someone/else.git &&
  echo code > main.c && git add -A && git commit -qm "their own") >/dev/null 2>&1
before="$(git -C "$W/cwd/trial" rev-parse main)"
run '\n' trial
not_own && has 'the clone ./trial is not' && has 'its origin is https://github.com/someone/else.git' &&
  [ "$before" = "$(git -C "$W/cwd/trial" rev-parse main)" ] && [ ! -d "$W/gh/repos" ]
result $? "pap-new-13: a local clone of another repository is left alone" "$out"
world
stopped_at pushed
# The clone's first commit rewritten: the same content, another commit.
(cd "$W/cwd/trial" && git commit -q --amend -m "another first commit") >/dev/null 2>&1
before="$(git -C "$W/cwd/trial" rev-parse main)"
run '\n' trial
not_own && has "its first commit differs from the first commit of olive/trial on GitHub" &&
  [ "$before" = "$(git -C "$W/cwd/trial" rev-parse main)" ] && [ "$(pushes)" = 1 ]
result $? "pap-new-13: a clone whose first commit differs from the repository's is left alone" "$out"

# --- The form of the output ---------------------------------------------------

world
run 'n\n' trial
! printf '%s\n' "$out" | grep -q "$(printf '\033')" && has '^ok  ' && has '^stop  '
result $? "output: every status has a text marker, and no colour without a terminal" "$out"

printf '1..%d\n' "$n"
[ "$failed" -eq 0 ]

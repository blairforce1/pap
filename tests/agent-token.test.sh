#!/bin/sh
# agent-token.test.sh: tests for decision 0023's first slice: pap agent-key,
# pap agent-token and the base layer's gh shim (scripts/shim/gh).
#
# Usage: sh tests/agent-token.test.sh
#
# Never touches the network or the real keyring. A fake secret-tool keeps
# the key in a file, a uname stub says Linux so macOS's security is never
# called, and a fake curl is the GitHub endpoint: it answers from response
# files in $FAKE_GH, logs each request with the --config text pap sends on
# stdin (the JWT), and fails as unreachable when FAKE_GH_DOWN is set. pap
# talks to it through PAP_GITHUB_API=http://github.invalid. The key is a
# throwaway RSA key made here. Prints one TAP-style line per case and exits
# 1 if any case fails. Needs git, jq and openssl.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck source=tests/clean-env.sh
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

real_curl="$(command -v curl || true)"
for tool in git jq openssl; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T"
# The machine's system git config (macOS runners set an osxkeychain
# helper) is not this suite's to read.
export GIT_CONFIG_NOSYSTEM=1

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

mkdir "$T/fake" "$T/gh" "$T/xdg" "$T/run" "$T/realgh"
cat > "$T/fake/uname" <<'EOF'
#!/bin/sh
echo Linux
EOF
cat > "$T/fake/secret-tool" <<'EOF'
#!/bin/sh
case "$1" in
  store) cat > "$FAKE_KEYRING" ;;
  lookup) [ -s "$FAKE_KEYRING" ] && cat "$FAKE_KEYRING" ;;
  *) exit 2 ;;
esac
EOF
cat > "$T/fake/curl" <<'EOF'
#!/bin/sh
# Records "<argv>" and the stdin config; answers from $FAKE_GH/<METHOD>_<path>.
[ -z "${FAKE_GH_DOWN:-}" ] || { cat >/dev/null; exit 7; }
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
cfg="$(cat)"
path="/${url#http://github.invalid/}"
printf 'ARGV %s\nREQ %s %s\nCFG %s\nDATA %s\n' "$argv" "$method" "$path" "$cfg" "$data" >> "$FAKE_GH/log"
f="$FAKE_GH/$(printf '%s_%s' "$method" "$path" | tr '/' '_')"
# A scoped mint for a repository with a deny-<name> file: not in the installation.
r="$(printf '%s' "$data" | jq -r '.repositories[0]? // empty' 2>/dev/null)"
[ -z "$r" ] || [ ! -f "$FAKE_GH/deny-$r" ] || f="$FAKE_GH/deny-$r"
if [ -f "$f" ]; then code="$(head -n 1 "$f")"; body="$(tail -n +2 "$f")"
else code=404; body='{"message":"Not Found"}'; fi
# -o names the body's file; without it the body goes to stdout before the code.
if [ -n "$out" ]; then printf '%s\n' "$body" > "$out"; printf '%s' "$code"
else printf '%s\n%s' "$body" "$code"; fi
EOF
# pap on PATH, as mise provides it in an adopting repository.
# shellcheck disable=SC2016 # expands in the stub, not here
printf '#!/bin/sh\nexec sh "%s" "$@"\n' "$pap" > "$T/fake/pap"
# The real gh: logs the token it was given and its arguments. Asked by git
# for a credential with no GH_TOKEN, it answers with the owner's token, as
# gh 2.97 does from the keyring with an empty config directory
# (docs/agent-identity-security.md); with GH_TOKEN, it answers with that.
cat > "$T/realgh/gh" <<EOF
#!/bin/sh
printf 'GH_TOKEN=%s args=%s\\n' "\${GH_TOKEN-<unset>}" "\$*" >> "$T/gh.log"
if [ "\$1 \$2" = "auth git-credential" ]; then
  cat >/dev/null
  printf 'protocol=https\\nhost=github.com\\nusername=x-access-token\\npassword=%s\\n' "\${GH_TOKEN:-gho_OWNER_FROM_KEYRING}"
fi
EOF
chmod +x "$T"/fake/* "$T/realgh/gh"

export PATH="$T/fake:$T/realgh:$PATH"
export FAKE_GH="$T/gh" FAKE_KEYRING="$T/keyring" XDG_CONFIG_HOME="$T/xdg" XDG_RUNTIME_DIR="$T/run"
export PAP_GITHUB_API=http://github.invalid
unset CLAUDECODE REMOTE_CONTAINERS GH_TOKEN 2>/dev/null || true

openssl genrsa -out "$T/app.pem" 2048 2>/dev/null
openssl rsa -in "$T/app.pem" -pubout -out "$T/app.pub" 2>/dev/null

# An adopting repository whose origin is on GitHub, and one that is not.
mkrepo() {
  git init -q -b main "$1"
  git -C "$1" remote add origin "https://github.com/example-owner/$(basename "$1").git"
}
mkrepo "$T/repo"
mkdir -p "$T/repo/scripts/shim"
cp "$here/scripts/guard-branch.sh" "$T/repo/scripts/guard-branch.sh"
cp "$here/scripts/shim/gh" "$T/repo/scripts/shim/gh"
mkrepo "$T/plain"

future() { jq -nr --argjson s "$1" 'now + $s | floor | todate'; }
answer() { # answer <file> <code> <body>
  printf '%s\n%s\n' "$2" "$3" > "$FAKE_GH/$1"
}
installed() { # the fake GitHub has pap-agent on example-owner, token valid <s>
  answer GET__users_example-owner_installation 200 '{"id":4242}'
  answer POST__app_installations_4242_access_tokens 201 \
    "{\"token\":\"ghs_fake_$2\",\"expires_at\":\"$(future "$1")\"}"
}
requests() { grep -c '^REQ' "$FAKE_GH/log" 2>/dev/null || true; }
p() { (cd "$T/repo" && sh "$pap" "$@"); }

# --- agent-key -----------------------------------------------------------------

out="$(p agent-key import "$T/app.pem" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'no client id yet' && [ ! -e "$FAKE_KEYRING" ]
result $? "agent-key import: refuses without a client id, stores nothing" "$out"

printf 'not a key\n' > "$T/bad.pem"
out="$(p agent-key import "$T/bad.pem" --client-id Iv1.example 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'not a private key' && [ ! -e "$FAKE_KEYRING" ]
result $? "agent-key import: refuses a file that is not a key" "$out"

out="$(p agent-key status 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q '^key        missing'
result $? "agent-key status: no key, exits 1" "$out"

out="$(p agent-key import "$T/app.pem" --client-id Iv1.example 2>&1)"; rc=$?
[ "$rc" = 0 ] && cmp -s "$FAKE_KEYRING" "$T/app.pem" &&
  printf '%s\n' "$out" | grep -q "Now delete $T/app.pem" &&
  ! printf '%s\n' "$out" | grep -q 'PRIVATE KEY' &&
  grep -qx 'client_id=Iv1.example' "$T/xdg/pap/agent.conf"
result $? "agent-key import: key in the keyring, client id in the XDG config, nothing secret printed, says delete" "$out"

out="$(p agent-key status 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q '^key        in the keyring' &&
  printf '%s\n' "$out" | grep -q '^client id  Iv1.example' && ! printf '%s\n' "$out" | grep -q 'PRIVATE'
result $? "agent-key status: key and client id, exits 0, no key text" "$out"

# --- agent-token ----------------------------------------------------------------

installed 3600 one
before="$(date +%s)"
tok="$(p agent-token 2>"$T/err")"; rc=$?
after="$(date +%s)"
[ "$rc" = 0 ] && [ "$tok" = ghs_fake_one ] && [ ! -s "$T/err" ]
result $? "agent-token: prints the installation token alone, stderr empty" "rc=$rc tok=$tok $(cat "$T/err")"

grep -q '^REQ GET /users/example-owner/installation$' "$FAKE_GH/log" &&
  grep -q '^REQ POST /app/installations/4242/access_tokens$' "$FAKE_GH/log" &&
  grep -qx 'installation.example-owner=4242' "$T/xdg/pap/agent.conf"
result $? "agent-token: finds the owner's installation from origin and keeps its id" "$(cat "$FAKE_GH/log")"

# The JWT, as pap sent it to curl on stdin.
jwt="$(sed -n 's/^CFG header = "Authorization: Bearer \(.*\)"$/\1/p' "$FAKE_GH/log" | tail -n 1)"
b64d() { s="$(printf '%s' "$1" | tr '_-' '/+')"; while [ $((${#s} % 4)) != 0 ]; do s="$s="; done; printf '%s' "$s" | openssl base64 -d -A; }
h="${jwt%%.*}" rest="${jwt#*.}"; pl="${rest%%.*}" sig="${rest#*.}"
hdr="$(b64d "$h")"; claims="$(b64d "$pl")"
printf '%s' "$h.$pl" > "$T/jwt-in"; b64d "$sig" > "$T/jwt-sig"
[ "$(printf '%s' "$hdr" | jq -r .alg)" = RS256 ] &&
  openssl dgst -sha256 -verify "$T/app.pub" -signature "$T/jwt-sig" "$T/jwt-in" >/dev/null 2>&1
result $? "agent-token: the JWT is RS256 and verifies against the app's public key" "$hdr"
iss="$(printf '%s' "$claims" | jq -r .iss)"; iat="$(printf '%s' "$claims" | jq -r .iat)"; exp="$(printf '%s' "$claims" | jq -r .exp)"
[ "$iss" = Iv1.example ] && [ $((exp - iat)) -le 600 ] && [ $((exp - iat)) -ge 540 ] &&
  [ "$iat" -le "$before" ] && [ "$exp" -le $((after + 600)) ] && [ "$exp" -gt "$after" ]
result $? "agent-token: iss is the client id, exp within ten minutes, iat not ahead of now" "$claims (now $before..$after)"
! grep '^ARGV' "$FAKE_GH/log" | grep -qF "$jwt" && ! grep '^ARGV' "$FAKE_GH/log" | grep -q 'Bearer'
result $? "agent-token: the JWT never reaches curl's argv" "$(grep '^ARGV' "$FAKE_GH/log")"

cache="$T/run/pap-agent-$(id -u)/token-example-owner"
[ "$(stat -c %a "$cache" 2>/dev/null || stat -f %Lp "$cache")" = 600 ] &&
  [ "$(stat -c %a "$T/run/pap-agent-$(id -u)" 2>/dev/null || stat -f %Lp "$T/run/pap-agent-$(id -u)")" = 700 ] &&
  grep -q ' ghs_fake_one$' "$cache"
result $? "agent-token: caches the token at mode 0600 in a 0700 runtime directory" "$(ls -la "$T/run/pap-agent-$(id -u)" 2>&1)"

was="$(requests)"
installed 3600 two
tok="$(p agent-token 2>&1)"
[ "$tok" = ghs_fake_one ] && [ "$(requests)" = "$was" ]
result $? "agent-token: reuses a cached token with more than five minutes left, no request" "tok=$tok requests $was -> $(requests)"

printf '%s ghs_fake_one\n' "$(($(date +%s) + 200))" > "$cache"
tok="$(p agent-token 2>&1)"
[ "$tok" = ghs_fake_two ] && [ "$(requests)" -gt "$was" ] && grep -q ' ghs_fake_two$' "$cache"
result $? "agent-token: refreshes a token with under five minutes left" "tok=$tok"

# Errors, each one line. A fresh runtime directory so nothing is cached.
fresh() { rm -rf "$T/run" && mkdir "$T/run"; }
fresh
out="$(cd "$T/repo" && FAKE_GH_DOWN=1 sh "$pap" agent-token 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] && printf '%s\n' "$out" | grep -q 'GitHub unreachable'
result $? "agent-token: GitHub unreachable, one line, exits 1" "$out"

fresh
out="$(p agent-token --owner other-owner 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "pap: agent-token: pap-agent is not installed on other-owner; install it there with this repository selected (pap agent-setup)" ]
result $? "agent-token: no installation for the owner, one line, exits 1" "$out"

fresh
out="$(cd "$T/plain" && git remote set-url origin "$T/elsewhere.git" && sh "$pap" agent-token 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'origin is not a GitHub remote'
result $? "agent-token: no --owner and a non-GitHub origin" "$out"
git -C "$T/plain" remote set-url origin https://github.com/example-owner/plain.git

mv "$FAKE_KEYRING" "$T/keyring.away"
out="$(p agent-token 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "pap: agent-token: no pap-agent key in the keyring; run pap agent-key import <pem> --client-id <id>" ]
result $? "agent-token: no key, one line naming the import" "$out"
mv "$T/keyring.away" "$FAKE_KEYRING"

answer POST__app_installations_4242_access_tokens 401 '{"message":"A JSON web token could not be decoded"}'
out="$(p agent-token 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'GitHub refused an installation token for example-owner (HTTP 401: A JSON web token' &&
  ! printf '%s\n' "$out" | grep -qF "$jwt"
result $? "agent-token: a refusal names the status and message, never the JWT" "$out"

# --- the gh shim ------------------------------------------------------------------

installed 3600 shim
fresh
shim="$T/repo/scripts/shim/gh"
gh_run() { # gh_run <dir> [env...]: the shim, first on PATH, from <dir>
  dir="$1"; shift
  : > "$T/gh.log"
  # GH_CONFIG_DIR as pap claude sets it (rule 23.4); a case may override it.
  (cd "$dir" && env PATH="$T/repo/scripts/shim:$PATH" GH_CONFIG_DIR="$T/xdg/gh-agent" "$@" gh pr list 2>&1)
}
mkdir -p "$T/xdg/gh-agent"
out="$(gh_run "$T/repo" CLAUDECODE=1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list' "$T/gh.log"
result $? "shim: CLAUDECODE in an adopting repository runs the real gh with GH_TOKEN" "$out $(cat "$T/gh.log")"

out="$(gh_run "$T/repo" GH_CONFIG_DIR="$T/xdg/gh")"
grep -qx 'GH_TOKEN=<unset> args=pr list' "$T/gh.log"
result $? "shim: a person's terminal (no CLAUDECODE, gh's own directory), gh unchanged" "$(cat "$T/gh.log")"

out="$(gh_run "$T/plain" CLAUDECODE=1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list' "$T/gh.log" &&
  grep '^DATA' "$FAKE_GH/log" | tail -n 1 | grep -qx 'DATA {"repositories":\["plain"\]}'
result $? "shim: a pap claude session in a repository that does not adopt PAP mints too, scoped to origin's repository" "$out $(cat "$T/gh.log")"

# Rule 23.4: an agent session not started by pap claude is refused.
for v in '' "$T/xdg/gh"; do
  out="$(gh_run "$T/repo" CLAUDECODE=1 GH_CONFIG_DIR="$v")"; rc=$?
  [ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] &&
    printf '%s\n' "$out" | grep -q "^gh (pap shim): this Claude Code session was not started with pap claude (GH_CONFIG_DIR is ${v:-unset}, not $T/xdg/gh-agent).*quit and run pap claude (rule 23.4)$"
  result $? "shim: GH_CONFIG_DIR ${v:-unset}, not the agent directory: refused naming pap claude, gh never runs" "rc=$rc $out $(cat "$T/gh.log")"
done
printf 'ghe.example.com:\n    user: example-owner\n' > "$T/xdg/gh-agent/hosts.yml"
out="$(gh_run "$T/repo" CLAUDECODE=1)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] && printf '%s\n' "$out" | grep -q 'hosts.yml holds a sign-in'
result $? "shim: an agent directory holding any sign-in, a GHE host included, is refused, gh never runs" "rc=$rc $out"
rm "$T/xdg/gh-agent/hosts.yml"
out="$(gh_run "$T/plain" CLAUDECODE=1 GH_CONFIG_DIR=)"
grep -qx 'GH_TOKEN=<unset> args=pr list' "$T/gh.log"
result $? "shim: outside an adopting repository the directory is not checked (rule 23.4's escape)" "$out"

mv "$FAKE_KEYRING" "$T/keyring.away"; fresh
out="$(gh_run "$T/repo" CLAUDECODE=1 GH_TOKEN=stored-sign-in)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] &&
  printf '%s\n' "$out" | grep -q '^gh (pap shim): no pap-agent key in the keyring; .*Not falling back to a stored sign-in (rule 23.1)$'
result $? "shim: minting fails, names the reason, exits 1, never runs gh" "rc=$rc $out $(cat "$T/gh.log")"

out="$(gh_run "$T/repo" CLAUDECODE=1 REMOTE_CONTAINERS=true)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=<unset> args=pr list' "$T/gh.log"
result $? "shim: a dev container with no key steps aside" "$out $(cat "$T/gh.log")"
mv "$T/keyring.away" "$FAKE_KEYRING"

out="$(gh_run "$T/repo" CLAUDECODE=1 REMOTE_CONTAINERS=true)"
grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list' "$T/gh.log"
result $? "shim: a dev container with a key still mints" "$(cat "$T/gh.log")"

fresh
out="$(gh_run "$T/repo" CLAUDECODE=1 FAKE_GH_DOWN=1)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] && printf '%s\n' "$out" | grep -q '^gh (pap shim): GitHub unreachable'
result $? "shim: GitHub unreachable, exits 1, never runs gh" "$out"

# A pap that warns on stderr: the warning stays out of GH_TOKEN.
mkdir "$T/noisy"
# shellcheck disable=SC2016 # expands in the stub, not here
printf '#!/bin/sh\necho "mise WARN  a newer mise is available" >&2\nexec sh "%s" "$@"\n' "$pap" > "$T/noisy/pap"
chmod +x "$T/noisy/pap"
out="$(gh_run "$T/repo" CLAUDECODE=1 PATH="$T/repo/scripts/shim:$T/noisy:$PATH")"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list' "$T/gh.log"
result $? "shim: a warning on pap's stderr never reaches GH_TOKEN" "$out $(cat "$T/gh.log")"

# Two more copies of the shim ahead of it on PATH: none of them recurses.
mkdir -p "$T/copy1" "$T/copy2"
cp "$shim" "$T/copy1/gh"; cp "$shim" "$T/copy2/gh"
: > "$T/gh.log"
# A shim that recursed would never return: cap it where timeout exists.
to=""; command -v timeout >/dev/null 2>&1 && to="$(command -v timeout) 10"
# shellcheck disable=SC2086 # $to is empty or two words on purpose
out="$(cd "$T/repo" && env PATH="$T/copy1:$T/copy2:$T/repo/scripts/shim:$PATH" $to gh pr list 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$(wc -l < "$T/gh.log")" -eq 1 ]
result $? "shim: copies of the shim on PATH are skipped; the real gh runs once" "rc=$rc $out"

mkdir "$T/empty"
# shellcheck disable=SC2086 # $to as above
out="$(cd "$T/repo" && env PATH="$T/repo/scripts/shim:$T/empty" $to gh pr list 2>&1)"; rc=$?
[ "$rc" = 127 ] && printf '%s\n' "$out" | grep -q 'no gh on PATH besides this shim'
result $? "shim: no real gh, exits 127 naming it" "rc=$rc $out"

# --- the shim in every directory (the owner-token finding) -------------------
# Before this, a pap claude shell outside an adopting repository ran the real
# gh unchanged, and gh's git-credential answered with the owner's keyring
# token (the fake real gh above models it). Every case here is a pap claude
# session: CLAUDECODE set and GH_CONFIG_DIR the agent directory.

installed 3600 shim
fresh
agd="$T/xdg/gh-agent"
sp="$T/repo/scripts/shim:$PATH"
credreq() { # credreq <dir> <request>: the shim as git's helper
  : > "$T/gh.log"
  (cd "$1" && printf '%b\n' "$2" | env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE=1 gh auth git-credential get 2>"$T/cred.err")
}
for d in plain repo; do
  out="$(credreq "$T/$d" "protocol=https\nhost=github.com\npath=example-owner/$d.git\n")"; rc=$?
  [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx 'password=ghs_fake_shim' &&
    printf '%s\n' "$out" | grep -qx 'username=x-access-token' &&
    ! printf '%s\n' "$out" | grep -q gho_OWNER && [ ! -s "$T/gh.log" ] &&
    grep '^DATA' "$FAKE_GH/log" | tail -n 1 | grep -qx "DATA {\"repositories\":\\[\"$d\"\\]}"
  result $? "shim: git-credential in the $d repository answers a token scoped to the request's path, never the owner's" "rc=$rc $out $(cat "$T/cred.err" "$T/gh.log")"
done

# git itself, end to end, with no network: credential fill runs the helper.
gitfill() { # gitfill <dir> <url>
  (cd "$1" && printf 'url=%s\n\n' "$2" |
    env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE=1 GIT_TERMINAL_PROMPT=0 GIT_ASKPASS= SSH_ASKPASS= \
      git -c credential.helper= -c 'credential.helper=!gh auth git-credential' -c credential.useHttpPath=true credential fill 2>"$T/cred.err")
}
out="$(gitfill "$T/plain" https://github.com/example-owner/elsewhere.git)"; rc=$?
[ "$rc" = 0 ] && printf '%s\n' "$out" | grep -qx 'password=ghs_fake_shim' &&
  grep '^DATA' "$FAKE_GH/log" | tail -n 1 | grep -qx 'DATA {"repositories":\["elsewhere"\]}'
result $? "shim: git credential fill for any github.com repository goes through the shim's scoped token" "rc=$rc $out $(cat "$T/cred.err")"

printf '422\n{"message":"There is at least one repository that does not exist or is not accessible to the parent installation."}\n' > "$FAKE_GH/deny-private-companion"
out="$(gitfill "$T/plain" https://github.com/example-owner/private-companion.git)"; rc=$?
[ "$rc" != 0 ] && ! printf '%s\n' "$out" | grep -q '^password=' &&
  grep -q "^gh (pap shim): pap-agent's installation on example-owner does not cover example-owner/private-companion; add the repository on the installation's page (pap agent-setup opens it)" "$T/cred.err"
result $? "shim: a repository the installation does not cover is refused by name, and no other credential answers" "rc=$rc $out $(cat "$T/cred.err")"
out="$(credreq "$T/plain" "protocol=https\nhost=github.com\npath=example-owner/private-companion.git\n")"; rc=$?
[ "$rc" = 1 ] && [ "$out" = quit=1 ] && [ ! -s "$T/gh.log" ]
result $? "shim: the refused credential tells git quit=1, and the real gh is never asked" "rc=$rc $out"

out="$(credreq "$T/plain" "protocol=https\nhost=github.com\n")"; rc=$?
[ "$rc" = 1 ] && [ "$out" = quit=1 ] && [ ! -s "$T/gh.log" ] && grep -q 'no repository path.*useHttpPath true' "$T/cred.err"
result $? "shim: a credential request with no path is refused naming useHttpPath" "rc=$rc $out $(cat "$T/cred.err")"
out="$(credreq "$T/plain" "protocol=https\nhost=ghe.example.com\npath=example-owner/plain.git\n")"; rc=$?
[ "$rc" = 1 ] && [ "$out" = quit=1 ] && [ ! -s "$T/gh.log" ] && grep -q 'answers only for https://github.com' "$T/cred.err"
result $? "shim: a credential request for another host is refused" "rc=$rc $out $(cat "$T/cred.err")"

ghx() { # ghx <dir> [VAR=value...] <gh args...>: the shim in a pap claude session
  dir="$1"; shift
  : > "$T/gh.log"
  (cd "$dir" && env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE=1 gh "$@" 2>&1)
}
lastrepo() { grep '^DATA' "$FAKE_GH/log" | tail -n 1 | sed 's/^DATA //' | jq -r '.repositories[0]'; }
mkdir -p "$T/norepo"
out="$(ghx "$T/norepo" api /user)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] && printf '%s\n' "$out" | grep -q '^gh (pap shim): no repository to act for'
result $? "shim: a call with no repository context is refused, the real gh never runs" "rc=$rc $out"
out="$(ghx "$T/norepo" pr list -R example-owner/other)"; rc=$?
[ "$rc" = 0 ] && [ "$(lastrepo)" = other ] && grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list -R example-owner/other' "$T/gh.log"
result $? "shim: -R names the repository the token is scoped to" "rc=$rc $out"
out="$(ghx "$T/plain" api --method GET repos/example-owner/third/pulls)"; rc=$?
[ "$rc" = 0 ] && [ "$(lastrepo)" = third ]
result $? "shim: gh api repos/<owner>/<name>/... is scoped to that repository" "rc=$rc $out $(lastrepo)"
out="$(ghx "$T/plain" pr list --repo=https://github.com/other-owner/x.git)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ] && printf '%s\n' "$out" | grep -q 'pap-agent is not installed on other-owner'
result $? "shim: no installation for the repository's owner, refused, the real gh never runs" "rc=$rc $out"
out="$(ghx "$T/plain" pr list -R ghe.example.com/example-owner/x)"; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/gh.log" ]
result $? "shim: a repository on another host is refused" "rc=$rc $out"

mv "$FAKE_KEYRING" "$T/keyring.away"; fresh
: > "$T/gh.log"
out="$(cd "$T/norepo" && env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE=1 REMOTE_CONTAINERS=true gh api /user 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=<unset> args=api /user' "$T/gh.log"
result $? "shim: a dev container with no key steps aside in any directory" "rc=$rc $out"
mv "$T/keyring.away" "$FAKE_KEYRING"

out="$(cd "$T/plain" && env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE= gh pr list 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -qx 'GH_TOKEN=ghs_fake_shim args=pr list' "$T/gh.log"
result $? "shim: CLAUDECODE unset with the agent directory is still a pap claude session, minted" "rc=$rc $out $(cat "$T/gh.log")"
out="$(ghx "$T/plain" api 'repos/{owner}/{repo}/pulls')"; rc=$?
[ "$rc" = 0 ] && [ "$(lastrepo)" = plain ]
result $? "shim: gh api repos/{owner}/{repo} placeholders fall back to origin" "rc=$rc $out $(lastrepo)"
out="$(credreq "$T/plain" "protocol=https\nhost=github.com\npath=example-owner/lfsrepo.git/info/lfs\n")"; rc=$?
[ "$rc" = 0 ] && [ "$(lastrepo)" = lfsrepo ]
result $? "shim: a Git LFS credential path is scoped to its repository" "rc=$rc $out $(cat "$T/cred.err")"
git -C "$T/plain" remote set-url origin https://someone:s3cret@git.example.com/x.git
out="$(ghx "$T/plain" pr list)"; rc=$?
[ "$rc" = 1 ] && ! printf '%s\n' "$out" | grep -q s3cret && printf '%s\n' "$out" | grep -qF 'origin (https://git.example.com/x.git)'
result $? "shim: a refused origin is named without its userinfo" "rc=$rc $out"
git -C "$T/plain" remote set-url origin https://github.com/example-owner/plain.git
for args in "--repo justname" "--repo example-owner/a --owner other-owner" "--owner other-owner --repo example-owner/a"; do
  # shellcheck disable=SC2086 # split on purpose
  out="$(p agent-token $args 2>&1)"; rc=$?
  [ "$rc" = 64 ]
  result $? "agent-token: $args is a usage error" "rc=$rc $out"
done

# The hook's question: a session not started by pap claude fails the check
# in any directory, so the hook can refuse outside adopting repositories.
(cd "$T/norepo" && env PATH="$sp" GH_CONFIG_DIR= CLAUDECODE=1 PAP_SHIM_CHECK=1 gh >/dev/null 2>&1); rc1=$?
(cd "$T/norepo" && env PATH="$sp" GH_CONFIG_DIR="$agd" CLAUDECODE=1 PAP_SHIM_CHECK=1 gh >/dev/null 2>&1); rc2=$?
[ "$rc1" = 1 ] && [ "$rc2" = 0 ]
result $? "shim: check mode answers the session question outside a repository too" "rc1=$rc1 rc2=$rc2"

# --- agent-setup ---------------------------------------------------------------

if ! command -v python3 >/dev/null 2>&1 || [ -z "$real_curl" ]; then
  printf 'ok %d - # SKIP agent-setup: no python3 or curl\n' "$((n + 1))"; n=$((n + 1))
else
  # The browser: on the loopback form it saves the page and answers the
  # callback with the form's state (or a wrong one, FAKE_STATE=bad); on the
  # install page it records the URL and installs the app on the fake GitHub.
  cat > "$T/fake/browser" <<EOF
#!/bin/sh
echo "\$1" >> "$T/opened.log"
case "\$1" in
  http://127.0.0.1:*)
    "$real_curl" -s "\$1" > "$T/form.html"
    st="\$(sed -n 's/.*?state=\([0-9a-f]*\)".*/\1/p' "$T/form.html")"
    [ "\${FAKE_STATE:-}" != bad ] || st=0000
    "$real_curl" -s -o /dev/null -w 'callback %{http_code}\n' "\${1}callback?code=fakecode&state=\$st" >> "$T/opened.log" ;;
  https://github.com/apps/*/installations/new)
    printf '200\n{"id":5151}\n' > "$FAKE_GH/GET__users_\${FAKE_OWNER:-example-owner}_installation" ;;
esac
EOF
  chmod +x "$T/fake/browser"
  export PAP_SETUP_TIMEOUT=20 PAP_BROWSER="$T/fake/browser" HOME="$T/home" GIT_CONFIG_GLOBAL="$T/gitconfig" TMPDIR="$T/tmp"
  mkdir -p "$T/home" "$T/tmp"
  git config --global credential.https://github.com.helper '!gh auth git-credential'
  setup_reset() { : > "$FAKE_KEYRING"; rm -f "$T/xdg/pap/agent.conf" "$T/opened.log" "$T/form.html" "$FAKE_GH"/*; fresh; }
  conversion() { # the fake GitHub's answer to the code, with the pem and two secrets
    jq -n --rawfile pem "$T/app.pem" '{id: 1, slug: "example-owner-pap-agent", client_id: "Iv1.setup",
      client_secret: "client-secret-xyz", webhook_secret: "webhook-secret-xyz", pem: $pem}' > "$T/conv.json"
    { echo 201; cat "$T/conv.json"; } > "$FAKE_GH/POST__app-manifests_fakecode_conversions"
  }
  setup_reset; conversion
  answer GET__users_example-owner 200 '{"login":"example-owner","type":"User"}'
  installed 3600 setup
  out="$(printf 'n\n' | p agent-setup 2>&1)"; rc=$?
  m="$(sed -n 's/.*name=manifest value="\([^"]*\)".*/\1/p' "$T/form.html" | sed 's/&quot;/"/g; s/&amp;/\&/g')"
  printf '%s' "$m" | jq -e '.name == "example-owner-pap-agent" and .public == true and .hook_attributes.active == false
      and .default_permissions == {contents: "write", pull_requests: "write", workflows: "write", checks: "read", statuses: "read", metadata: "read"}
      and (.redirect_url | test("^http://127\\.0\\.0\\.1:[0-9]+/callback$")) and .default_events == []' >/dev/null &&
    grep -q 'action="https://github.com/settings/apps/new?state=[0-9a-f]\{32\}"' "$T/form.html"
  result $? "agent-setup: posts exactly 0023's manifest to the personal account's form, with a state" "$m"
  [ "$rc" = 0 ] && cmp -s "$FAKE_KEYRING" "$T/app.pem" &&
    grep -qx 'client_id=Iv1.setup' "$T/xdg/pap/agent.conf" && grep -qx 'slug=example-owner-pap-agent' "$T/xdg/pap/agent.conf" &&
    printf '%s\n' "$out" | grep -q 'is installed on example-owner (installation 4242)'
  result $? "agent-setup: the converted key is in the keyring, client id and slug in the config, installation confirmed" "rc=$rc $out"
  ! printf '%s\n' "$out" | grep -qE 'PRIVATE KEY|client-secret-xyz|webhook-secret-xyz' &&
    ! grep -rqlE 'PRIVATE KEY|client-secret-xyz' "$T/tmp" "$T/run" "$T/xdg" "$T/home" 2>/dev/null &&
    ! grep -E '^ARGV' "$FAKE_GH/log" | grep -qE 'PRIVATE KEY|client-secret-xyz|webhook-secret-xyz'
  result $? "agent-setup: the pem and secrets are never printed nor written outside the keyring" "$out"

  was="$(grep -c '^REQ POST /app-manifests' "$FAKE_GH/log")"
  out="$(printf 'n\n' | p agent-setup 2>&1)"; rc=$?
  [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'registration skipped' &&
    [ "$(grep -c '^REQ POST /app-manifests' "$FAKE_GH/log")" = "$was" ]
  result $? "agent-setup: a second run with the key here skips registration" "$out"

  setup_reset; conversion
  answer GET__users_example-org 200 '{"login":"example-org","type":"Organization"}'
  answer GET__users_example-org_installation 200 '{"id":4343}'
  answer POST__app_installations_4343_access_tokens 201 "{\"token\":\"ghs_fake_org\",\"expires_at\":\"$(future 3600)\"}"
  out="$(printf 'n\n' | p agent-setup --owner example-org --name example-org-agent 2>&1)"; rc=$?
  [ "$rc" = 1 ] && cmp -s "$FAKE_KEYRING" "$T/app.pem" &&
    printf '%s\n' "$out" | grep -q 'installed on example-org (installation 4343)' && grep -q 'action="https://github.com/organizations/example-org/settings/apps/new?state=' "$T/form.html" &&
    sed -n 's/.*name=manifest value="\([^"]*\)".*/\1/p' "$T/form.html" | grep -q '&quot;name&quot;: &quot;example-org-agent&quot;'
  result $? "agent-setup: an organisation's form, and --name" "rc=$rc $out"

  setup_reset; conversion
  answer GET__users_example-owner 200 '{"login":"example-owner","type":"User"}'
  out="$(cd "$T/repo" && FAKE_STATE=bad PAP_SETUP_TIMEOUT=10 sh "$pap" agent-setup < /dev/null 2>&1)"; rc=$?
  [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'no answer from GitHub in time' && [ ! -s "$FAKE_KEYRING" ] &&
    grep -qx 'callback 400' "$T/opened.log" &&
    ! grep -q '^REQ POST /app-manifests' "$FAKE_GH/log"
  result $? "agent-setup: a callback with the wrong state is refused; nothing converted or stored" "rc=$rc $out"

  out="$(p agent-setup --name 'bad name; rm' 2>&1 < /dev/null)"; rc=$?
  out2="$(p agent-setup --name abcdefghijklmnopqrstuvwxyz0123456789 2>&1 < /dev/null)"; rc2=$?
  [ "$rc" = 1 ] && [ "$rc2" = 1 ] && printf '%s\n%s\n' "$out" "$out2" | grep -c 'not a usable app name' | grep -qx 2
  result $? "agent-setup: refuses an app name GitHub would not take" "$out / $out2"
  # A listener left behind when pap is stopped mid-wait would hold the port.
  setup_reset; conversion
  answer GET__users_example-owner 200 '{"login":"example-owner","type":"User"}'
  (cd "$T/repo" && PAP_BROWSER=true exec sh "$pap" agent-setup < /dev/null > "$T/stopped.out" 2>&1) &
  spid=$!
  i=0; until grep -q '127.0.0.1' "$T/stopped.out" 2>/dev/null || [ "$i" -ge 300 ]; do sleep 0.1; i=$((i + 1)); done
  kill "$spid" 2>/dev/null; wait "$spid" 2>/dev/null
  sleep 1
  port="$(sed -n 's#.*http://127.0.0.1:\([0-9]*\)/.*#\1#p' "$T/stopped.out")"
  [ -n "$port" ] && ! "$real_curl" -s -m 2 -o /dev/null "http://127.0.0.1:$port/"
  result $? "agent-setup: stopping pap mid-wait stops its listener" "port=$port $(cat "$T/stopped.out")"

  # The install page: the app is installed only once the browser has been
  # there; the answers wait for it.
  cp "$T/app.pem" "$FAKE_KEYRING"; printf 'client_id=Iv1.setup\nslug=example-owner-pap-agent\n' > "$T/xdg/pap/agent.conf"
  rm -f "$FAKE_GH/GET__users_example-owner_installation"
  answer POST__app_installations_5151_access_tokens 201 "{\"token\":\"ghs_fake_5151\",\"expires_at\":\"$(future 3600)\"}"
  out="$( { until [ -f "$FAKE_GH/GET__users_example-owner_installation" ]; do sleep 0.1; done; printf '\nn\n'; } | p agent-setup 2>&1)"
  grep -qx 'https://github.com/apps/example-owner-pap-agent/installations/new' "$T/opened.log" &&
    printf '%s\n' "$out" | grep -q 'is installed on example-owner (installation 5151)'
  result $? "agent-setup: opens the install page and confirms the installation with the app's JWT" "$out"

  # The origin and the global rewrite: only on a yes, and never twice.
  git -C "$T/repo" remote set-url origin git@github.com:example-owner/repo.git
  out="$(printf '\n\n' | p agent-setup 2>&1)"
  [ "$(git -C "$T/repo" config remote.origin.url)" = git@github.com:example-owner/repo.git ] &&
    [ -z "$(git config --global --get-all url.https://github.com/.insteadOf)" ] &&
    printf '%s\n' "$out" | grep -qF 'warn     SSH GitHub URLs read as HTTPS  (git config --global --add url."https://github.com/".insteadOf git@github.com:; git config --global --add url."https://github.com/".insteadOf ssh://git@github.com/)'
  result $? "agent-setup: the default answer changes neither origin nor global config; doctor's item warns with the commands" "$out"
  out="$(printf 'y\ny\n' | p agent-setup 2>&1)"
  out2="$(git config --global --unset-all url.https://github.com/.insteadOf 'ssh://' ; git config --global --get-all url.https://github.com/.insteadOf)"
  out="$(printf 'y\n' | p agent-setup 2>&1)"
  [ "$(git -C "$T/repo" config remote.origin.url)" = https://github.com/example-owner/repo.git ] &&
    [ "$(git config --global --get-all url.https://github.com/.insteadOf | sort | tr '\n' ' ')" = "git@github.com: ssh://git@github.com/ " ] &&
    printf '%s\n' "$out" | grep -qF 'ok       SSH GitHub URLs read as HTTPS'
  result $? "agent-setup: yes switches origin and adds each rewrite once, topping up a partial one" "$out2 / $out"
  # A global config git cannot write, as home-manager's link into
  # /nix/store: no stop, the lines to add instead, doctor still runs.
  mkdir -p "$T/nix/store/x-git"
  cat > "$T/nix/store/x-git/config" <<'EOF'
[credential "https://github.com"]
  helper =
  helper = !gh auth git-credential
EOF
  chmod 444 "$T/nix/store/x-git/config"; chmod 555 "$T/nix/store/x-git"
  ln -s "$T/nix/store/x-git/config" "$T/hm-gitconfig"
  out="$(printf 'y\n' | GIT_CONFIG_GLOBAL="$T/hm-gitconfig" p agent-setup 2>&1)"; rc=$?
  chmod 755 "$T/nix/store/x-git"
  [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -q 'is not writable here; it is managed elsewhere' &&
    printf '%s\n' "$out" | grep -qxF '    insteadOf = ssh://git@github.com/' &&
    printf '%s\n' "$out" | grep -qF 'programs.git.settings.url."https://github.com/".insteadOf = [ "git@github.com:" "ssh://git@github.com/" ];' &&
    printf '%s\n' "$out" | grep -q 'pap-agent is set up on this machine' && ! printf '%s\n' "$out" | grep -q 'could not lock'
  result $? "agent-setup: a read-only global config (home-manager) gets the lines to add, and setup carries on" "rc=$rc $out"
  unset PAP_BROWSER
fi

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

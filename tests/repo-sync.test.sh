#!/bin/sh
# repo-sync.test.sh: tests for the required checks in .github/rulesets/main.json,
# their per-check report in scripts/repo-sync.sh status, the all-branches
# ruleset (decision 0022) as status reports it and apply restores it, the
# report of what GitHub makes of .github/CODEOWNERS, and what apply writes:
# the required checks it keeps, adds and removes, and the risk layer's labels.
#
# Usage: sh tests/repo-sync.test.sh
#
# Runs status and apply against a stub gh that serves fixture API responses
# from a temporary directory and logs every write instead of making it, so
# no test reaches GitHub. Prints one
# TAP-style line per case and exits 1 if any case fails. Needs jq and
# mikefarah yq; touches nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
sync="$here/scripts/repo-sync.sh"
ruleset="$here/.github/rulesets/main.json"
branches="$here/.github/rulesets/all-branches.json"

for tool in jq yq bash; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

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

want='tests
pr-checks / checks
security / check
security / gitleaks
security / semgrep
security / trivy'

# --- the ruleset file ---------------------------------------------------------

have="$(jq -r '.rules[] | select(.type == "required_status_checks")
  | .parameters.required_status_checks[].context' "$ruleset")"
[ "$have" = "$want" ]
result $? "ruleset: requires tests, pr-checks and the four security jobs" "$have"
jq -e '.rules[] | select(.type == "required_status_checks")
  | .parameters.strict_required_status_checks_policy == false
    and all(.parameters.required_status_checks[]; .integration_id == 15368)' \
  "$ruleset" >/dev/null
result $? "ruleset: not strict, every check from GitHub Actions"

# GitHub refuses a label description over 100 characters.
long="$(cat "$here/.github/labels.yml" "$here"/.github/labels/*.yml |
  yq -o=json '.' | jq -rs 'add | .[] | select((.description // "") | length > 100) | .name')"
[ -z "$long" ]
result $? "labels: every description is at most 100 characters" "$long"

# --- the tools pap repo needs -------------------------------------------------

# repo-sync.sh refuses to run without mikefarah yq. 0.6.0's base layer did
# not pin it, so `pap repo` died with "yq not found" in a repository that
# had only run `mise install`. The base layer pins it, at the version pap
# pins for itself.
pin() { sed -n 's/^yq = "\(.*\)"$/\1/p' "$1"; }
base_pin="$(pin "$here/templates/base/.config/mise/conf.d/base.toml")"
[ -n "$base_pin" ] && [ "$base_pin" = "$(pin "$here/.config/mise/conf.d/pap-repo.toml")" ]
result $? "base layer: pins yq, at the version pap's own repository pins" \
  "base: '$base_pin'; pap: '$(pin "$here/.config/mise/conf.d/pap-repo.toml")'"

# --- status against a stub gh -------------------------------------------------

# The stub answers the calls status makes. A path with no fixture is a 404.
# repo view names another repository, so the local hook check is skipped and
# the target's files are read through the contents API. A write (any -X other
# than GET) is logged to $LOG with its -f fields, its --input copied to
# $T/input-<name>.json by the body's name (main, all-branches), and answered
# with {}. A ruleset is served from ruleset-<id>.json.
mkdir "$T/stub" "$T/fix" "$T/fix/contents"
cat > "$T/stub/gh" <<'EOF'
#!/bin/sh
[ "$1" = repo ] && { echo blairforce1/elsewhere; exit 0; }
method=GET input="" fields="" path=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    --input) input="$2"; shift 2 ;;
    -f | -F) fields="$fields $2"; shift 2 ;;
    -*) shift ;;
    *) path="$1"; shift ;;
  esac
done
if [ "$method" != GET ]; then
  printf '%s %s%s\n' "$method" "$path" "$fields" >> "$LOG"
  [ -z "$input" ] || cp "$input" "$FIX/../input-$(jq -r .name "$input").json"
  if [ -f "$FIX/refuse-user" ] && [ -n "$input" ] &&
    jq -e 'any(.bypass_actors[]?; .actor_type == "User")' "$input" >/dev/null; then
    echo 'gh: Validation Failed (HTTP 422)' >&2
    exit 1
  fi
  echo '{}'
  exit 0
fi
case "$path" in
  */labels*) if [ -f "$FIX/labels.json" ]; then cat "$FIX/labels.json"; else echo '[[]]'; fi; exit 0 ;;
  repos/blairforce1/demo) f=repo ;;
  */rulesets\?*) f=rulesets ;;
  */rulesets/*) f="ruleset-${path##*/}" ;;
  */codeowners/errors) f=codeowners ;;
  */vulnerability-alerts) f=alerts ;;
  */automated-security-fixes) f=fixes ;;
  */code-scanning/default-setup) f=codeql ;;
  */actions/policies\?*) f=policies ;;
  */actions/policies/*) f="policy-${path##*/}" ;;
  */contents/*) f="contents/${path#*/contents/}" ;;
  *) f=none ;;
esac
if [ -f "$FIX/$f.code" ]; then
  printf 'HTTP/2.0 %s Status\r\n\r\n{}' "$(cat "$FIX/$f.code")"
  exit 1
elif [ -f "$FIX/$f.json" ]; then
  printf 'HTTP/2.0 200 OK\r\n\r\n'
  cat "$FIX/$f.json"
else
  printf 'HTTP/2.0 404 Not Found\r\n\r\n{}'
  exit 1
fi
EOF
chmod +x "$T/stub/gh"
echo '{"visibility": "private", "owner": {"login": "blairforce1", "id": 1001, "type": "User"}, "permissions": {"admin": true}}' > "$T/fix/repo.json"
export FIX="$T/fix" LOG="$T/log"

status() { (cd "$T" && PATH="$T/stub:$PATH" bash "$sync" status --repo blairforce1/demo 2>&1); }
# lines <state>: the required checks reported in that state, one per line.
lines() { printf '%s\n' "$out" | sed -n "s/^  $1 *required check '\(.*\)'\$/\1/p"; }

# live <jq filter>: the live ruleset is main.json with an id and the filter
# applied, beside all-branches.json as id 8 with the owner's User actor, as
# apply writes it for the fixture's personal repository.
live() {
  echo '[{"id": 7, "name": "main", "source_type": "Repository"},
         {"id": 8, "name": "all-branches", "source_type": "Repository"}]' > "$T/fix/rulesets.json"
  jq ".id = 7 | $1" "$ruleset" > "$T/fix/ruleset-7.json"
  jq '.id = 8 | .bypass_actors = [{"actor_id": 1001, "actor_type": "User", "bypass_mode": "always"}]' \
    "$branches" > "$T/fix/ruleset-8.json"
}

live '(.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
  |= map(select(.context == "tests"))'
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(lines ok)" = tests ] && [ "$(lines missing)" = "$(printf '%s\n' "$want" | tail -n +2)" ]
result $? "status: only tests live, the other five reported missing by name" "exit $rc; $out"

live '.'
out="$(status)"
[ "$(lines ok)" = "$want" ] && [ -z "$(lines missing)" ]
result $? "status: the live ruleset matches, all six ok" "$out"

rm "$T/fix/ruleset-7.json" "$T/fix/ruleset-8.json"
echo '[]' > "$T/fix/rulesets.json"
out="$(status)"
[ "$(lines missing)" = "$want" ]
result $? "status: no ruleset, all six missing" "$out"

# --- what GitHub makes of CODEOWNERS (decision 0014) --------------------------

# owners: the CODEOWNERS line of the report, state first.
owners() { printf '%s\n' "$out" | sed -n 's/^  \([a-z-]*\) *\.github\/CODEOWNERS accepted by GitHub.*/\1/p'; }

out="$(status)"
[ "$(owners)" = skipped ] && printf '%s\n' "$out" | grep -q 'no CODEOWNERS on the default branch'
result $? "status: no CODEOWNERS on the default branch is skipped, not a failure" "$out"

echo '{"errors": []}' > "$T/fix/codeowners.json"
out="$(status)"
[ "$(owners)" = ok ]
result $? "status: a CODEOWNERS with no errors is ok" "$out"

# An organisation's own name as the owner, as the origin default writes it
# in a repository the organisation owns.
cat > "$T/fix/codeowners.json" <<'EOF'
{"errors": [{"line": 5, "column": 13, "kind": "Unknown owner", "source": "/product/** @acme",
  "suggestion": "make sure @acme exists and has write access to the repository",
  "message": "Unknown owner on line 5", "path": ".github/CODEOWNERS"}]}
EOF
live '.'
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(owners)" = drift ] &&
  printf '%s\n' "$out" | grep -q '1 error(s); name the owner on an Owner: line in product/invariants.md' &&
  printf '%s\n' "$out" | grep -qx '      line 5: Unknown owner: /product/\*\* @acme'
result $? "status: an owner GitHub does not accept is drift, named by line; exits 1" "exit $rc; $out"

# --- the Actions event policy for pr-checks (public repositories) ------------

# policy: the pull_request_target line of the report, state first.
policy() { printf '%s\n' "$out" | sed -n 's/^  \([a-z-]*\) *Actions policy allows pull_request_target for pr-checks.*/\1/p'; }
# policies <enforcement> <events> <workflow_path json>: one live policy, id 1:
# a summary in the list, its rules and conditions only in its own GET.
policies() {
  jq -n --arg e "$1" '{total_count: 1, policies: [{id: 1, name: "pr-checks", target: "actions",
    source_type: "Repository", enforcement: $e,
    _links: {self: {href: "https://api.github.com/repos/blairforce1/demo/actions/policies/1"}}}]}' > "$T/fix/policies.json"
  jq -n --arg e "$1" --argjson ev "$2" --argjson w "$3" '{id: 1, name: "pr-checks",
    target: "actions", source_type: "Repository", enforcement: $e, conditions: {workflow_path: $w},
    rules: [{type: "restrict_action_events", parameters: {allowed_events: $ev}}]}' > "$T/fix/policy-1.json"
}
scoped='{"include": [".github/workflows/pr-checks.yml"], "exclude": []}'

out="$(status)"
[ "$(policy)" = skipped ] && printf '%s\n' "$out" | grep -q 'private repository; the default policy blocks it in public ones only'
result $? "status: a private repository skips the pull_request_target policy" "$out"

echo '{"visibility": "public", "owner": {"login": "blairforce1", "id": 1001, "type": "User"}, "permissions": {"admin": true}}' > "$T/fix/repo.json"
out="$(status)"
[ "$(policy)" = skipped ] && printf '%s\n' "$out" | grep -q 'policies unavailable (HTTP 404)'
result $? "status: policies the API will not serve are skipped as unavailable" "$out"

echo '{"total_count": 0, "policies": []}' > "$T/fix/policies.json"
out="$(status)"
[ "$(policy)" = missing ]
result $? "status: a public repository with no policy is missing" "$out"

policies active '["pull_request_target"]' "$scoped"
out="$(status)"
[ "$(policy)" = ok ]
result $? "status: an active policy allowing it for the pr-checks path is ok" "$out"

policies disabled '["pull_request_target"]' "$scoped"
out="$(status)"
[ "$(policy)" = missing ]
result $? "status: a disabled policy does not count" "$out"

policies active '["pull_request"]' "$scoped"
out="$(status)"
[ "$(policy)" = missing ]
result $? "status: a policy that allows other events only is missing" "$out"

policies active '["pull_request_target"]' '{"include": [".github/workflows/other.yml"], "exclude": []}'
out="$(status)"
[ "$(policy)" = missing ]
result $? "status: a policy scoped to another workflow is missing" "$out"

policies active '["pull_request_target"]' '{"include": ["~ALL"], "exclude": []}'
out="$(status)"
[ "$(policy)" = drift ] && printf '%s\n' "$out" | grep -q 'scope it to .github/workflows/pr-checks.yml'
result $? "status: a policy allowing it for every workflow is drift" "$out"

policies active '["pull_request_target"]' "$scoped"
rm "$T/fix/policy-1.json"
out="$(status)"
[ "$(policy)" = skipped ] && printf '%s\n' "$out" | grep -q 'policies unavailable (HTTP 404)'
result $? "status: a policy whose detail the API will not serve is skipped, not missing" "$out"

rm -f "$T/fix/policies.json" "$T/fix/policy-1.json"
echo '{"visibility": "private", "owner": {"login": "blairforce1", "id": 1001, "type": "User"}, "permissions": {"admin": true}}' > "$T/fix/repo.json"

# --- apply: required checks kept, added, removed -----------------------------

# serve <path> <text>: the target's default branch holds <path> with <text>.
serve() {
  mkdir -p "$(dirname "$T/fix/contents/$1")"
  jq -n --arg c "$(printf '%s\n' "$2" | base64)" '{content: $c}' > "$T/fix/contents/$1.json"
}
apply() { rm -f "$LOG" "$T"/input-*.json; (cd "$T" && PATH="$T/stub:$PATH" bash "$sync" apply --repo blairforce1/demo "$@" 2>&1); }
# sent: the required checks in the ruleset apply sent, one per line, sorted.
sent() { jq -r "$checks_of" "$T/input-main.json" 2>/dev/null | sort; }
checks_of='.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context'
sorted() { printf '%s\n' "$@" | sort; }
rm -f "$T/fix/codeowners.json"

# The business-os incident (#99): the live ruleset lacks a check main.json
# names, so apply must update it, and also requires coverage, which main.json
# does not name. The update must keep coverage.
extra='(.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
  |= (map(select(.context != "tests")) + [{"context": "coverage", "integration_id": 15368}])'
live "$extra"
out="$(apply)"; rc=$?
[ "$rc" = 0 ] && [ "$(sent)" = "$(sorted "$want" coverage)" ] &&
  grep -q '^PUT repos/blairforce1/demo/rulesets/7$' "$LOG" &&
  printf '%s\n' "$out" | grep -q 'kept (--remove-checks removes them): coverage$' &&
  printf '%s\n' "$out" | grep -q '^ *+ *"context": "tests",$'
result $? "apply: an existing extra check is kept, the missing one added, and the diff shown" "exit $rc; $out; sent: $(sent)"

out="$(status)"
printf '%s\n' "$out" | grep -q 'kept (--remove-checks removes them): coverage$' &&
  [ "$(lines missing)" = tests ]
result $? "status: names the kept extra check; only tests missing" "$out"

# Listed first: order alone is not drift either.
live '(.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks)
  |= [{"context": "coverage", "integration_id": 15368}] + .'
out="$(status)"
printf '%s\n' "$out" | grep -q "^  ok  *ruleset 'main'  (id 7)\$"
result $? "status: a live ruleset that differs only by an extra check is not drift" "$out"

live "$extra"
out="$(apply --remove-checks)"; rc=$?
[ "$rc" = 0 ] && [ "$(sent)" = "$(sorted "$want")" ] &&
  printf '%s\n' "$out" | grep -q 'removed (--remove-checks): coverage$' &&
  printf '%s\n' "$out" | grep -q '^ *- *"context": "coverage",$'
result $? "apply --remove-checks: removes the extra check, and says so" "exit $rc; $out; sent: $(sent)"

out="$(apply --dry-run)"
[ ! -f "$LOG" ] || ! grep -q rulesets "$LOG"
result $? "apply --dry-run: sends no ruleset" "$(cat "$LOG" 2>/dev/null)"

(cd "$T" && PATH="$T/stub:$PATH" bash "$sync" status --repo blairforce1/demo --remove-checks >/dev/null 2>&1)
[ $? = 64 ]
result $? "status --remove-checks: a usage error"

# A check the repository declares in .github/required-checks.yml.
serve .github/required-checks.yml '- coverage'
live '.'
out="$(status)"
[ "$(lines missing)" = coverage ]
result $? "status: a declared check the live ruleset lacks is missing" "$out"
out="$(apply)"; rc=$?
[ "$rc" = 0 ] && [ "$(sent)" = "$(sorted "$want" coverage)" ] &&
  jq -e '.rules[] | select(.type == "required_status_checks")
    | .parameters.required_status_checks[] | select(.context == "coverage") | .integration_id == 15368' "$T/input-main.json" >/dev/null
result $? "apply: a declared check is added, from GitHub Actions" "exit $rc; $out; sent: $(sent)"

rm "$T/fix/ruleset-7.json" "$T/fix/ruleset-8.json"; echo '[]' > "$T/fix/rulesets.json"
out="$(apply)"
grep -q '^POST repos/blairforce1/demo/rulesets$' "$LOG" && [ "$(sent)" = "$(sorted "$want" coverage)" ]
result $? "apply: a new ruleset carries the declared check" "$out; sent: $(sent)"
rm -r "$T/fix/contents/.github"

serve .github/required-checks.yml 'coverage: yes'
out="$(apply)"; rc=$?
[ "$rc" != 0 ] && printf '%s\n' "$out" | grep -q 'must be a list of check names'
result $? "apply: a required-checks.yml that is not a list is refused" "exit $rc; $out"
rm -r "$T/fix/contents/.github"

# --- the all-branches ruleset (decisions 0022, 0023) --------------------------

jq -e '.target == "branch" and .enforcement == "active"
  and .conditions.ref_name.include == ["~ALL"]
  and .bypass_actors == [] and [.rules[].type] == ["non_fast_forward"]' "$branches" >/dev/null
result $? "all-branches: every branch, active, no id in the template's bypass list, only non_fast_forward"

# state <item>: the state status reports for that item.
state() { printf '%s\n' "$out" | sed -n "s/^  \([a-z-]*\) *$1\$/\1/p; s/^  \([a-z-]*\) *$1  (.*/\1/p"; }
ab="ruleset 'all-branches'"
# actors <jq array>: replace all-branches' live bypass actors.
actors() { jq --argjson a "$1" '.bypass_actors = $a' "$T/fix/ruleset-8.json" > "$T/r8" && mv "$T/r8" "$T/fix/ruleset-8.json"; }
# repo_as <type> <admin>: the repository's owner type and the caller's admin flag.
repo_as() {
  jq --arg t "$1" --argjson a "$2" '.owner.type = $t | .permissions.admin = $a' "$T/fix/repo.json" > "$T/rj" &&
    mv "$T/rj" "$T/fix/repo.json"
}
user_actor='{"actor_id": 1001, "actor_type": "User", "bypass_mode": "always"}'

live '.'
out="$(status)"; rc=$?
[ "$(state "$ab")" = ok ] && [ "$(state "$ab active on GitHub")" = ok ] &&
  [ "$(state "$ab bypass actors")" = ok ] && [ "$(state "ruleset 'main' bypass actors")" = ok ]
result $? "status: all-branches with the owner's User actor is ok, and active; main with none is ok" "$out"

live '.'
actors "[$user_actor, {\"actor_id\": 424242, \"actor_type\": \"Integration\", \"bypass_mode\": \"always\"}]"
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(state "$ab bypass actors")" = drift ] && [ "$(state "$ab")" = ok ] &&
  printf '%s\n' "$out" | grep -q 'an Integration (GitHub App) is listed and must never bypass'
result $? "status: an Integration beside the owner is drift on the bypass item alone; exits 1" "exit $rc; $out"

actors '[]'
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(state "$ab bypass actors")" = drift ] && printf '%s\n' "$out" | grep -q 'the owner is not listed'
result $? "status: an admin token seeing an empty list reports the missing owner as drift" "exit $rc; $out"

actors '[{"actor_id": 1001, "actor_type": "User", "bypass_mode": "pull_request"}]'
out="$(status)"
[ "$(state "$ab bypass actors")" = drift ]
result $? "status: the owner in pull_request mode, not always, is drift" "$out"

actors '[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]'
out="$(status)"
[ "$(state "$ab bypass actors")" = ok ]
result $? "status: on a personal repository the admin-role fallback counts as the owner" "$out"

# A token without administration (an agent app's) sees the list empty.
live '.'
actors '[]'
jq 'del(.bypass_actors)' "$T/fix/ruleset-7.json" > "$T/r7" && mv "$T/r7" "$T/fix/ruleset-7.json"
repo_as User false
echo 403 > "$T/fix/alerts.code"
echo 403 > "$T/fix/fixes.code"
out="$(status)"; rc=$?
printf '%s\n' "$out" | grep -q ', 0 error$' && [ "$(state "$ab bypass actors")" = skipped ] && [ "$(state "$ab")" = ok ] &&
  [ "$(state "ruleset 'main' bypass actors")" = skipped ] && [ "$(state "ruleset 'main'")" = ok ] &&
  [ "$(state "Dependabot alerts")" = skipped ] && [ "$(state "Dependabot security updates")" = skipped ] &&
  printf '%s\n' "$out" | grep -q "bypass actors not visible to this token (needs administration; run from the owner's terminal)"
result $? "status: without administration, hidden bypass actors and Dependabot 403s are skipped, the rest compared" "exit $rc; $out"

jq '.enforcement = "disabled"' "$T/fix/ruleset-8.json" > "$T/r8" && mv "$T/r8" "$T/fix/ruleset-8.json"
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(state "$ab")" = drift ] && [ "$(state "$ab bypass actors")" = skipped ]
result $? "status: without administration, drift in the rest of the ruleset still shows" "exit $rc; $out"

out="$(apply)"; rc=$?
[ "$rc" = 1 ] && [ ! -f "$LOG" ] && printf '%s\n' "$out" | grep -q 'apply needs administration on blairforce1/demo and this token has none'
result $? "apply: refused up front without administration, nothing written" "exit $rc; $out"

repo_as User true
out="$(status)"; rc=$?
[ "$(state "Dependabot alerts")" = error ] && [ "$(state "$ab bypass actors")" = drift ]
result $? "status: with administration, a 403 is an error and an empty list drift, never skipped" "exit $rc; $out"
rm "$T/fix/alerts.code" "$T/fix/fixes.code"

# In a public repository, the same token sees no security_and_analysis and
# gets 403 on CodeQL's default setup.
repo_as User false
jq '.visibility = "public" | del(.security_and_analysis)' "$T/fix/repo.json" > "$T/rj" && mv "$T/rj" "$T/fix/repo.json"
echo 403 > "$T/fix/codeql.code"
out="$(status)"
[ "$(state "secret scanning push protection")" = skipped ] && [ "$(state "CodeQL default setup")" = skipped ]
result $? "status: without administration, push protection and CodeQL are skipped, not missing or error" "$out"
repo_as User true
out="$(status)"
[ "$(state "secret scanning push protection")" = missing ] && [ "$(state "CodeQL default setup")" = error ]
result $? "status: with administration, the same answers are missing and error" "$out"
rm "$T/fix/codeql.code"
jq '.visibility = "private"' "$T/fix/repo.json" > "$T/rj" && mv "$T/rj" "$T/fix/repo.json"

# The deliberate override before 0023: the ruleset disabled by hand.
live '.'
jq '.enforcement = "disabled"' "$T/fix/ruleset-8.json" > "$T/r8" && mv "$T/r8" "$T/fix/ruleset-8.json"
out="$(status)"; rc=$?
[ "$rc" = 1 ] && [ "$(state "$ab")" = drift ] &&
  [ "$(state "$ab active on GitHub")" = drift ] &&
  printf '%s\n' "$out" | grep -q 'enforcement disabled; pap repo apply restores it' &&
  printf '%s\n' "$out" | grep -q '^ *+ *"enforcement": "active",$'
result $? "status: a disabled all-branches is drift twice, with the diff; exits 1" "exit $rc; $out"

# one_owner <file> <type>: the body's bypass list is exactly one <type> actor, always, no Integration.
one_owner() {
  jq -e --arg t "$2" '.bypass_actors | length == 1 and .[0].actor_type == $t and .[0].bypass_mode == "always"
    and all(.[]; .actor_type != "Integration")' "$1" >/dev/null
}

out="$(apply)"; rc=$?
[ "$rc" = 0 ] && grep -q '^PUT repos/blairforce1/demo/rulesets/8$' "$LOG" &&
  jq -e '.enforcement == "active" and .bypass_actors == [{"actor_id": 1001, "actor_type": "User", "bypass_mode": "always"}]' \
    "$T/input-all-branches.json" >/dev/null && one_owner "$T/input-all-branches.json" User
result $? "apply: restores a disabled all-branches, active, by id, with the owner's User actor" "exit $rc; $out"

live '.'
actors "[$user_actor, {\"actor_id\": 424242, \"actor_type\": \"Integration\", \"bypass_mode\": \"always\"}]"
out="$(apply)"; rc=$?
[ "$rc" = 0 ] && grep -q '^PUT repos/blairforce1/demo/rulesets/8$' "$LOG" && one_owner "$T/input-all-branches.json" User
result $? "apply: an Integration in the list is replaced by the owner alone" "exit $rc; $out"

touch "$T/fix/refuse-user"
out="$(apply)"; rc=$?
[ "$rc" = 0 ] && [ "$(grep -c '^PUT repos/blairforce1/demo/rulesets/8$' "$LOG")" = 2 ] &&
  one_owner "$T/input-all-branches.json" RepositoryRole && jq -e '.bypass_actors[0].actor_id == 5' "$T/input-all-branches.json" >/dev/null &&
  printf '%s\n' "$out" | grep -q 'GitHub refused a User bypass actor (gh: Validation Failed (HTTP 422)); writing RepositoryRole admin instead'
result $? "apply: a refused User actor falls back to RepositoryRole admin, and says so" "exit $rc; $out"
rm "$T/fix/refuse-user"

repo_as Organization true
out="$(status)"
[ "$(state "$ab bypass actors")" = drift ]
result $? "status: on an organisation's repository a User actor is not the owner's bypass" "$out"
out="$(apply)"; rc=$?
[ "$rc" = 0 ] && grep -q '^PUT repos/blairforce1/demo/rulesets/8$' "$LOG" &&
  jq -e '.bypass_actors == [{"actor_id": null, "actor_type": "OrganizationAdmin", "bypass_mode": "always"}]' \
    "$T/input-all-branches.json" >/dev/null
result $? "apply: an organisation's repository gets exactly OrganizationAdmin, actor_id null, always" "exit $rc; $out"
# GitHub ignores actor_id for OrganizationAdmin; whatever it returns there, the type counts.
for id in null 1; do
  actors "[{\"actor_id\": $id, \"actor_type\": \"OrganizationAdmin\", \"bypass_mode\": \"always\"}]"
  out="$(status)"
  [ "$(state "$ab bypass actors")" = ok ]
  result $? "status: an organisation's repository with OrganizationAdmin (actor_id $id) is ok" "$out"
done
actors '[{"actor_id": null, "actor_type": "OrganizationAdmin", "bypass_mode": "always"}, {"actor_id": 424242, "actor_type": "Integration", "bypass_mode": "always"}]'
out="$(status)"
[ "$(state "$ab bypass actors")" = drift ] && printf '%s\n' "$out" | grep -q 'an Integration (GitHub App) is listed'
result $? "status: on an organisation's repository an Integration beside OrganizationAdmin is drift" "$out"
actors '[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]'
out="$(status)"
[ "$(state "$ab bypass actors")" = drift ]
result $? "status: on an organisation's repository the admin role is not the owner (other admins hold it)" "$out"
repo_as User true

echo '[{"id": 7, "name": "main", "source_type": "Repository"}]' > "$T/fix/rulesets.json"
out="$(status)"
[ "$(state "$ab")" = missing ] && [ "$(state "$ab active on GitHub")" = missing ]
result $? "status: no all-branches is missing" "$out"
out="$(apply)"
grep -q '^POST repos/blairforce1/demo/rulesets$' "$LOG" &&
  [ "$(jq -S 'del(.bypass_actors)' "$T/input-all-branches.json")" = "$(jq -S 'del(.bypass_actors)' "$branches")" ] &&
  one_owner "$T/input-all-branches.json" User &&
  ! grep -q '^PUT repos/blairforce1/demo/rulesets/8$' "$LOG"
result $? "apply: creates all-branches from the file, with the owner's actor" "$out"

# --- apply: the risk layer's labels -------------------------------------------

risk_labels='owner-reviewed
risk:high
risk:low
risk:medium'
# posted: the labels apply created, one per line, sorted.
posted() { sed -n 's|^POST repos/blairforce1/demo/labels name=\([^ ]*\) .*|\1|p' "$LOG" | sort; }

serve .config/pap.toml 'version = "0.9.0"
layers = ["base", "dotnet", "risk"]'
out="$(apply)"
[ "$(posted | grep -E '^(risk:|owner-reviewed)')" = "$risk_labels" ] &&
  grep -q '^POST repos/blairforce1/demo/labels name=owner-reviewed color=0052cc description=The owner reviewed this head of a risk:high pull request; the owner adds it, any push removes it$' "$LOG" &&
  grep -q '^POST repos/blairforce1/demo/labels name=risk:high color=b60205 ' "$LOG" &&
  posted | grep -qx class:bugfix
result $? "apply: the risk layer creates owner-reviewed and the three risk labels, with the base set" "$out; $(posted)"

echo '[[{"name": "Owner-Reviewed", "color": "0E8A16", "description": "made by hand"}]]' > "$T/fix/labels.json"
out="$(apply)"
grep -q '^PATCH repos/blairforce1/demo/labels/Owner-Reviewed new_name=owner-reviewed color=0052cc ' "$LOG" &&
  ! posted | grep -qx owner-reviewed
result $? "apply: a hand-made owner-reviewed is updated, not duplicated" "$out; $(cat "$LOG")"
rm "$T/fix/labels.json"

serve .config/pap.toml 'version = "0.9.0"
layers = ["base", "dotnet"]'
out="$(apply)"
! posted | grep -qE '^(risk:|owner-reviewed)' && posted | grep -qx class:bugfix
result $? "apply: without the risk layer, no risk labels" "$out; $(posted)"

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

#!/bin/sh
# repo-sync.test.sh: tests for the required checks in .github/rulesets/main.json,
# their per-check report in scripts/repo-sync.sh status, its report of what
# GitHub makes of .github/CODEOWNERS, and what apply writes: the required
# checks it keeps, adds and removes, and the risk layer's labels.
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

here="$(cd "$(dirname "$0")/.." && pwd)"
sync="$here/scripts/repo-sync.sh"
ruleset="$here/.github/rulesets/main.json"

for tool in jq yq bash; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

T="$(mktemp -d)"
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
# $T/input.json, and answered with {}.
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
  [ -z "$input" ] || cp "$input" "$FIX/../input.json"
  echo '{}'
  exit 0
fi
case "$path" in
  */labels*) if [ -f "$FIX/labels.json" ]; then cat "$FIX/labels.json"; else echo '[[]]'; fi; exit 0 ;;
  repos/blairforce1/demo) f=repo ;;
  */rulesets\?*) f=rulesets ;;
  */rulesets/*) f=ruleset ;;
  */codeowners/errors) f=codeowners ;;
  */contents/*) f="contents/${path#*/contents/}" ;;
  *) f=none ;;
esac
if [ -f "$FIX/$f.json" ]; then
  printf 'HTTP/2.0 200 OK\r\n\r\n'
  cat "$FIX/$f.json"
else
  printf 'HTTP/2.0 404 Not Found\r\n\r\n{}'
  exit 1
fi
EOF
chmod +x "$T/stub/gh"
echo '{"visibility": "private"}' > "$T/fix/repo.json"
export FIX="$T/fix" LOG="$T/log"

status() { (cd "$T" && PATH="$T/stub:$PATH" bash "$sync" status --repo blairforce1/demo 2>&1); }
# lines <state>: the required checks reported in that state, one per line.
lines() { printf '%s\n' "$out" | sed -n "s/^  $1 *required check '\(.*\)'\$/\1/p"; }

# live <jq filter>: the live ruleset is main.json with an id and the filter applied.
live() {
  echo '[{"id": 7, "name": "main", "source_type": "Repository"}]' > "$T/fix/rulesets.json"
  jq ".id = 7 | $1" "$ruleset" > "$T/fix/ruleset.json"
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

rm "$T/fix/ruleset.json"
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

# --- apply: required checks kept, added, removed -----------------------------

# serve <path> <text>: the target's default branch holds <path> with <text>.
serve() {
  mkdir -p "$(dirname "$T/fix/contents/$1")"
  jq -n --arg c "$(printf '%s\n' "$2" | base64)" '{content: $c}' > "$T/fix/contents/$1.json"
}
apply() { rm -f "$LOG" "$T/input.json"; (cd "$T" && PATH="$T/stub:$PATH" bash "$sync" apply --repo blairforce1/demo "$@" 2>&1); }
# sent: the required checks in the ruleset apply sent, one per line, sorted.
sent() { jq -r "$checks_of" "$T/input.json" 2>/dev/null | sort; }
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
    | .parameters.required_status_checks[] | select(.context == "coverage") | .integration_id == 15368' "$T/input.json" >/dev/null
result $? "apply: a declared check is added, from GitHub Actions" "exit $rc; $out; sent: $(sent)"

rm "$T/fix/ruleset.json"; echo '[]' > "$T/fix/rulesets.json"
out="$(apply)"
grep -q '^POST repos/blairforce1/demo/rulesets$' "$LOG" && [ "$(sent)" = "$(sorted "$want" coverage)" ]
result $? "apply: a new ruleset carries the declared check" "$out; sent: $(sent)"
rm -r "$T/fix/contents/.github"

serve .github/required-checks.yml 'coverage: yes'
out="$(apply)"; rc=$?
[ "$rc" != 0 ] && printf '%s\n' "$out" | grep -q 'must be a list of check names'
result $? "apply: a required-checks.yml that is not a list is refused" "exit $rc; $out"
rm -r "$T/fix/contents/.github"

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

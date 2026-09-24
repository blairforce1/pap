#!/bin/sh
# repo-sync.test.sh: tests for the required checks in .github/rulesets/main.json
# and their per-check report in scripts/repo-sync.sh status.
#
# Usage: sh tests/repo-sync.test.sh
#
# Runs status against a stub gh that serves fixture API responses from a
# temporary directory, and checks each required check's line. Prints one
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

# --- status against a stub gh -------------------------------------------------

# The stub answers the calls status makes. A path with no fixture is a 404.
# repo view names another repository, so the local hook check is skipped.
mkdir "$T/stub" "$T/fix"
cat > "$T/stub/gh" <<'EOF'
#!/bin/sh
[ "$1" = repo ] && { echo blairforce1/elsewhere; exit 0; }
for a; do case "$a" in -*) ;; *) path="$a" ;; esac; done
case "$path" in
  */labels*) echo '[[]]'; exit 0 ;;
  repos/blairforce1/demo) f=repo ;;
  */rulesets\?*) f=rulesets ;;
  */rulesets/*) f=ruleset ;;
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
export FIX="$T/fix"

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

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

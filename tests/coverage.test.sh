#!/bin/sh
# coverage.test.sh: tests for bin/pap coverage (H-001).
#
# Usage: sh tests/coverage.test.sh
#
# Builds a repository in a temporary directory with a process document,
# coverage.md, rules.md, a backlog, a ruleset and a workflow, each seeded
# with one case per outcome, and runs pap coverage on it. Prints one
# TAP-style line per case and exits 1 if any case fails. Needs git; touches
# nothing outside the temporary directory.
#
# SC2319: each case passes the exit status of its condition on purpose.
# shellcheck disable=SC2319

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
pap="$here/bin/pap"

command -v git >/dev/null 2>&1 || { printf 'Bail out! git not found\n'; exit 1; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT INT TERM
export GIT_CEILING_DIRECTORIES="$T"

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

R="$T/repo"
mkdir -p "$R/process" "$R/product" "$R/.github/rulesets" "$R/.github/workflows" "$R/scripts"
git init -q -b main "$R"
: > "$R/scripts/real.sh"
cat > "$R/process/personal-agentic-process.md" <<'DOC'
# Process

## 1. Principles <!-- id: S-principles -->

1. **Covered by a rule.** Text. <!-- id: P-ruled -->
2. **Covered by a hypothesis.** Text. <!-- id: P-hyp -->
3. **Deferred.** Text. <!-- id: P-later -->
4. **Nothing behind it.** Text. <!-- id: P-bare -->
5. **Names a missing rule.** Text. <!-- id: P-norule -->
6. **Names a missing hypothesis.** Text. <!-- id: P-nohyp -->

### 1.1 A subsection <!-- id: S-sub -->

```text
## Not a section
```
DOC
cat > "$R/coverage.md" <<'MAP'
# Coverage

- P-ruled: rule 1.1, rule 2.1
- P-hyp: H-001
- P-later: deferred: not yet, and maybe never
- P-norule: rule 9.9
- P-nohyp: H-099
- S-sub: rule 1.1
- P-gone: H-001
MAP
cat > "$R/product/backlog.md" <<'BL'
# Backlog

**H-001** We believe something.
BL
cat > "$R/rules.md" <<'RULES'
# Rules

### 1.1 Files exist

- Decision: none
- Enforced by: [`scripts/real.sh`](scripts/real.sh) and [`scripts/gone.sh`](scripts/gone.sh#L1); also `scripts/missing.sh` and [a site](https://example.invalid/x).

### 2.1 Required is required

- Decision: none
- Enforced by: the `tests` check, a required check since #1. The `lint` workflow ([`.github/workflows/lint.yml`](.github/workflows/lint.yml)) is a required check too.

### 3.1 Optional is optional

- Decision: none
- Enforced by: the `tests` check does not block.

### 4.1 A claim names a check

- Decision: none
- Enforced by: a required check, unnamed.
RULES
cat > "$R/.github/rulesets/main.json" <<'JSON'
{ "rules": [ { "type": "required_status_checks", "parameters": { "required_status_checks": [
  { "context": "tests", "integration_id": 1 },
  { "context": "security / check", "integration_id": 1 }
] } } ] }
JSON
printf 'name: lint\n' > "$R/.github/workflows/lint.yml"

out="$(cd "$R" && sh "$pap" coverage 2>&1)"
rc=$?
has() { printf '%s\n' "$out" | grep -qxF "$1"; }
show() { printf '%s\n' "$out"; }

result "$rc" "exits 0 with findings" "$(show)"
has "P-ruled covered (rule 1.1, rule 2.1)"
result $? "an ID mapped to rules is covered" "$(show)"
has "P-hyp covered (H-001)"
result $? "an ID mapped to a hypothesis is covered" "$(show)"
has "P-later deferred (not yet, and maybe never)"
result $? "a deferral takes the rest of the line" "$(show)"
has "P-bare uncovered (Nothing behind it)"
result $? "an ID with no line is uncovered, with its name" "$(show)"
has "S-principles uncovered (1. Principles)"
result $? "a heading ID is uncovered, with its text" "$(show)"
has "P-norule uncovered (rule 9.9 is not in rules.md)"
result $? "a missing rule does not cover" "$(show)"
has "P-nohyp uncovered (H-099 is not in product/backlog.md)"
result $? "a missing hypothesis does not cover" "$(show)"
has "S-sub covered (rule 1.1)"
result $? "a subsection is read" "$(show)"
has "P-gone stale (in coverage.md, not in process/personal-agentic-process.md)"
result $? "a map line for no ID is stale" "$(show)"
! printf '%s\n' "$out" | grep -q 'Not a section'
result $? "a heading with no ID is not an ID" "$(show)"
has "rule 1.1 disagrees (names scripts/gone.sh, which does not exist)"
result $? "a linked file that does not exist disagrees" "$(show)"
has "rule 1.1 disagrees (names scripts/missing.sh, which does not exist)"
result $? "a backticked path that does not exist disagrees" "$(show)"
! printf '%s\n' "$out" | grep -q 'real.sh\|example.invalid'
result $? "an existing file and a URL agree" "$(show)"
has "rule 2.1 disagrees (lint is not a required check in .github/rulesets/main.json)"
result $? "a required claim on an optional check disagrees" "$(show)"
! printf '%s\n' "$out" | grep -q '(tests is not a required'
result $? "a required claim on a required check agrees" "$(show)"
has "rule 3.1 disagrees (tests is a required check in .github/rulesets/main.json, so it blocks)"
result $? "a does-not-block claim on a required check disagrees" "$(show)"
has "rule 4.1 disagrees (claims a required check and names none the repository has)"
result $? "a claim naming no check disagrees" "$(show)"
[ "$(printf '%s\n' "$out" | tail -n 1)" = "4 uncovered, 5 disagreeing" ]
result $? "ends with the two counts" "$(show)"

rm "$R/process/personal-agentic-process.md"
out="$(cd "$R" && sh "$pap" coverage 2>&1)"
rc=$?
[ "$rc" = 0 ] && has "No process/personal-agentic-process.md; nothing to cover."
result $? "no process document: says so, exits 0" "$(show)"

printf '1..%d\n' "$n"
[ "$failed" = 0 ]

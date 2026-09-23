#!/usr/bin/env bash
# repo-sync.sh: make a GitHub repository conform to PAP defaults; safe to re-run.
#
# Usage: repo-sync.sh status [--repo owner/name]
#        repo-sync.sh apply  [--repo owner/name] [--dry-run]
#
# The repository defaults to the one gh resolves from the current directory.
# The reference files come from the blairforce1/pap checkout this script lives
# in, not from the target: .github/rulesets/main.json and .github/labels.yml.
#
# status  Read-only. Reports each item as ok, drift, missing or
#         unavailable-on-plan, in five groups: repository settings, security,
#         ruleset, enforcement layers (decision 0002) and labels. Two more
#         states cover what the four cannot: skipped (the check cannot run
#         from here) and error (the API call itself failed). Exits 1 unless
#         every item is ok, unavailable-on-plan or skipped.
#
# apply   Prints the intended changes, then makes them unless --dry-run is
#         given. Applies settings, security, ruleset and labels; the
#         enforcement group is report-only. The ruleset is created or updated
#         by name through the rulesets API, never legacy branch protection.
#         Labels are created or have colour and description updated; labels
#         not in labels.yml are reported and never deleted. Ends with a
#         summary: newly applied, already correct, skipped, failed. Exits 1
#         if anything failed.
#
# Push protection and CodeQL default setup need GitHub Advanced Security on
# private repositories, which a Pro personal account does not have. They are
# checked and applied only when the repository is public, whatever the caller
# assumes about its visibility.
#
# Requires gh (authenticated), jq, and yq (mikefarah v4, pinned in mise.toml).

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
ruleset_file="$root/.github/rulesets/main.json"
labels_file="$root/.github/labels.yml"
sep=$'\x1f'

die() {
  printf 'repo-sync: %s\n' "$1" >&2
  exit "${2:-1}"
}

usage() {
  sed -n '4,5p' "$0" | sed 's/^# //' >&2
  exit 64
}

cmd="${1:-}"
[ $# -gt 0 ] && shift
repo=""
dry_run=false
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
    --repo=*) repo="${1#--repo=}"; shift ;;
    --dry-run) dry_run=true; shift ;;
    *) usage ;;
  esac
done
case "$cmd" in status | apply) ;; *) usage ;; esac
[ "$cmd" = apply ] || [ "$dry_run" = false ] || usage

for tool in gh jq yq; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found"
done
case "$(yq --version 2>&1)" in *mikefarah*) ;; *) die "yq must be mikefarah/yq v4; run mise install" ;; esac
[ -f "$ruleset_file" ] || die "missing $ruleset_file"
[ -f "$labels_file" ] || die "missing $labels_file"

local_repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
repo="${repo:-$local_repo}"
[ -n "$repo" ] || die "no --repo given and the current directory is not a GitHub repository"

# api_get <path>: sets $code to the HTTP status and $body to the response
# body. Never fails, so callers decide what each status means.
api_get() {
  local out
  out="$(gh api -i "$1" 2>/dev/null || true)"
  code="${out%%$'\n'*}"
  code="${code#* }"
  code="${code%% *}"
  [ -n "$out" ] || code=000
  body="$(printf '%s\n' "$out" | sed '1,/^\r\{0,1\}$/d')"
}

# Every check ends in record(); fixable ones also call plan().
rec_group=() rec_state=() rec_item=()
plan_item=() plan_desc=() plan_cmd=()

group() {
  [ "$cmd" = status ] && printf '\n%s\n' "$1"
  return 0
}

# record <group> <state> <item> [detail]
record() {
  rec_group+=("$1") rec_state+=("$2") rec_item+=("$3")
  [ "$cmd" = status ] && printf '  %-20s %s%s\n' "$2" "$3" "${4:+  ($4)}"
  return 0
}

# note <text>: an indented line under the current item, in either mode.
note() {
  printf '%s\n' "$1" | sed 's/^/      /'
}

# plan <item> <description> <command...>
plan() {
  plan_item+=("$1") plan_desc+=("$2")
  shift 2
  plan_cmd+=("$(printf '%q ' "$@")")
}

api_get "repos/$repo"
[ "$code" = 200 ] || die "cannot read $repo (HTTP $code)"
repo_json="$body"
visibility="$(jq -r .visibility <<<"$repo_json")"

# --- 1. Repository settings -------------------------------------------------

# setting <field> <wanted value> <item>
setting() {
  local have msg
  have="$(jq -r --arg f "$1" '.[$f] | tostring' <<<"$repo_json")"
  if [ "$have" = "$2" ]; then
    record settings ok "$3"
    return
  fi
  record settings drift "$3" "$1 is $have"
  if [ "$1" = squash_merge_commit_title ]; then
    # GitHub sets title and message as a pair; PR_TITLE pairs with PR_BODY or BLANK.
    msg="$(jq -r .squash_merge_commit_message <<<"$repo_json")"
    case "$msg" in PR_BODY | BLANK) ;; *) msg=PR_BODY ;; esac
    plan "$3" "~ settings: $1 $have -> $2 (squash_merge_commit_message $msg)" \
      gh api -X PATCH "repos/$repo" -f "$1=$2" -f "squash_merge_commit_message=$msg"
  else
    plan "$3" "~ settings: $1 $have -> $2" gh api -X PATCH "repos/$repo" -F "$1=$2"
  fi
}

group "Repository settings"
# Squash is enabled before the others are disabled: GitHub refuses a
# repository with no merge method.
setting allow_squash_merge true "squash merge enabled"
setting allow_merge_commit false "merge commits disabled"
setting allow_rebase_merge false "rebase merge disabled"
setting delete_branch_on_merge true "delete branch on merge"
setting squash_merge_commit_title PR_TITLE "PR title as squash commit title"
setting allow_auto_merge false "auto-merge off"

# --- 2. Security ------------------------------------------------------------

group "Security"
item="Dependabot alerts"
api_get "repos/$repo/vulnerability-alerts"
case "$code" in
  204) record security ok "$item" ;;
  404)
    record security missing "$item"
    plan "$item" "+ security: enable Dependabot alerts" \
      gh api -X PUT "repos/$repo/vulnerability-alerts"
    ;;
  *) record security error "$item" "HTTP $code" ;;
esac

item="Dependabot security updates"
api_get "repos/$repo/automated-security-fixes"
if [ "$code" = 200 ] && [ "$(jq -r .enabled <<<"$body")" = true ]; then
  record security ok "$item"
elif [ "$code" = 200 ] || [ "$code" = 404 ]; then
  record security missing "$item"
  plan "$item" "+ security: enable Dependabot security updates" \
    gh api -X PUT "repos/$repo/automated-security-fixes"
else
  record security error "$item" "HTTP $code"
fi

if [ "$visibility" != public ]; then
  record security unavailable-on-plan "secret scanning push protection" "$visibility repository"
  record security unavailable-on-plan "CodeQL default setup" "$visibility repository"
else
  item="secret scanning push protection"
  status="$(jq -r '.security_and_analysis.secret_scanning_push_protection.status // "disabled"' <<<"$repo_json")"
  if [ "$status" = enabled ]; then
    record security ok "$item"
  else
    record security missing "$item" "status $status"
    # Push protection needs secret scanning on; both go in one request.
    plan "$item" "+ security: enable secret scanning and push protection" \
      sh -c 'printf "%s" "$1" | gh api -X PATCH "repos/$0" --input -' "$repo" \
      '{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}'
  fi

  item="CodeQL default setup"
  api_get "repos/$repo/code-scanning/default-setup"
  if [ "$code" = 200 ]; then
    state="$(jq -r .state <<<"$body")"
    if [ "$state" = configured ]; then
      record security ok "$item"
    else
      record security missing "$item" "state $state"
      plan "$item" "+ security: configure CodeQL default setup" \
        gh api -X PATCH "repos/$repo/code-scanning/default-setup" -f state=configured
    fi
  else
    record security error "$item" "HTTP $code"
  fi
fi

# --- 3. Ruleset -------------------------------------------------------------

# Both sides lose the fields GitHub owns. The live side is then pruned to the
# keys the file carries, recursively, with rules matched by type, so a field
# GitHub adds or returns by default cannot cause permanent drift. Rules are
# sorted by type so order alone is not drift.
normalise='
  def prune($t):
    if ($t | type) == "object" and type == "object" then
      . as $v
      | reduce ($t | keys[]) as $k ({};
          if $v | has($k) then .[$k] = ($v[$k] | prune($t[$k])) else . end)
    elif ($t | type) == "array" and type == "array"
         and all($t[]; type == "object" and has("type")) then
      map(. as $e
          | ($t | map(select(.type == $e.type)) | first) as $m
          | if $m == null then . else prune($m) end)
    else . end;
  def owned: del(.id, .source, .source_type, .created_at, .updated_at);
  ($t[0] | owned) as $want
  | owned | prune($want)
  | if has("rules") then .rules |= sort_by(.type) else . end
'

group "Ruleset"
ruleset_name="$(jq -r .name "$ruleset_file")"
ruleset_want="$(jq -S --slurpfile t "$ruleset_file" "$normalise" "$ruleset_file")"
ruleset_enforcement=""
item="ruleset '$ruleset_name'"
api_get "repos/$repo/rulesets?per_page=100"
if [ "$code" != 200 ]; then
  record ruleset error "$item" "HTTP $code"
else
  ruleset_id="$(jq -r --arg n "$ruleset_name" \
    'map(select(.name == $n and .source_type == "Repository")) | first | .id // empty' <<<"$body")"
  if [ -z "$ruleset_id" ]; then
    record ruleset missing "$item"
    plan "$item" "+ ruleset: create '$ruleset_name' from .github/rulesets/main.json" \
      gh api -X POST "repos/$repo/rulesets" --input "$ruleset_file"
  else
    api_get "repos/$repo/rulesets/$ruleset_id"
    if [ "$code" != 200 ]; then
      record ruleset error "$item" "HTTP $code"
    else
      ruleset_enforcement="$(jq -r .enforcement <<<"$body")"
      have="$(jq -S --slurpfile t "$ruleset_file" "$normalise" <<<"$body")"
      if [ "$have" = "$ruleset_want" ]; then
        record ruleset ok "$item" "id $ruleset_id"
      else
        delta="$(diff -u --label "live ruleset $ruleset_id" --label .github/rulesets/main.json \
          <(printf '%s\n' "$have") <(printf '%s\n' "$ruleset_want") | tail -n +3 || true)"
        record ruleset drift "$item" "id $ruleset_id"
        [ "$cmd" = status ] && note "$delta"
        plan "$item" "~ ruleset: update '$ruleset_name' (id $ruleset_id)"$'\n'"$(printf '%s\n' "$delta" | sed 's/^/      /')" \
          gh api -X PUT "repos/$repo/rulesets/$ruleset_id" --input "$ruleset_file"
      fi
    fi
  fi
fi

# --- 4. Enforcement layers (decision 0002), report-only ---------------------

group "Enforcement layers (decision 0002)"
item="ruleset '$ruleset_name' active on GitHub"
case "$ruleset_enforcement" in
  active) record enforcement ok "$item" ;;
  "") record enforcement missing "$item" ;;
  *) record enforcement drift "$item" "enforcement $ruleset_enforcement" ;;
esac

for path in lefthook.yml scripts/guard-branch.sh; do
  api_get "repos/$repo/contents/$path"
  case "$code" in
    200) record enforcement ok "$path present" ;;
    404) record enforcement missing "$path present" ;;
    *) record enforcement error "$path present" "HTTP $code" ;;
  esac
done

item="lefthook pre-push hook installed locally"
if [ -n "$local_repo" ] && [ "$(tr '[:upper:]' '[:lower:]' <<<"$local_repo")" = "$(tr '[:upper:]' '[:lower:]' <<<"$repo")" ]; then
  hook="$(git rev-parse --git-path hooks)/pre-push"
  if [ ! -f "$hook" ]; then
    record enforcement missing "$item" "run lefthook install"
  elif grep -q lefthook "$hook"; then
    record enforcement ok "$item"
  else
    record enforcement drift "$item" "$hook is not lefthook's"
  fi
else
  record enforcement skipped "$item" "current directory is not a checkout of $repo"
fi

# --- 5. Labels --------------------------------------------------------------

group "Labels"
labels_want="$(yq -o=json '.' "$labels_file" | jq -c 'map(.description //= "")')"
bad="$(jq -r '.[] | select((.color | type) != "string" or (.color | test("^[0-9a-f]{6}$") | not)) | .name' <<<"$labels_want")"
[ -z "$bad" ] || die "labels.yml: colour must be a quoted six-digit lower-case hex string: $bad"

if ! labels_live="$(gh api --paginate --slurp "repos/$repo/labels?per_page=100" 2>/dev/null | jq -c 'add // []')"; then
  record labels error "labels" "cannot list labels"
else
  while IFS="$sep" read -r state name live_name color desc changes; do
    case "$state" in
      ok) record labels ok "$name" ;;
      missing)
        record labels missing "$name"
        plan "$name" "+ label: $name #$color \"$desc\"" \
          gh api -X POST "repos/$repo/labels" -f "name=$name" -f "color=$color" -f "description=$desc"
        ;;
      drift)
        record labels drift "$name" "$changes"
        plan "$name" "~ label: $name: $changes" \
          gh api -X PATCH "repos/$repo/labels/$(jq -rn --arg n "$live_name" '$n | @uri')" \
          -f "new_name=$name" -f "color=$color" -f "description=$desc"
        ;;
    esac
  done < <(jq -r --argjson live "$labels_live" --arg sep "$sep" '
    ($live | map({key: (.name | ascii_downcase), value: .}) | from_entries) as $by
    | .[] | . as $w | $by[$w.name | ascii_downcase] as $h
    | if $h == null then ["missing", $w.name, "", $w.color, $w.description, ""]
      else
        ([ (if $h.name != $w.name then "name \($h.name) -> \($w.name)" else empty end),
           (if ($h.color | ascii_downcase) != $w.color then "colour \($h.color) -> \($w.color)" else empty end),
           (if ($h.description // "") != $w.description
            then "description \"\($h.description // "")\" -> \"\($w.description)\"" else empty end)
         ] | join("; ")) as $c
        | [(if $c == "" then "ok" else "drift" end), $w.name, $h.name, $w.color, $w.description, $c]
      end
    | join($sep)' <<<"$labels_want")

  extras="$(jq -r --argjson want "$labels_want" '
    ($want | map(.name | ascii_downcase)) as $names
    | map(select((.name | ascii_downcase) as $n | $names | index($n) | not) | .name)
    | join(", ")' <<<"$labels_live")"
  [ -z "$extras" ] || note "not in labels.yml, kept: $extras"
fi

# --- Report -----------------------------------------------------------------

count() {
  local n=0 i
  for i in "${!rec_state[@]}"; do [ "${rec_state[$i]}" = "$1" ] && n=$((n + 1)); done
  printf '%s' "$n"
}

if [ "$cmd" = status ]; then
  printf '\n%s (%s): %s ok, %s drift, %s missing, %s unavailable-on-plan, %s skipped, %s error\n' \
    "$repo" "$visibility" "$(count ok)" "$(count drift)" "$(count missing)" \
    "$(count unavailable-on-plan)" "$(count skipped)" "$(count error)"
  [ "$(count drift)" = 0 ] && [ "$(count missing)" = 0 ] && [ "$(count error)" = 0 ]
  exit
fi

correct=0 skipped=() failed=() applied=0
for i in "${!rec_state[@]}"; do
  g="${rec_group[$i]}" s="${rec_state[$i]}" it="${rec_item[$i]}"
  if [ "$g" = enforcement ]; then
    skipped+=("$it ($s; report-only)")
  elif [ "$s" = ok ]; then
    correct=$((correct + 1))
  elif [ "$s" = unavailable-on-plan ] || [ "$s" = skipped ]; then
    skipped+=("$it ($s)")
  elif [ "$s" = error ]; then
    failed+=("$it (could not be read)")
  fi
done

printf 'Intended changes to %s (%s):\n' "$repo" "$visibility"
[ "${#plan_cmd[@]}" -gt 0 ] || printf '  none\n'
for i in "${!plan_desc[@]}"; do printf '  %s\n' "${plan_desc[$i]}"; done

if [ "$dry_run" = false ]; then
  printf '\nApplying:\n'
  for i in "${!plan_cmd[@]}"; do
    if out="$(eval "${plan_cmd[$i]}" 2>&1)"; then
      applied=$((applied + 1))
      printf '  applied  %s\n' "${plan_item[$i]}"
    else
      failed+=("${plan_item[$i]}: $(printf '%s\n' "$out" | tail -1)")
      printf '  FAILED   %s\n' "${plan_item[$i]}"
    fi
  done
fi

printf '\nSummary for %s%s:\n' "$repo" "$([ "$dry_run" = true ] && printf ' (dry run, nothing changed)')"
if [ "$dry_run" = true ]; then
  printf '  %-17s %s\n' "would apply" "${#plan_cmd[@]}"
else
  printf '  %-17s %s\n' "newly applied" "$applied"
fi
printf '  %-17s %s\n' "already correct" "$correct"
printf '  %-17s %s\n' "skipped" "${#skipped[@]}"
for s in "${skipped[@]}"; do printf '    - %s\n' "$s"; done
printf '  %-17s %s\n' "failed" "${#failed[@]}"
for f in "${failed[@]}"; do printf '    - %s\n' "$f"; done
[ "${#failed[@]}" = 0 ]

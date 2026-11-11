#!/bin/sh
# plugin-names.test.sh: no command a mod in plugins/ registers has the name
# of a skill of another plugin in plugins/.
#
# Usage: sh tests/plugin-names.test.sh
#
# Claude Code reaches a plugin's skill by its short name as well as by
# <plugin>:<name>, and refuses a mod's command of that name. The refusal
# throws in the mod's start-up hook, so the mod loads nothing. pap 0.18.0
# shipped the skill `pm` beside pm-console's command `pm` that way, and no
# suite loaded the two plugins together.
#
# The names are read from the sources: `$.command.register({ name: ... })`
# in each plugins/<plugin>/hooks/*.tsx (test files apart) and `name:` in the
# frontmatter of each plugins/<plugin>/skills/*/SKILL.md. A name built at
# run time is not seen. The first cases run the same check on throwaway
# trees, so a check that finds nothing in plugins/ is shown to find a clash
# when there is one. Prints one TAP-style line per case and exits 1 if any
# fails. No network; writes only under a temporary directory.

# SC2319: each case passes the exit status of its condition on purpose.
# SC2016: the backticks in the labels are text, not commands.
# shellcheck disable=SC2319,SC2016

set -u
# shellcheck disable=SC1091 # tests/clean-env.sh, sourced from this directory
. "$(dirname "$0")/clean-env.sh"

here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

n=0
failed=0
result() { # result <ok 0|1> <label> [detail]
  n=$((n + 1))
  if [ "$1" = 0 ]; then
    printf 'ok %d - %s\n' "$n" "$2"
  else
    printf 'not ok %d - %s\n' "$n" "$2"
    [ -z "${3:-}" ] || printf '%s\n' "$3" | sed 's/^/# /'
    failed=$((failed + 1))
  fi
}

# commands <plugins dir>: one "<plugin> <name>" line per command a mod registers.
commands() {
  for f in "$1"/*/hooks/*.tsx; do
    [ -f "$f" ] || continue
    case "$f" in *.test.tsx) continue ;; esac
    plugin="$(basename "$(dirname "$(dirname "$f")")")"
    # The name is on the line of the call or on one after it, before the call closes.
    awk -v p="$plugin" '
      index($0, "$.command.register(") { open = 1; sub(/.*\$\.command\.register\(/, "") }
      open && match($0, /name:[ \t]*["\047`][^"\047`]*["\047`]/) {
        s = substr($0, RSTART, RLENGTH); sub(/^name:[ \t]*./, "", s); sub(/.$/, "", s)
        print p, s; open = 0
      }
      open && /\}\)/ { open = 0 }' "$f"
  done
}

# skills <plugins dir>: one "<plugin> <name>" line per skill.
skills() {
  for f in "$1"/*/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    plugin="$(basename "$(dirname "$(dirname "$(dirname "$f")")")")"
    awk -v p="$plugin" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
      NR > 1 && index($0, "name: ") == 1 { print p, substr($0, 7); exit }' "$f"
  done
}

# clashes <plugins dir>: one line per command named as another plugin's skill.
clashes() {
  skills "$1" > "$tmp/skills"
  commands "$1" | while read -r plugin name; do
    while read -r other skill; do
      [ "$name" = "$skill" ] && [ "$plugin" != "$other" ] &&
        printf '%s registers /%s, which is the skill %s:%s\n' "$plugin" "$name" "$other" "$skill"
    done < "$tmp/skills"
  done
}

# tree <dir> <mod's command registration> <skill name of plugin b> [<skill name of the mod's own plugin>]
tree() {
  mkdir -p "$1/a/hooks" "$1/b/skills/one"
  printf '%s\n' "export const register = on => {" "  on('session.start', async \$ => {" "$2" "  })" "}" > "$1/a/hooks/register.tsx"
  printf '%s\n' "await \$.command.register({ name: 'tested' })" > "$1/a/hooks/register.test.tsx"
  printf '%s\n' '---' "name: $3" 'description: A skill.' '---' '' 'name: body' > "$1/b/skills/one/SKILL.md"
  [ -z "${4:-}" ] || {
    mkdir -p "$1/a/skills/own"
    printf '%s\n' '---' "name: $4" '---' > "$1/a/skills/own/SKILL.md"
  }
}

tree "$tmp/one" "    await \$.command.register({ name: 'pm', description: 'x' })" pm
out="$(clashes "$tmp/one")"
[ "$out" = 'a registers /pm, which is the skill b:pm' ]
result $? "a command registered on one line with another plugin's skill name is found" "$out"

tree "$tmp/many" "    await \$.command.register({
      name: \"pm\",
      description: 'x',
    })" pm
out="$(clashes "$tmp/many")"
[ "$out" = 'a registers /pm, which is the skill b:pm' ]
result $? "a command registered over several lines, double-quoted, is found" "$out"

tree "$tmp/apart" "    await \$.command.register({ name: 'console' })
    await \$.tool.register({ name: 'pm' })" pm
out="$(clashes "$tmp/apart")"
[ -z "$out" ] && [ "$(commands "$tmp/apart")" = 'a console' ]
result $? "a command of another name is read and is no clash, and a tool of the skill's name is not a command" "$out; commands: $(commands "$tmp/apart")"

tree "$tmp/own" "    await \$.command.register({ name: 'own' })" pm own
out="$(clashes "$tmp/own")"
[ -z "$out" ] && [ "$(skills "$tmp/own" | sort | tr '\n' ';')" = 'a own;b pm;' ]
result $? "a command named as a skill of its own plugin is no clash, and only the frontmatter's name is read" "$out; skills: $(skills "$tmp/own" | tr '\n' ';')"

[ -n "$(skills "$here/plugins")" ] && ls "$here"/plugins/*/hooks/*.tsx >/dev/null 2>&1
result $? "plugins/ has skills and at least one mod to read" "skills: $(skills "$here/plugins" | tr '\n' ';')"

out="$(clashes "$here/plugins")"
[ -z "$out" ]
result $? "no command a mod in plugins/ registers has the name of a skill of another plugin in plugins/" "$out"

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }

#!/bin/sh
# guard-route.sh: Claude Code PreToolUse hook for decisions 0002
# (decisions/0002-skills-stop-at-draft-pr.md), 0005
# (decisions/0005-agent-sessions-do-not-bypass-hooks.md), 0012
# (decisions/0012-protected-paths-need-an-owners-approved-by-line.md) and
# 0016 (decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md).
#
# Reads the tool-call JSON on stdin. For every git command in a Bash command,
# works out the directory it runs in: the session's cwd, then any `cd <dir>`
# earlier in the same command, then any `git -C <dir>`. A repository adopts
# PAP when it has an executable scripts/guard-branch.sh. Exits 2 to block the
# call, 0 otherwise. In an adopting repository:
#
#   0002  a `git commit` or `git push` runs guard-branch.sh's branch check.
#   0005  a hook bypass is refused: LEFTHOOK or LEFTHOOK_EXCLUDE set anywhere
#         in the command (as a prefix, through env or export, or earlier in
#         a sequence), `git commit --no-verify` or `-n`, `git push
#         --no-verify`, and core.hooksPath through `git config`, `-c` or
#         `--config-env`. `git push -n` is --dry-run and passes.
#   0012  a pull request body carrying an `Approved-by:` line (any case,
#         indented or not) is refused, even one the live body already has:
#         `gh pr create`, `new` or `edit` with --body/-b, --body-file/-F
#         <path> (the file is read) or --body-file - fed by a heredoc in the
#         command, and `gh api` on a pulls or pulls/<n> endpoint with a
#         body= field (-f, -F, @file) or --input <file> or - (a JSON body).
#   0016  adding the owner-reviewed label (any case, alone or in a comma
#         list, any of repeated flags) is refused: `gh pr` or `gh issue`
#         `edit --add-label`, `create` or `new` with --label/-l or
#         --add-label, `gh label edit --name owner-reviewed` (a rename
#         into it), and `gh api` on issues/<n> or issues/<n>/labels with a
#         labels or labels[] field or an --input JSON body naming it, or on
#         labels/<name> with new_name=owner-reviewed. Merging is refused:
#         `gh pr merge` with any flags, --auto included, and `gh api -X PUT`
#         on pulls/<n>/merge. In every repository that adopts PAP, opted in
#         to risk mode or not. Removing a label and every other gh call pass.
#
# The rules live here and in each repository's guard-branch.sh; this script
# decides which repository a command targets, so a session in one repository
# neither blocks commits to another nor lets a commit to a guarded one through.
# Humans are unaffected: the hook runs only on an agent's Bash tool calls.
#
# Parsing is deliberately simple. It follows cd and git -C across &&, ||, ;,
# |, newlines and subshell parentheses, skips git's -c and other global
# options, and reads quoted words as one, so a commit message that mentions
# --no-verify passes. It does not follow bash -c, eval, GIT_DIR, --git-dir or
# GIT_CONFIG_* variables; the pre-push hook and the repository ruleset remain
# the backstop for main, and nothing yet backs up pre-commit.
#
# For 0012 the command is read once more with heredocs lifted out and words
# taken quote-aware, so a quoted body may span lines. The same limits hold:
# no bash -c, eval, scripts, variables or command substitution other than a
# heredoc inside the body word; a body piped in from anything but a heredoc
# (echo, cat <file>) passes; GraphQL mutations through `gh api graphql`
# pass. An `Approved-by:` line elsewhere, as in a commit message, passes.
# The pr-checks workflow still cannot tell who typed a line that got through.
#
# 0016 reads the same words, with the same limits: a label or merge through
# `gh api graphql` (addLabelsToLabelable, mergePullRequest), bash -c, eval,
# a script, or a label held in a variable or command substitution passes,
# as does an --input body piped from anything but a heredoc. Neither the
# label nor the merge can be traced to who did it once it is through.

set -u

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the command cannot be parsed. Complain only in a session whose
  # own repository is guarded, as the hook did before routing existed.
  [ -x "${CLAUDE_PROJECT_DIR:-.}/scripts/guard-branch.sh" ] || exit 0
  printf 'guard-route: jq not found; cannot parse the tool call\n' >&2
  exit 1
fi

targets="$(jq -r '
  def unquote: if test("^\".*\"$") or test("^'"'"'.*'"'"'$") then .[1:-1] else . end;
  def resolve($base):
    unquote
    | if . == "" or . == "~" then env.HOME
      elif startswith("~/") then env.HOME + .[1:]
      elif startswith("/") then .
      else $base + "/" + . end;
  def arg: "(\"[^\"]*\"|'"'"'[^'"'"']*'"'"'|[^\\s]+)";

  # Decision 0012: pull request bodies. Heredocs are lifted out first and
  # replaced by <<@HD<n>; the command is then read as quote-aware words.
  def approval: test("(^|\\n)[ \\t\\r\\f\\v]*approved-by:"; "i");
  def hdre: "(?<!<)<<(?![<@])-?[ \\t]*(?<q>['"'"'\"]?)(?<d>[A-Za-z_][A-Za-z0-9_]*)\\k<q>(?<mid>[^\\n]*)\\n(?<body>(?:[^\\n]*\\n)*?)\\t*\\k<d>[ \\t]*(?=\\n|$)";
  def lift:
    {cmd: ., docs: []}
    | until((.cmd | test(hdre)) | not;
        (.cmd | match(hdre)) as $m
        | ([$m.captures[] | {key: .name, value: .string}] | from_entries) as $c
        | .cmd = .cmd[:$m.offset] + "<<@HD\(.docs | length) " + $c.mid + .cmd[$m.offset + $m.length:]
        | .docs += [$c.body]);
  def word: "(?:\"(?:[^\"\\\\]|\\\\.)*\"|'"'"'[^'"'"']*'"'"'|\\$'"'"'(?:[^'"'"'\\\\]|\\\\.)*'"'"'|\\\\.|[^\\s\"'"'"'();&|<>\\\\])+";
  def unword:
    [scan("\"((?:[^\"\\\\]|\\\\.)*)\"|'"'"'([^'"'"']*)'"'"'|\\$'"'"'((?:[^'"'"'\\\\]|\\\\.)*)'"'"'|\\\\(.)|([^\"'"'"'\\\\$]+|\\$)")
     | if .[0] != null then .[0] | gsub("\\\\(?<c>[\"\\\\$`])"; .c)
       elif .[1] != null then .[1]
       elif .[2] != null then .[2] | gsub("\\\\n"; "\n") | gsub("\\\\t"; "\t")
       elif .[3] != null then .[3] else .[4] end] | add // "";
  def marks: [scan("<<@HD([0-9]+)") | .[0] | tonumber];
  # optat($a; $i; $long; $short): the value of --long v, --long=v, -s v, -sv
  # or -s=v at word $i of $a.
  def optat($a; $i; $long; $short):
    $a[$i] as $w
    | if $w == $long or $w == $short then $a[$i + 1] // empty
      elif ($w | startswith($long + "=")) then $w[($long | length) + 1:]
      elif ($w | startswith($short)) and ($short | test("^-[A-Za-z]$")) then $w[2:] | ltrimstr("=")
      else empty end;

  # Decision 0016: the owner-reviewed label and the merge belong to the owner.
  # One finding per write: "label" or "merge" when the command shows it,
  # "labelfile" when gh api reads a JSON body from a file.
  def ownerlabel: ascii_downcase | gsub("^\\s+|\\s+$"; "") == "owner-reviewed";
  def listed: unword | split(",") | any(ownerlabel);
  def jsonlabels:
    (if type == "object" then .labels? else . end)
    | arrays | .[] | (strings, (objects | .name? | strings));
  def owner($dir; $docs; $stmt):
    . as $a | ($a | length) as $n
    | [$stmt[] | marks[]] as $all
    | def adds($route): "label\t\($dir)\t\($route)";
      def field($i): optat($a; $i; "--raw-field"; "-f"), optat($a; $i; "--field"; "-F");
      if $a[0] == "pr" and $a[1] == "merge" then "merge\t\($dir)\tgh pr merge"
      elif ($a[0] | IN("pr", "issue")) and ($a[1] | IN("edit", "create", "new")) then
        ("gh \($a[0]) \($a[1])") as $r
        | range(2; $n) as $i
        | ((optat($a; $i; "--add-label"; "--add-label") | select(listed) | adds($r + " --add-label")),
           (if $a[1] == "edit" then empty
            else optat($a; $i; "--label"; "-l") | select(listed) | adds($r + " --label") end))
      elif $a[0] == "label" and $a[1] == "edit" then
        range(2; $n) as $i
        | optat($a; $i; "--name"; "-n") | select(unword | ownerlabel) | adds("gh label edit --name")
      elif $a[0] == "api" then
        [$a[] | unword] as $u
        | ([range(1; $n) as $i | optat($a; $i; "--method"; "-X") | unword | ascii_upcase] | last) as $method
        | (if $method == "PUT" and ($u | any(test("(^|/)pulls/[0-9]+/merge/?([?].*)?$")))
           then "merge\t\($dir)\tgh api PUT pulls/<n>/merge" else empty end),
          (if $u | any(test("(^|/)issues/[0-9]+(/labels)?/?([?].*)?$")) then
             range(1; $n) as $i
             | ((field($i) | unword | select(test("^labels(\\[\\])?="))
                 | select(sub("^[^=]*="; "") | split(",") | any(ownerlabel))
                 | adds("gh api labels")),
                (optat($a; $i; "--input"; "--input") | unword
                 | if . == "-" then
                     first($all[] | $docs[.] | fromjson? | select(any(jsonlabels; ownerlabel)))
                     | adds("gh api --input")
                   else "labelfile\t\($dir)\tgh api --input\t\(if startswith("/") then . else $dir + "/" + . end)" end))
           else empty end),
          (if $u | any(test("(^|/)labels/[^/?]+/?([?].*)?$")) then
             range(1; $n) as $i
             | field($i) | unword | select(test("^new_name="))
             | select(sub("^[^=]*="; "") | ownerlabel) | adds("gh api labels new_name")
           else empty end)
      else empty end;
  # One finding per body the command writes: "approval" when the text is in
  # the command, "bodyfile" or "jsonfile" when gh reads it from a file.
  def bodies($dir; $docs; $stmt):
    . as $a | ($a | length) as $n
    | [$stmt[] | marks[]] as $all
    | def found($route): select(approval) | "approval\t\($dir)\t\($route)";
      def stdin($kind; $route):
        $all[] | $docs[.] | (., if $kind == "jsonfile" then (fromjson? | .body? | strings) else empty end) | found($route);
      # $v is a word as written; a heredoc inside it, as in "$(cat <<EOF ...)", counts.
      def text($route; $v): (($v | unword | ltrimstr("body=")), ($v | marks[] | $docs[.])) | found($route);
      def file($kind; $route; $f):
        if $f == "-" then stdin($kind; $route)
          else "\($kind)\t\($dir)\t\($route)\t\(if ($f | startswith("/")) then $f else $dir + "/" + $f end)" end;
      def opt($i; $long; $short): optat($a; $i; $long; $short);
      if $a[0] == "pr" and ($a[1] | IN("create", "new", "edit")) then
        ("gh pr " + $a[1]) as $r
        | range(2; $n) as $i
        | (opt($i; "--body"; "-b") | text($r + " --body"; .)),
          (opt($i; "--body-file"; "-F") | unword | file("bodyfile"; $r + " --body-file"; .))
      elif $a[0] == "api" and ($a | any(unword | test("(^|/)pulls(/[0-9]+)?/?([?].*)?$"))) then
        range(1; $n) as $i
        | ((opt($i; "--raw-field"; "-f"), opt($i; "--field"; "-F"))
           | select(unword | startswith("body="))
           | if unword | startswith("body=@") then unword | file("bodyfile"; "gh api body=@"; .[6:])
             else text("gh api body="; .) end),
          (opt($i; "--input"; "--input") | unword | file("jsonfile"; "gh api --input"; .))
      else empty end;
  def prbodies($cwd):
    lift as $l
    | [$l.cmd | scan("&&|\\|\\||[;&|()\\n]|<<@HD[0-9]+|<<<|[0-9]*[<>]+&?|" + word)]
    | reduce .[] as $t ({dir: $cwd, stmts: [[]]};
        if ($t | IN("&&", "||", ";", "&", "\n")) then .stmts += [[]]
        elif ($t | IN("(", ")")) then .
        else .stmts[-1] += [$t] end)
    | reduce .stmts[] as $st ({dir: $cwd, out: []};
        . as $s
        | ([$st | .[] | select(. != "|")]) as $w
        | if $w[0] == "cd" then .dir = (($w[1] // "~" | unword) | resolve($s.dir))
          else
            .out += [ $st
              | [foreach (.[], "|") as $t ({cur: [], done: null};
                  if $t == "|" then {cur: [], done: .cur} else {cur: (.cur + [$t]), done: null} end;
                  .done // empty)]
              | .[]
              | ([.[] | select(test("^(env|-.*|[A-Za-z_][A-Za-z0-9_]*=.*)$") | not)] | .[0]) as $head
              | select($head == "gh")
              | .[(index("gh") + 1):]
              | (bodies($s.dir; $l.docs; $st), owner($s.dir; $l.docs; $st)) ]
          end)
    | .out[];

  select(.tool_name == "Bash")
  | (.cwd // env.CLAUDE_PROJECT_DIR // ".") as $cwd
  | ((.tool_input.command // "") | try prbodies($cwd) catch empty),
    ([(.tool_input.command // "") | splits("&&|\\|\\||;|\\||\\n|\\(|\\)")]
  | reduce .[] as $seg ({dir: $cwd, lefthook: null, out: []};
      . as $st
      | ($seg | gsub("^\\s+|\\s+$"; "")) as $s
      | if ($s | test("^cd(\\s|$)")) then
          .dir = ((($s | capture("^cd\\s+(?<a>" + arg + ")")? | .a) // "~") | resolve($st.dir))
        else
          # [...][0] turns a failed match into null; an empty update would
          # reset the reduce state and lose the directory tracked so far.
          ([$s | capture("^(env(\\s+-[^\\s]+)*\\s+)?([A-Za-z_][A-Za-z0-9_]*=[^\\s]*\\s+)*git(?<opts>(\\s+-[Cc]\\s+" + arg
                         + "|\\s+--?[A-Za-z][A-Za-z0-9-]*(=[^\\s]+)?)*)\\s+(?<sub>[^\\s]+)(?<rest>.*)$")?][0]) as $m
          # A LEFTHOOK assignment sticks for the rest of the command, as
          # export would; over-refusing a prefix assignment is harmless.
          | ([$s | scan(arg) | .[0] | select(test("^(LEFTHOOK|LEFTHOOK_EXCLUDE)="))][0] // .lefthook) as $lh
          | .lefthook = $lh
          | if $m == null then
              if $lh != null then .out += ["bypass\t\($st.dir)\t\($lh)"] else . end
            else
              (reduce ([$m.opts | scan("-C\\s+" + arg)] | map(.[0]))[] as $c
                 ($st.dir; . as $d | $c | resolve($d))) as $t
              | ([$m.rest | scan(arg) | .[0]]) as $args
              | (if $m.sub == "commit" or $m.sub == "push" then .out += ["branch\t\($t)"] else . end)
              | (if $lh != null then .out += ["bypass\t\($t)\t\($lh)"] else . end)
              | (if ($m.opts | test("core\\.hookspath"; "i"))
                    or ($m.sub == "config" and ($m.rest | test("core\\.hookspath"; "i")))
                 then .out += ["bypass\t\($t)\tcore.hooksPath"] else . end)
              | (if ($m.sub == "commit" or $m.sub == "push")
                    and ($args | any(test("^--no-veri(fy?)?$")))
                 then .out += ["bypass\t\($t)\t--no-verify"] else . end)
              | (if $m.sub == "commit" and ($args | any(test("^-[^-mFCctuS]*n")))
                 then .out += ["bypass\t\($t)\tcommit -n"] else . end)
            end
        end)
    | .out[])
' | sort -u)" || exit 0

[ -n "$targets" ] || exit 0

tab="$(printf '\t')"
status=0

# approved <file> <kind>: the file carries an Approved-by line, as text or,
# for gh api --input, as the body field of a JSON object.
approved() {
  [ -f "$1" ] || return 1
  if [ "$2" = jsonfile ]; then
    jq -r '.body? // empty' "$1" 2>/dev/null | grep -qi '^[[:space:]]*approved-by:' && return 0
  fi
  grep -qi '^[[:space:]]*approved-by:' "$1"
}

# labelled <file>: the JSON file gh api --input reads adds owner-reviewed, as
# a labels array or a bare array of names or {name} objects.
labelled() {
  [ -f "$1" ] || return 1
  jq -e '[(if type == "object" then .labels? else . end) | arrays | .[]
          | (strings, (objects | .name? | strings))]
         | any(ascii_downcase | gsub("^\\s+|\\s+$"; "") == "owner-reviewed")' "$1" >/dev/null 2>&1
}

while IFS="$tab" read -r kind target reason file; do
  root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || continue
  guard="$root/scripts/guard-branch.sh"
  [ -x "$guard" ] || continue
  case "$kind" in
    branch)
      (cd "$root" && "$guard" branch) || status=2
      ;;
    bypass)
      printf 'guard-route: refusing %s in %s\n' "$reason" "$root" >&2
      printf 'guard-route: decision 0005: agent sessions may not bypass git hooks; fix what the hook reports, or ask the human.\n' >&2
      status=2
      ;;
    approval | bodyfile | jsonfile)
      [ "$kind" = approval ] || approved "$file" "$kind" || continue
      printf 'guard-route: refusing an Approved-by line in a pull request body (%s) in %s\n' "$reason" "$root" >&2
      printf 'guard-route: decision 0012: the line is the owner'"'"'s to type by hand; a rewritten body must drop it, and the owner re-approves.\n' >&2
      status=2
      ;;
    label | labelfile)
      [ "$kind" = label ] || labelled "$file" || continue
      printf 'guard-route: refusing the owner-reviewed label (%s) in %s\n' "$reason" "$root" >&2
      printf 'guard-route: decision 0016: the owner adds owner-reviewed after review; an agent never does (rule 16.2).\n' >&2
      status=2
      ;;
    merge)
      printf 'guard-route: refusing a merge (%s) in %s\n' "$reason" "$root" >&2
      printf 'guard-route: decision 0016: the owner merges; an agent stops at the draft pull request (rule 16.2).\n' >&2
      status=2
      ;;
  esac
done <<EOF
$targets
EOF
exit "$status"

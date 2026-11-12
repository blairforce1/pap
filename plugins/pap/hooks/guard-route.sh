#!/bin/sh
# guard-route.sh: Claude Code PreToolUse hook for decisions 0002
# (decisions/0002-skills-stop-at-draft-pr.md), 0005
# (decisions/0005-agent-sessions-do-not-bypass-hooks.md), 0012
# (decisions/0012-protected-paths-need-an-owners-approved-by-line.md),
# 0016 (decisions/0016-risk-labels-and-an-owner-reviewed-label-replace-approved-by.md),
# 0022 (decisions/0022-no-branch-takes-a-force-push.md), 0023
# (decisions/0023-agents-act-on-github-as-their-own-app.md), 0025
# (decisions/0025-pap-runs-as-the-project-manager-by-default.md) and 0027
# (decisions/0027-an-agent-opens-its-pull-request-from-a-worktree-with-its-class-label.md).
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
#   0022  a `git push` with --force, -f, --force-with-lease,
#         --force-if-includes, --mirror or a `+<refspec>` runs guard-branch.sh's
#         push-args check, which refuses it, on any branch. A push is
#         let through if the repository's guard predates push-args.
#   0023  every `git push` runs the same push-args check, which also
#         refuses a push to an SSH remote (rule 23.1): an agent pushes over
#         HTTPS as the pap-agent app.
#         gh run by a path (`/usr/bin/gh`, `./gh`, `~/bin/gh`, also after
#         env, command or exec) or with a `PATH=` assignment is refused
#         (rule 23.1): it skips the shim. `command gh` and `env gh` find
#         the shim on PATH and pass. In an adopting repository, gh by name
#         and git push, fetch, pull, clone, ls-remote or remote update to a
#         GitHub HTTPS remote are refused unless the session was started by
#         pap claude (rule 23.4; see session_ok); so are they in any other
#         directory, repository or not, when the session's project
#         (CLAUDE_PROJECT_DIR) adopts PAP. In every repository,
#         adopting or not,
#         GH_CONFIG_DIR changed in assignment position (= or += as a prefix
#         or after env, export, declare, typeset, readonly or local; unset,
#         env -u, env -i) is refused (rule 23.4): pap claude sets it to the
#         agent's gh directory and it stays so. A mention elsewhere (grep
#         GH_CONFIG_DIR= docs) passes. So is a read of gh's keyring entry,
#         service gh:github.com (secret-tool lookup or search naming it,
#         security find-generic-password or find-internet-password naming
#         it, security dump-keychain) or gh printing its token (gh auth
#         token, gh auth status -t), a command naming the agent directory
#         (gh-agent, or $GH_CONFIG_DIR expanded) or signing gh in (gh auth
#         login, switch, refresh), and running reviewed.sh or accept.sh,
#         the owner's skill scripts, by name or path (also after sh, bash,
#         env or source): a skill's own preprocessing never reaches this
#         hook, so only an agent's call is refused.
#         None follows bash -c, eval, scripts, a name built from a
#         variable, set -a with read, or another language's subprocess;
#         HOME or XDG_CONFIG_HOME pointed at a copy of the owner's
#         directory passes; a heredoc line that assigns it is refused.
#
#   0025  PAP_MODE changed in assignment position, as GH_CONFIG_DIR above
#         (= or += as a prefix or after env, export and its kin; unset,
#         env -u), is refused in every repository, for every caller: pap
#         claude sets the mode and it stays so. pap-pm.sh, the /pap:pm
#         script, run by name or path from a sub-agent's command is
#         refused: /pap:pm needs the main session. In a session pap claude
#         started in PM mode (PAP_MODE=pm in the hook's own environment), a
#         `git commit` by the main session, a call with no agent id, is
#         refused when the work tree it runs in is an adopting
#         repository's and holds any change outside the PM paths: staged,
#         unstaged, or untracked and not ignored (rule 25.2; pm-lib.sh has
#         the paths). The whole work tree is judged because the hook runs
#         before the command and cannot know what it will stage. Each
#         refused file is a line in the refusal log. A sub-agent's commit
#         is never judged. Only `git commit` is: merge, cherry-pick,
#         revert, am, rebase, commit-tree, update-ref, gh api on a
#         repository's contents, and a commit with --git-dir or GIT_DIR
#         pass, as limits of the rule. A call this hook cannot parse is
#         let through, as before, and in a PM session is said and logged
#         as an unread line.
#
#   0027  In a session pap claude started in PM mode only, for its main
#         session and its sub-agents alike. Rule 27.1: a `gh pr create` or
#         `gh pr new` is refused in the main checkout of an adopting
#         repository, whatever its labels, and elsewhere unless it gives
#         exactly one class label: a --label or -l value, split on commas,
#         that is class: and one of feature, infra, security-sensitive,
#         bugfix, spike, chore, docs. A value holding $ or a backquote is
#         not counted. It binds in an adopting repository, and anywhere
#         when the session's project adopts PAP, whatever -R names. A pull
#         request opened through `gh api` or GraphQL passes, as a limit.
#         One of the four verbs after a word the guard does not take for
#         a command's head (`then`, `command`, `xargs`) is let through and
#         logged as an unread line. Rule 27.2: a `git switch` or
#         `git checkout` that runs in the main checkout of an adopting
#         repository (the work tree whose git directory is the
#         repository's own) is refused, but for `git switch main`, `git
#         checkout main`, a path restore (`git checkout [<tree>] --
#         <path>`) and `git checkout` with no word. Any -c, -C, -d,
#         --create, --force-create, --detach or --orphan (for checkout -b,
#         -B, -d, --detach, --orphan), or an abbreviation of a long one,
#         makes it a branch switch. A checkout of one word with no `--`
#         may be a path: it is refused, and logged as path-without-dashes.
#         Nothing is refused in a linked work tree. A directory the guard
#         cannot place is refused when the session's project adopts PAP:
#         one that does not exist as the guard runs, one written with a
#         variable, `cd -`, pushd or popd, and a git directory given by
#         GIT_DIR, GIT_WORK_TREE, --git-dir or --work-tree. The forms let
#         through in the main checkout are let through there too. Each
#         refusal is a line in the refusal log, with its kind and the form
#         refused. Placing a directory is one git call, made only for
#         these verbs. `git branch -m`, `git stash branch`, `git rebase
#         <upstream> <branch>`, `git bisect start` and `git symbolic-ref
#         HEAD` pass, as limits of the rule, as does git reached through
#         bash -c, a script or an alias.
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

# SC2154: the pm_ variables are set by pm-lib.sh's functions.
# shellcheck disable=SC2154
set -u

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the command cannot be parsed. Complain only in a session whose
  # own repository is guarded, as the hook did before routing existed.
  [ -x "${CLAUDE_PROJECT_DIR:-.}/scripts/guard-branch.sh" ] || exit 0
  printf 'guard-route: jq not found; cannot parse the tool call\n' >&2
  exit 1
fi

input="$(cat)"
targets="$(printf '%s' "$input" | jq -r '
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
  # Decision 0027: where a git switch or checkout runs, and what it is.
  def dyn: test("[$`]");
  # The words of one command less its redirections and their targets.
  def noredir:
    reduce .[] as $t ({skip: false, out: []};
      if .skip then .skip = false
      elif ($t | test("^(<<<|[0-9]*[<>]+&?)$")) then .skip = true
      elif ($t | test("^<<@HD[0-9]+$")) then .
      else .out += [$t] end)
    | .out;
  def pieces:
    [foreach (.[], "|") as $t ({cur: [], done: null};
       if $t == "|" then {cur: [], done: .cur} else {cur: (.cur + [$t]), done: null} end;
       .done // empty)];
  def headat:
    . as $q
    | first(range(0; length) | select($q[.] | test("^(env|-.*|[A-Za-z_][A-Za-z0-9_]*=.*)$") | not)) // null;
  # GIT_DIR or GIT_WORK_TREE in assignment position: the word, or null.
  def gitenv:
    . as $w
    | (headat // length) as $k
    | (if ($w[0] // "" | IN("export", "declare", "typeset", "readonly", "local")) then $w[1:] else $w[:$k] end)
    | [.[] | select(test("^(GIT_DIR|GIT_WORK_TREE)\\+?="))][0] // null;
  # The words after `git`: its global options skipped and -C applied. un is
  # the word that makes the directory one the guard cannot place.
  def gitsub($dir):
    . as $a
    | {i: 0, dir: $dir, un: null, done: false}
    | until(.done or .i >= ($a | length);
        $a[.i] as $x
        | if ($x | startswith("-") | not) then .done = true
          elif $x == "-C" then
            ($a[.i + 1] // "") as $v
            | (if ($v | dyn) then .un = (.un // $v) else . end)
            | .dir = (.dir as $d | $v | unword | resolve($d))
            | .i += 2
          elif ($x | test("^--(git-dir|work-tree)(=|$)")) then
            .un = (.un // $x) | .i += (if ($x | contains("=")) then 1 else 2 end)
          elif ($x | IN("-c", "--namespace", "--config-env", "--super-prefix", "--attr-source")) then .i += 2
          else .i += 1 end)
    | {dir, un, sub: ($a[.i] // "" | unword), rest: $a[.i + 1:]};
  def shortopt($letters): test("^-[^-]") and (.[1:] | test("[" + $letters + "]"));
  # A long option or an abbreviation of one; --force is its own option.
  def longopt($names):
    sub("=.*"; "") as $o
    | ($o | test("^--[a-z]")) and $o != "--force" and ($names | any(startswith($o)));
  # verdict($verb): of the words after git switch or git checkout. ok is a
  # form rule 27.2 lets through in the main checkout.
  def verdict($verb):
    [.[] | unword] as $u
    | def nonopts: [.[] | select((startswith("-") | not) or . == "-")];
      if $verb == "switch" then
        if ($u | any(shortopt("cCd") or longopt(["--create", "--force-create", "--detach", "--orphan"])))
        then "branch-switch"
        elif ($u | nonopts) == ["main"] then "ok"
        else "branch-switch" end
      else
        ($u | index("--")) as $dd
        | if ((if $dd == null then $u else $u[:$dd] end)
              | any(shortopt("bBd") or longopt(["--detach", "--orphan"])))
          then "branch-switch"
          elif $dd != null then (if ($u | length) > $dd + 1 then "ok" else "branch-switch" end)
          else
            ($u | nonopts) as $n
            | if $n == [] or $n == ["main"] then "ok"
              elif ($n | length) == 1 then "path-without-dashes"
              else "branch-switch" end
          end
      end;
  # The form refused, for the log: the verb and its options, never a value.
  def form($verb):
    "git " + $verb
    + ([.[] | unword
        | if IN("main", "--", "-") then .
          elif test("^-") then (capture("^(?<o>-[-A-Za-z0-9]*)") | .o)
          else "<word>" end
        | " " + .] | add // "");
  # at27($dir; $un; $cdw; $i): the target the word at $i starts, if any.
  def at27($dir; $un; $cdw; $i):
    . as $q
    | if $q[$i] == "git" then
        ($q[$i + 1:] | gitsub($dir)) as $g
        | select($g.sub | IN("switch", "checkout"))
        | ($g.rest | verdict($g.sub)) as $v
        | select($v != "ok")
        | "sw\t\($g.dir)\tgit \($g.sub)\t"
          + ([$v, (if ($un // $g.un) != null then "unplaced" else "placed" end),
              ($un // $g.un // $cdw // "-"), ($g.rest | form($g.sub)), "end"] | join("\u001f"))
      elif $q[$i] == "gh" and $q[$i + 1] == "pr" and ($q[$i + 2] // "" | IN("create", "new")) then
        # Rule 27.1: the literal class labels the command gives. A value
        # holding $ or a backquote cannot be read and is not counted.
        $q[$i + 3:] as $a
        | ([range(0; $a | length) as $j
            | optat($a; $j; "--label"; "-l") | unword | split(",")[]
            | gsub("^\\s+|\\s+$"; "")
            | select(test("^class:(feature|infra|security-sensitive|bugfix|spike|chore|docs)$"))]
           | length) as $c
        | "pr\t\($dir)\t\($c)\t"
          + ([(if $un != null then "unplaced" else "placed" end), ($un // $cdw // "-"),
              "gh pr " + $q[$i + 2], "end"] | join("\u001f"))
      else empty end;
  # The targets of one command, and unread27 when a word that is not its
  # head starts one of the verbs, as after `then`: the guard does not know
  # where that runs.
  def targets27($dir; $un; $cdw):
    noredir as $q
    | ($q | headat) as $h
    | select($h != null)
    | ($q | at27($dir; $un; $cdw; $h)),
      (if any(range(0; $q | length) | select(. != $h);
              . as $i | [$q | at27($dir; $un; $cdw; $i)] | length > 0)
       then "unread27\t-\t-" else empty end);
  def prbodies($cwd):
    lift as $l
    | [$l.cmd | scan("&&|\\|\\||[;&|()\\n]|<<@HD[0-9]+|<<<|[0-9]*[<>]+&?|" + word)]
    | reduce .[] as $t ({dir: $cwd, stmts: [[]]};
        if ($t | IN("&&", "||", ";", "&", "\n")) then .stmts += [[]]
        elif ($t | IN("(", ")")) then .
        else .stmts[-1] += [$t] end)
    | reduce .stmts[] as $st ({dir: $cwd, out: [], un: null, cdw: null};
        ([$st | .[] | select(. != "|")]) as $w
        | .un = (.un // ($w | gitenv))
        | . as $s
        | if $w[0] == "cd" then
            ($w[1] // "~") as $x
            | .cdw = $x
            | (if ($x | dyn) or $x == "-" then .un = (.un // $x) else . end)
            | .dir = (($x | unword) | resolve($s.dir))
          elif ($w[0] // "" | IN("pushd", "popd")) then .un = (.un // ($w | join(" ")))
          else
            .out += [$st | pieces | .[] | targets27($s.dir; $s.un; $s.cdw)] |
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
  | ((.tool_input.command // "") as $c
     | try ($c | prbodies($cwd))
       catch (if ($c | type) == "string"
                 and ($c | test("\\bgh\\s+pr\\s+(create|new)\\b|\\bgit\\s(.*\\s)?(switch|checkout)\\b"))
              then "unread27\t-\t-" else empty end)),
    ([(.tool_input.command // "") | splits("&&|\\|\\||;|\\||\\n|\\(|\\)")]
  | reduce .[] as $seg ({dir: $cwd, lefthook: null, out: []};
      . as $st
      | ($seg | gsub("^\\s+|\\s+$"; "")) as $s
      # Decision 0023, rule 23.4: GH_CONFIG_DIR assigned (= or +=) in
      # assignment position: the leading words (prefix assignments, env and
      # its flags, the name after -u), or any word after export and its kin.
      # A word elsewhere, as in a grep pattern, passes.
      | ([$s | scan(arg) | .[0] | unquote]) as $w
      | ([foreach $w[] as $x ({go: true, prev: "", out: null};
            if .go and (($x | test("^(env|-[^=]*|[A-Za-z_][A-Za-z0-9_]*\\+?=.*)$")) or (.prev | IN("-u", "--unset")))
            then {go: true, prev: $x, out: $x} else {go: false, prev: $x, out: null} end;
            .out // empty)]) as $lead
      | (if ($lead | any(test("^GH_CONFIG_DIR(\\+?=|$)")))
            or ((($w[0] // "") == "env") and ($lead | any(IN("-i", "--ignore-environment"))))
            or ((($w[0] // "") | IN("export", "declare", "typeset", "readonly", "local", "unset"))
                and ($w[1:] | any(test("^GH_CONFIG_DIR(\\+?=|$)"))))
         then .out += ["ghconfig\t\($st.dir)\tGH_CONFIG_DIR"] else . end)
      # Decision 0025, rule 25.1: pap claude sets the mode, and nothing else.
      | (if ($lead | any(test("^PAP_MODE(\\+?=|$)")))
            or ((($w[0] // "") | IN("export", "declare", "typeset", "readonly", "local", "unset"))
                and ($w[1:] | any(test("^PAP_MODE(\\+?=|$)"))))
         then .out += ["papmode\t\($st.dir)\tPAP_MODE"] else . end)
      # Rule 23.1: gh run by a path, or with PATH changed, skips the shim.
      | ([$w[] | select(test("^(env|command|exec|nohup|time|-.*|[A-Za-z_][A-Za-z0-9_]*=.*)$") | not)][0]) as $h
      | (if (($h // "") | test("/gh$")) or ($h == "gh" and ($w | any(test("^PATH="))))
         then .out += ["ghpath\t\($st.dir)\t\($h)"] else . end)
      # Rule 23.4: any gh by name, for the session check.
      | (if $h == "gh" then .out += ["ghcall\t\($st.dir)\tgh"] else . end)
      # Rule 23.4: the keyring entry gh keeps the owner token in (service
      # gh:github.com), and gh printing that token.
      | ($w | join(" ")) as $j
      | (if ($h == "secret-tool" and ($w | any(IN("lookup", "search"))) and ($j | test("gh:")))
            or ($h == "security" and ($w | any(test("^find-(generic|internet)-password$"))) and ($j | test("gh:")))
            or ($h == "security" and ($w | any(. == "dump-keychain")))
            or ($h == "gh" and ($j | test("(^|\\s)gh\\s+auth\\s+(token(\\s|$)|status\\s.*(-t|--show-token)(\\s|$))")))
         then .out += ["keyring\t\($st.dir)\t\($h)"] else . end)
      # Rule 23.4: the agent directory stays empty. A hosts.yml naming the
      # owner would make gh fetch the owner token from the keyring, and a
      # gh auth login there would sign it in. No agent needs to name it.
      | (if ($j | test("gh-agent|\\$\\{?GH_CONFIG_DIR"))
            or ($h == "gh" and ($j | test("(^|\\s)gh\\s+auth\\s+(login|switch|refresh)(\\s|$)")))
         then .out += ["agentdir\t\($st.dir)\t\($h)"] else . end)
      # Rule 23.4: the two skill scripts that act as the owner. The skill
      # runs them by its own preprocessing, which no PreToolUse hook sees.
      | ([$w[] | select(test("^(env|command|exec|nohup|time|sh|bash|dash|zsh|source|\\.|-.*|[A-Za-z_][A-Za-z0-9_]*=.*)$") | not)][0]) as $x
      | (if (($x // "") | test("(^|/)(reviewed|accept)\\.sh$"))
         then .out += ["ownerscript\t\($st.dir)\t\($x)"] else . end)
      # Decision 0025: the /pap:pm script runs in the main session only.
      | (if (($x // "") | test("(^|/)pap-pm\\.sh$"))
         then .out += ["pmscript\t\($st.dir)\t\($x)"] else . end)
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
              | (if $m.sub == "commit" then .out += ["pmcommit\t\($t)"] else . end)
              | (if $m.sub == "push"
                 then .out += ["push\t\($t)\t\($args | map(unquote) | join("\u001f"))"] else . end)
              # Rule 23.4: git that talks to a remote, through the credential helper.
              | (if ($m.sub | IN("push", "fetch", "pull", "clone", "ls-remote"))
                    or ($m.sub == "remote" and ($args[0] // "") == "update")
                 then .out += ["gitnet\t\($t)\t\($m.sub)\t\($args | map(unquote) | join("\u001f"))"] else . end)
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
')" || {
  # A call that cannot be parsed is let through, as it always was. In a PM
  # session it is said and logged, so the window can count them. jq's own
  # exit status is read here, before sort, whose status would hide it.
  if [ "${PAP_MODE:-}" = pm ]; then
    # shellcheck disable=SC1091 # pm-lib.sh, beside this script
    . "$(dirname "$0")/pm-lib.sh"
    printf 'guard-route: could not read the tool call; nothing was checked for it\n' >&2
    pm_log refusals.log "$(pm_now)" - pm unknown - - unread
  fi
  [ -n "$targets" ] || exit 0
}
targets="$(printf '%s\n' "$targets" | sort -u)"

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

# Rule 23.4: whether this session was started by pap claude, asked of the
# gh first on PATH. Claude Code runs hooks with its own environment, which
# pap claude set. That gh must be the shim, and the shim, in its check mode,
# applies its own tests: the agent directory and an empty hosts.yml. A shim
# without the check mode fails it. A dev container with no key passes, as
# the shim steps aside there (pap agent-key status exits 1); the hook never
# runs a shim from the working tree, which the agent can edit.
session=""
session_ok() { # session_ok <root>
  if [ -z "$session" ]; then
    session=no
    if { [ -f /.dockerenv ] || [ -n "${REMOTE_CONTAINERS:-}" ]; } && command -v pap >/dev/null 2>&1; then
      pap agent-key status >/dev/null 2>&1
      [ $? != 1 ] || session=yes
    fi
    g="$(command -v gh 2>/dev/null)" || g=""
    l2=""
    [ -z "$g" ] || { read -r _ && read -r l2; } 2>/dev/null < "$g" || true
    case "$l2" in
      "# pap-gh-shim:"*)
        if grep -q PAP_SHIM_CHECK "$g" 2>/dev/null &&
          (cd "$1" && CLAUDECODE=1 PAP_SHIM_CHECK=1 "$g" >/dev/null 2>&1); then
          session=yes
        fi ;;
    esac
  fi
  [ "$session" = yes ]
}
# github_https <root> <sub> <words>: whether the git call reaches GitHub
# over HTTPS, each URL as git resolves it (a remote's, insteadOf applied).
# Any word that resolves to GitHub counts. The repository is the first word
# that is a remote or looks like a URL or path, so an option's value
# (--depth 1, -o x) is not taken for it; with none, the default remote (each
# named remote, or every remote, for remote update).
github_https() {
  gw="$(printf '%s' "$3" | tr '\037' '\n' | grep -v '^-')"
  remotes="$(git -C "$1" remote 2>/dev/null)"
  if [ "$2" = remote ]; then
    gw="$(printf '%s\n' "$gw" | sed 1d)"
    [ -n "$gw" ] || gw="$remotes"
  elif [ "$2" != clone ]; then
    repo=""
    for w in $gw; do
      if printf '%s\n' "$remotes" | grep -qxF -- "$w"; then repo="$w"; break; fi
      case "$w" in */* | *:* | .) repo="$w"; break ;; esac
    done
    [ -n "$repo" ] || gw="$gw
$(git -C "$1" ls-remote --get-url 2>/dev/null)"
  fi
  printf '%s\n' "$gw" | while IFS= read -r w; do
    [ -n "$w" ] || continue
    u="$(git -C "$1" ls-remote --get-url "$w" 2>/dev/null)" || u="$w"
    if printf '%s\n' "$u" | grep -qiE '^https?://([^/@]*@)?(www\.)?github\.com(:[0-9]+)?(/|$)'; then echo yes; break; fi
  done | grep -q yes
}

# Decision 0025: who called, read once and only when a rule needs it. A
# sub-agent's call carries an agent id; the main session's carries none.
who=""
who() {
  [ -z "$who" ] || return 0
  who="$(printf '%s' "$input" | jq -r '[.agent_id // "", .agent_type // "", .session_id // "", "end"] | join("\u001f")' 2>/dev/null)" || who=""
  IFS="$(printf '\037')" read -r agent_id agent_type session_id _ <<EOF2
$who
EOF2
  who=yes
}
pm_lib=""
pm_lib() {
  [ -z "$pm_lib" ] || return 0
  # shellcheck disable=SC1091 # pm-lib.sh, beside this script
  . "$(dirname "$0")/pm-lib.sh"
  pm_session "${CLAUDE_PROJECT_DIR:-.}"
  pm_lib=yes
}


# Decision 0027. place <dir>: sets placed to main (the main checkout of an
# adopting repository), linked (a linked work tree of one), none (in no
# adopting repository) or missing (no such directory as the guard runs),
# and p_top and p_common. One git call a directory, kept for the next ask.
placed_dir="" placed="" p_top="" p_common=""
place() {
  [ "$1" != "$placed_dir" ] || [ -z "$placed" ] || return 0
  placed_dir="$1" placed=none p_top="" p_common=""
  while IFS="$tab" read -r c_dir c_placed c_top c_common; do
    [ "$c_dir" = "$1" ] || continue
    placed="$c_placed" p_top="$c_top" p_common="$c_common"
    return 0
  done <<EOF3
$place_cache
EOF3
  if [ ! -d "$1" ]; then
    placed=missing
  else
    p_out="$(git -C "$1" rev-parse --path-format=absolute --show-toplevel --git-dir --git-common-dir 2>/dev/null)" || p_out=""
    p_git=""
    { IFS= read -r p_top && IFS= read -r p_git && IFS= read -r p_common; } <<EOF3 || p_top=""
$p_out
EOF3
    if [ -n "$p_top" ] && [ -x "$p_top/scripts/guard-branch.sh" ]; then
      if [ "$p_git" = "$p_common" ]; then placed=main; else placed=linked; fi
    fi
  fi
  place_cache="$place_cache
$1$tab$placed$tab${p_top:--}$tab${p_common:--}"
}
place_cache=""
project_adopts() { [ -x "${CLAUDE_PROJECT_DIR:-/nonexistent}/scripts/guard-branch.sh" ]; }
# refuse27 <kind> <rule> <directory> <form>: the two lines, the block, and
# one line in the refusal log: the kind and the form, never the command.
refuse27() {
  case "$1" in
    branch-switch | path-without-dashes)
      printf 'guard-route: refusing to switch the branch of the main checkout, %s\n' "$3" >&2
      printf 'guard-route: rule 27.2: parallel sessions share it; work in a worktree on change/<id>, made by /change. To restore a path: git checkout -- <path>.\n' >&2 ;;
    pr-main-checkout)
      printf 'guard-route: refusing gh pr create in the main checkout, %s\n' "$3" >&2
      printf 'guard-route: rule 27.1: a change pull request is opened from its worktree on change/<id>, made by /change.\n' >&2 ;;
    pr-label)
      printf 'guard-route: refusing gh pr create with no class label in %s\n' "$3" >&2
      printf 'guard-route: rule 27.1: run /change, which opens the pull request with --label class:<class>.\n' >&2 ;;
    unplaced)
      r_what="a branch switch"
      [ "$2" != 27.1 ] || r_what="gh pr create"
      printf 'guard-route: refusing %s in a directory the guard cannot place: %s\n' "$r_what" "$3" >&2
      printf 'guard-route: rule %s: run it as its own command, from the worktree made by /change.\n' "$2" >&2 ;;
  esac
  status=2
  who
  pm_lib
  r_caller=main
  [ -z "${agent_id:-}" ] || r_caller="$agent_id ${agent_type:--}"
  # The repository as the commit check logs it: its key when it is the
  # session's own or the directory is in none, its root otherwise.
  r_repo="${pm_own_key:--}"
  case "$placed" in
    main | linked) [ "$1" = unplaced ] || [ "$p_common" = "$pm_own_common" ] || r_repo="$p_top" ;;
  esac
  pm_log refusals.log "$(pm_now)" "${session_id:--}" pm "$r_caller" "$3" "$r_repo" "$1" "$4"
  [ "$pm_logged" = true ] || printf 'guard-route: the refusal could not be written to the refusal log.\n' >&2
}

while IFS="$tab" read -r kind target reason file; do
  if [ "$kind" = sw ] || [ "$kind" = pr ] || [ "$kind" = unread27 ]; then
    # Rules 27.1 and 27.2 bind the callers of a PM session, and no other.
    [ "${PAP_MODE:-}" = pm ] || continue
    if [ "$kind" = unread27 ]; then
      # One of the four verbs where the guard cannot tell what runs it: let
      # through, and counted.
      who
      # shellcheck disable=SC1091 # pm-lib.sh, beside this script
      . "$(dirname "$0")/pm-lib.sh"
      r_caller=main
      [ -z "${agent_id:-}" ] || r_caller="$agent_id ${agent_type:--}"
      pm_log refusals.log "$(pm_now)" "${session_id:--}" pm "$r_caller" - - unread
      continue
    fi
    # sw: the verdict and the rest; pr: the count of class labels (in
    # reason) and the rest.
    t_a="$reason" rule=27.1
    if [ "$kind" = sw ]; then
      rule=27.2
      IFS="$(printf '\037')" read -r t_a t_flag t_written t_form _ <<EOF2
$file
EOF2
    else
      IFS="$(printf '\037')" read -r t_flag t_written t_form _ <<EOF2
$file
EOF2
    fi
    if [ "$t_flag" = placed ]; then
      place "$target"
      [ "$placed" != missing ] || { t_flag=unplaced; [ "$t_written" != - ] || t_written="$target"; }
    else
      placed=""
    fi
    if [ "$t_flag" = unplaced ]; then
      ! project_adopts || refuse27 unplaced "$rule" "$t_written" "$t_form"
    elif [ "$kind" = sw ]; then
      [ "$placed" != main ] || refuse27 "$t_a" 27.2 "$target" "$t_form"
    elif [ "$placed" = main ]; then
      refuse27 pr-main-checkout 27.1 "$target" "$t_form"
    elif [ "$t_a" != 1 ]; then
      # Bound in an adopting repository, and anywhere when the session's
      # own project is one, whatever -R names.
      { [ "$placed" != linked ] && ! project_adopts; } || refuse27 pr-label 27.1 "$target" "$t_form"
    fi
    continue
  fi
  if [ "$kind" = papmode ]; then
    printf 'guard-route: refusing %s set or unset in an agent'"'"'s command in %s\n' "$reason" "$target" >&2
    printf 'guard-route: rule 25.1: the mode is set by pap claude and stays so; the owner starts a solo session with pap claude --solo, from their own terminal.\n' >&2
    status=2
    continue
  fi
  if [ "$kind" = pmscript ]; then
    who
    [ -n "${agent_id:-}" ] || continue
    printf 'guard-route: refusing %s run from a sub-agent'"'"'s command in %s\n' "$reason" "$target" >&2
    printf 'guard-route: decision 0025: /pap:pm needs the PM session, the main one; a cycle launches no cycle and writes no tracker.\n' >&2
    status=2
    continue
  fi
  if [ "$kind" = pmcommit ]; then
    [ "${PAP_MODE:-}" = pm ] || continue
    who
    [ -z "${agent_id:-}" ] || continue
    pm_lib
    out_tmp="$(mktemp)" || continue
    pm_commit_outside "$target" > "$out_tmp"
    if [ -s "$out_tmp" ]; then
      printf 'guard-route: refusing git commit in %s: the whole work tree is judged, and it holds changes outside the PM paths: %s\n' \
        "$pm_top" "$(head -n 10 "$out_tmp" | tr '\n' ' ' | sed 's/ $//')$([ "$(wc -l < "$out_tmp")" -le 10 ] || printf ' and more')" >&2
      printf 'guard-route: rule 25.2: a PM session commits only the PM paths. Commit from the change'"'"'s own work tree, or have whoever owns each file move it; never stash, clean, check out or delete a file to clear this. Report the files to the owner and stop.\n' >&2
      # The repository as guard-pm.sh logs it: its key when it is the
      # session's own, its root otherwise.
      c_repo="$pm_top"
      [ "$pm_common" != "$pm_own_common" ] || c_repo="$pm_own_key"
      while IFS= read -r f; do
        pm_log refusals.log "$(pm_now)" "${session_id:--}" pm main "$f" "$c_repo" commit
      done < "$out_tmp"
      status=2
    fi
    rm -f "$out_tmp"
    continue
  fi
  if [ "$kind" = keyring ]; then
    printf 'guard-route: refusing a read of gh'"'"'s keyring entry or token (%s) in %s\n' "$reason" "$target" >&2
    printf 'guard-route: rule 23.4: the owner'"'"'s gh token stays out of agent shells; an agent acts as pap-agent through the gh shim.\n' >&2
    status=2
    continue
  fi
  if [ "$kind" = agentdir ]; then
    printf 'guard-route: refusing a command that names the agent gh directory or signs gh in (%s) in %s\n' "$reason" "$target" >&2
    printf 'guard-route: rule 23.4: the agent gh directory stays empty; an agent acts as pap-agent through the gh shim.\n' >&2
    status=2
    continue
  fi
  if [ "$kind" = ownerscript ]; then
    printf 'guard-route: refusing %s run from an agent'"'"'s command in %s\n' "$reason" "$target" >&2
    printf 'guard-route: rule 23.4: /pap:reviewed and /pap:accept act as the owner; only the owner invokes them, as skills.\n' >&2
    status=2
    continue
  fi
  if [ "$kind" = ghconfig ]; then
    # In every repository: the owner's sign-in is out of every agent shell.
    printf 'guard-route: refusing %s set in an agent'"'"'s command in %s\n' "$reason" "$target" >&2
    printf 'guard-route: rule 23.4: an agent shell carries no owner sign-in; only /pap:reviewed and /pap:accept reach the owner'"'"'s gh directory.\n' >&2
    status=2
    continue
  fi
  root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" || root=""
  guard="$root/scripts/guard-branch.sh"
  if [ -z "$root" ] || [ ! -x "$guard" ]; then
    # Rule 23.4 outside adopting repositories: in a session whose project
    # adopts PAP, gh, and git to GitHub, need pap claude in any directory (a
    # companion repository, a scratch clone, no repository at all). Other
    # sessions are not pap's to refuse.
    case "$kind" in ghcall | gitnet) ;; *) continue ;; esac
    [ -x "${CLAUDE_PROJECT_DIR:-/nonexistent}/scripts/guard-branch.sh" ] || continue
    d="${root:-$target}"
    [ -d "$d" ] || d="$CLAUDE_PROJECT_DIR"
    [ "$kind" = ghcall ] || github_https "$d" "$reason" "$file" || continue
    session_ok "$d" && continue
    [ "$kind" = ghcall ] || reason="git $reason"
    printf 'guard-route: refusing %s in %s: this Claude Code session was not started by pap claude, so it could act as your own GitHub sign-in\n' "$reason" "$d" >&2
    printf 'guard-route: rule 23.4: quit and start the session with pap claude (pap claude --resume to keep this conversation).\n' >&2
    status=2
    continue
  fi
  case "$kind" in
    branch)
      (cd "$root" && "$guard" branch) || status=2
      ;;
    push)
      # Each word after `git push`; guard-branch.sh decides what is a force
      # push. An older guard without push-args exits 64 and lets it through.
      words="$(printf '%s' "$reason" | tr '\037' '\n')"
      (
        cd "$root" || exit 0
        set -f
        IFS='
'
        # shellcheck disable=SC2086 # split on newlines on purpose
        "$guard" push-args $words
        rc=$?
        [ "$rc" = 64 ] && exit 0
        exit "$rc"
      ) || status=2
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
    ghpath)
      printf 'guard-route: refusing gh run as %s, past the pap gh shim, in %s\n' "$reason" "$root" >&2
      printf 'guard-route: rule 23.1: run gh by name with PATH as it is, so the shim gives it the pap-agent token.\n' >&2
      status=2
      ;;
    ghcall | gitnet)
      [ "$kind" = ghcall ] || github_https "$root" "$reason" "$file" || continue
      session_ok "$root" && continue
      [ "$kind" = ghcall ] || reason="git $reason"
      printf 'guard-route: refusing %s in %s: this Claude Code session was not started by pap claude, so it could act as your own GitHub sign-in\n' "$reason" "$root" >&2
      printf 'guard-route: rule 23.4: quit and start the session with pap claude (pap claude --resume to keep this conversation).\n' >&2
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

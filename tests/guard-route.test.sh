#!/bin/sh
# guard-route.test.sh: regression tests for the decision 0002 hook layer
# (plugins/pap/hooks/guard-route.sh routing to scripts/guard-branch.sh).
#
# Usage: sh tests/guard-route.test.sh
#
# Builds throwaway repositories in a temporary directory, feeds the router
# synthetic PreToolUse input, and checks its exit code: 2 blocks the call,
# 0 lets it through. Prints one TAP-style line per case and exits 1 if any
# case fails. Needs git and jq; touches nothing outside the temporary
# directory.
#
#   G     adopts decision 0002, on main
#   G2    adopts decision 0002, on change/x
#   G sp  adopts decision 0002, on main, path contains a space
#   D     adopts decision 0002, detached HEAD
#   U     does not adopt decision 0002, on main

set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
router="$here/plugins/pap/hooks/guard-route.sh"
guard="$here/scripts/guard-branch.sh"

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'Bail out! %s not found\n' "$tool"; exit 1; }
done

# pwd -P: macOS's temporary directory is under a symlink (/var to
# /private/var), and git and pwd report the resolved path.
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT INT TERM
# The machine's git config is not this suite's: a global insteadOf
# rewrite, for one, turns the SSH remotes below into HTTPS ones.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$T/gitconfig"
: > "$GIT_CONFIG_GLOBAL"
# The owner's terminal exports GH_CONFIG_DIR (rule 23.4); the hook refuses
# everything while it is set, so the suite runs without it.
unset GH_CONFIG_DIR 2>/dev/null || true

mkrepo() {
  git init -q -b main "$1"
  git -C "$1" -c user.name=test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q --allow-empty -m init
}
adopt() {
  mkdir -p "$1/scripts"
  cp "$guard" "$1/scripts/guard-branch.sh"
}

mkrepo "$T/G"    && adopt "$T/G"
mkrepo "$T/G2"   && adopt "$T/G2" && git -C "$T/G2" switch -q -c change/x
mkrepo "$T/G sp" && adopt "$T/G sp"
mkrepo "$T/D"    && adopt "$T/D"  && git -C "$T/D" switch -q --detach
mkrepo "$T/U"

n=0
failed=0

# check <expected exit> <cwd> <command> [tool name]
check() {
  n=$((n + 1))
  input="$(jq -nc --arg c "$3" --arg d "$2" --arg t "${4:-Bash}" \
    '{tool_name: $t, cwd: $d, tool_input: {command: $c}}')"
  printf '%s' "$input" | "$router" >/dev/null 2>&1
  rc=$?
  label="cwd=${2#"$T"/} ${4:+[$4] }$(printf '%s' "$3" | tr '\n' '~')"
  if [ "$rc" = "$1" ]; then
    printf 'ok %d - %s\n' "$n" "$label"
  else
    printf 'not ok %d - %s (exit %s, expected %s)\n' "$n" "$label" "$rc" "$1"
    failed=$((failed + 1))
  fi
}

# The session's own repository.
check 2 "$T/G"  'git commit -m x'
check 0 "$T/G2" 'git commit -m x'
check 2 "$T/D"  'git commit -m x'
check 0 "$T/U"  'git commit -m x'

# A session in a guarded repository must not block others (the dotfiles case).
check 0 "$T/G"  "cd $T/U && git commit -m x"
check 0 "$T/G"  "git -C $T/U commit -m x"

# A session elsewhere must not reach a guarded main.
check 2 "$T/U"  "cd $T/G && git commit -m x"
check 2 "$T/U"  "git -C $T/G commit -m x"
check 2 "$T/G2" "git -C $T/G push origin main"
check 2 "$T/U"  "git -c user.name=x -C $T/G commit"
check 2 "$T/G2" "cd ../G && GIT_AUTHOR_NAME=x git commit -m y"
check 2 "$T/U"  "cd \"$T/G sp\" && git commit -m x"

# Separators, subshells and sequences.
check 2 "$T/G"  "cd $T/U; git commit -m a && cd $T/G && git push"
check 2 "$T/U"  "(cd $T/G && git commit -m x)"
check 2 "$T/U"  "echo start | cat && cd $T/G && git commit -m x"
check 0 "$T/U"  "cd $T/G && git status && cd $T/U && git commit -m x"
check 0 "$T/G2" "cd ../G2 && git commit -m x"

# Not a commit or push, or not a Bash call.
check 0 "$T/U"  'git status'
check 0 "$T/G"  'git log --oneline | grep commit'
check 0 "$T/U"  "git -C $T/G log"
check 0 "$T/G"  'git commit -m x' Edit

# Targets that are not repositories.
check 0 "$T/U"  'cd ~/does-not-exist && git commit -m x'

# Decision 0005: hook bypasses are refused in an adopting repository. G2 is
# on change/x, so the branch check passes and only the bypass can refuse.
# Each pattern: direct, after cd, through git -C, after env, and in && and ;
# sequences.
for bypass in 'LEFTHOOK=0 git commit -m x' 'LEFTHOOK_EXCLUDE=lint git commit -m x' \
              'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -anm x' \
              'git push --no-verify' 'git config core.hooksPath /dev/null'; do
  check 2 "$T/G2" "$bypass"
  check 2 "$T/U"  "cd $T/G2 && $bypass"
  check 2 "$T/G2" "env $bypass"
  check 2 "$T/U"  "cd $T/G2 && true && $bypass"
  check 2 "$T/U"  "cd $T/G2; $bypass"
done
check 2 "$T/U"  "git -C $T/G2 commit --no-verify -m x"
check 2 "$T/U"  "git -C $T/G2 commit -n -m x"
check 2 "$T/U"  "git -C $T/G2 push --no-verify"
check 2 "$T/U"  "git -C $T/G2 config core.hooksPath /dev/null"
check 2 "$T/U"  "LEFTHOOK=0 git -C $T/G2 commit -m x"
check 2 "$T/U"  "LEFTHOOK_EXCLUDE=lint git -C $T/G2 commit -m x"
check 2 "$T/U"  "env LEFTHOOK=0 git -C $T/G2 commit -m x"
check 2 "$T/U"  "env LEFTHOOK_EXCLUDE=lint git -C $T/G2 commit -m x"
check 2 "$T/G2" 'export LEFTHOOK=0 && git commit -m x'
check 2 "$T/G2" 'LEFTHOOK=0; git commit -m x'
check 2 "$T/G2" 'export LEFTHOOK=0'
check 2 "$T/G2" 'git commit --no-veri -m x'
check 2 "$T/G2" 'git -c core.hooksPath=/dev/null commit -m x'
check 2 "$T/G2" 'git --config-env=core.hooksPath=H commit -m x'
check 2 "$T/G2" 'git config --local core.HooksPath .no-hooks'

# Near misses that must pass.
check 0 "$T/G2" 'git commit -m "skip --no-verify next time"'
check 0 "$T/G2" "git commit -m 'why LEFTHOOK=0 is refused'"
check 0 "$T/G2" 'LEFTHOOK_VERBOSE=1 git commit -m x'

# Rule 23.4: GH_CONFIG_DIR set in an agent's command, in every repository.
for cwd in "$T/G2" "$T/U"; do
  check 2 "$cwd" 'GH_CONFIG_DIR=/home/x/.config/gh-owner gh pr list'
  check 2 "$cwd" 'export GH_CONFIG_DIR=/home/x/.config/gh-owner'
  check 2 "$cwd" 'export GH_CONFIG_DIR'
  check 2 "$cwd" "export 'GH_CONFIG_DIR=/x' && gh pr list"
  check 2 "$cwd" 'env GH_CONFIG_DIR=/x gh pr list'
  check 2 "$cwd" 'declare -x GH_CONFIG_DIR=/x; gh api user'
  check 2 "$cwd" 'cd /tmp && GH_CONFIG_DIR=/x git push'
done
check 0 "$T/G2" 'unset GH_CONFIG_DIR && gh pr list'
check 0 "$T/G2" 'env -u GH_CONFIG_DIR gh pr list'
# shellcheck disable=SC2016 # the command is the hook's input, unexpanded
check 0 "$T/G2" 'echo "$GH_CONFIG_DIR"'
check 0 "$T/G2" 'GH_CONFIG_DIRS=x gh pr list'
check 2 "$T/G2" 'GH_CONFIG_DIR+=/x gh pr list'
check 2 "$T/U"  'export GH_CONFIG_DIR+=/x'
check 2 "$T/U"  'env -u GH_CONFIG_DIR GH_CONFIG_DIR=/x gh pr list'
check 0 "$T/U"  'grep -rn GH_CONFIG_DIR= docs'
check 0 "$T/U"  'echo GH_CONFIG_DIR=/x'
# A session started as plain claude from the owner's terminal: every Bash
# call is refused, in every repository.
n=$((n + 1))
bad=""
for c in 'ls' 'git status'; do
  printf '%s' "$(jq -nc --arg c "$c" --arg d "$T/U" '{tool_name: "Bash", cwd: $d, tool_input: {command: $c}}')" |
    GH_CONFIG_DIR="$T/owner" "$router" >/dev/null 2>&1
  [ $? = 2 ] || bad="$bad $c;"
done
if [ -z "$bad" ]; then
  printf 'ok %d - GH_CONFIG_DIR in the session environment refuses every Bash call\n' "$n"
else
  printf 'not ok %d - GH_CONFIG_DIR in the session environment refuses every Bash call (passed:%s)\n' "$n" "$bad"
  failed=$((failed + 1))
fi

# Rule 23.1: gh by a path or with PATH changed skips the shim, in an
# adopting repository; command gh and env gh find the shim and pass.
check 2 "$T/G2" '/usr/bin/gh pr list'
check 2 "$T/G2" "\"$HOME/.local/share/mise/installs/gh/2.0.0/bin/gh\" pr list"
# shellcheck disable=SC2088 # the command is the hook's input, unexpanded
check 2 "$T/G2" '~/bin/gh api user'
check 2 "$T/G2" './gh pr list'
check 2 "$T/G2" 'command /usr/bin/gh pr list'
check 2 "$T/G2" 'env /usr/bin/gh pr list'
check 2 "$T/G2" 'PATH=/usr/bin gh pr list'
check 2 "$T/G2" 'env PATH=/usr/bin gh pr list'
check 2 "$T/G2" 'git status && /usr/bin/gh pr list'
check 0 "$T/G2" 'gh pr list'
check 0 "$T/G2" 'command gh pr list'
check 0 "$T/G2" 'env gh pr list'
check 0 "$T/G2" 'cat scripts/shim/gh'
check 0 "$T/U"  '/usr/bin/gh pr list'
check 0 "$T/G2" 'git push -n origin change/x'
check 0 "$T/G2" 'git commit -m n'
check 0 "$T/G2" 'git commit -uno -m x'
check 0 "$T/G2" 'git commit -m "fix core.hooksPath docs"'
check 0 "$T/G2" 'git log --grep=--no-verify'

# A bypass in a repository that does not adopt PAP is not this hook's business.
check 0 "$T/U"  'git commit --no-verify -m x'
check 0 "$T/G2" "LEFTHOOK=0 git -C $T/U commit -m x"
check 0 "$T/G2" "cd $T/U && git config core.hooksPath /dev/null"

# Decision 0012: an agent may not write an Approved-by line into a pull
# request body, by any route, even to keep one the live body already has.
printf 'Summary\n- [ ] No protected path touched\n  Approved-by: @owner\n' > "$T/G2/approved.md"
printf 'Summary\nApproved by the owner later.\n' > "$T/G2/plain.md"
printf '{"body":"x\\napproved-BY: @owner"}' > "$T/G2/approved.json"
printf '{"body":"x\\nno approval"}' > "$T/G2/plain.json"
nl='
'
check 2 "$T/G2" "gh pr create --draft --title t --body \"x${nl}Approved-by: @owner\""
check 0 "$T/G2" "gh pr create --draft --title t --body \"x${nl}no approval\""
check 2 "$T/G2" "gh pr edit 7 -b 'x${nl}  approved-BY: @owner'"
check 0 "$T/G2" "gh pr edit 7 -b 'x'"
check 2 "$T/G2" "gh pr edit 7 --body=\$'x\\nApproved-by: @owner'"
check 2 "$T/G2" 'gh pr create --body-file approved.md'
check 0 "$T/G2" 'gh pr create --body-file plain.md'
check 2 "$T/U"  "cd $T/G2 && gh pr edit 7 -F approved.md"
check 2 "$T/G2" "gh pr edit 7 -F $T/G2/approved.md"
check 0 "$T/G2" 'gh pr edit 7 -F missing.md'
check 2 "$T/G2" "gh pr edit 7 --body-file - <<'EOF'${nl}Summary${nl}Approved-by: @owner${nl}EOF"
check 0 "$T/G2" "gh pr edit 7 --body-file - <<'EOF'${nl}Summary${nl}EOF"
check 2 "$T/G2" "cat <<EOF | gh pr create -F -${nl}Approved-By:@owner${nl}EOF"
check 2 "$T/G2" "gh pr create --body \"\$(cat <<'EOF'${nl}Approved-by: @owner${nl}EOF${nl})\""
check 0 "$T/G2" "gh pr create --body \"\$(cat <<'EOF'${nl}Summary${nl}EOF${nl})\""
check 2 "$T/G2" "gh api repos/o/r/pulls/7 -X PATCH -f body=\"x${nl}Approved-by: @owner\""
check 0 "$T/G2" "gh api repos/o/r/pulls/7 -X PATCH -f body=\"x${nl}no approval\""
check 2 "$T/G2" 'gh api repos/o/r/pulls/7 -X PATCH -F body=@approved.md'
check 0 "$T/G2" 'gh api repos/o/r/pulls/7 -X PATCH -F body=@plain.md'
check 2 "$T/G2" 'gh api -X PATCH repos/o/r/pulls/7 --input approved.json'
check 0 "$T/G2" 'gh api -X PATCH repos/o/r/pulls/7 --input plain.json'
check 2 "$T/G2" "gh api -X PATCH repos/o/r/pulls/7 --input - <<'EOF'${nl}{\"body\":\"x\\nApproved-by: @owner\"}${nl}EOF"
check 2 "$T/G2" "gh api repos/o/r/pulls -f title=t -f head=change/x -f base=main -f body=\"Approved-by: @owner\""

# Approved-by elsewhere, not in a pull request body, passes.
check 0 "$T/G2" "git commit -m \"x${nl}${nl}Approved-by: @owner\""
check 0 "$T/G2" "git commit -F - <<'EOF'${nl}x${nl}Approved-by: @owner${nl}EOF"
check 0 "$T/G2" "gh pr comment 7 --body \"Approved-by: @owner\""
check 0 "$T/G2" "gh pr view 7 --json body | grep -i 'Approved-by:'"
check 0 "$T/G2" "gh pr create --title 'Approved-by: @owner' --body x"
check 0 "$T/G2" "gh pr edit 7 --body \"see the Approved-by: line\""
check 0 "$T/G2" "gh api repos/o/r/issues/7/comments -f body=\"Approved-by: @owner\""
check 0 "$T/U"  "gh pr edit 7 --body \"Approved-by: @owner\""
# Decision 0013: the box's "Head to approve:" reason is the agent's, and
# passes; the Approved-by line it asks for stays the owner's.
printf 'Summary\n- [ ] No protected path touched, or an owner has approved the head: Approved-by: @login <sha> below\n  Head to approve: 3f9c2a7\n' > "$T/G2/head.md"
check 0 "$T/G2" 'gh pr edit 7 --body-file head.md'
check 0 "$T/G2" "gh pr create --draft --title t --body \"x${nl}  Head to approve: 3f9c2a7\""
check 2 "$T/G2" "gh pr edit 7 --body \"x${nl}  Head to approve: 3f9c2a7${nl}  Approved-by: @owner 3f9c2a7\""

# Decision 0016: an agent may not add the owner-reviewed label or merge, by
# any route, in an adopting repository (rule 16.2).
printf '{"labels":["bug","Owner-Reviewed"]}' > "$T/G2/labels.json"
printf '[{"name":"owner-reviewed"}]' > "$T/G2/named.json"
printf '{"labels":["owner-reviewed-not"]}' > "$T/G2/other.json"
check 2 "$T/G2" 'gh pr edit 7 --add-label owner-reviewed'
check 2 "$T/G2" 'gh pr edit 7 --add-label=OWNER-REVIEWED'
check 2 "$T/G2" 'gh pr edit 7 --add-label "bug, owner-reviewed"'
check 2 "$T/G2" 'gh pr edit 7 --add-label bug --add-label owner-reviewed'
check 2 "$T/G2" 'gh issue edit 7 --add-label owner-reviewed'
check 2 "$T/U"  "cd $T/G2 && gh pr edit 7 --add-label owner-reviewed"
check 2 "$T/G2" 'gh pr create --draft --title t --body x -l owner-reviewed'
check 2 "$T/G2" 'gh pr create --draft --title t --body x --label class:feature,owner-reviewed'
check 2 "$T/G2" 'gh issue create --title t --body x --label Owner-reviewed'
check 2 "$T/G2" 'gh label edit approved --name owner-reviewed'
check 2 "$T/G2" 'gh api repos/o/r/issues/7/labels -f "labels[]=owner-reviewed"'
check 2 "$T/G2" 'gh api -X PUT repos/o/r/issues/7/labels -f labels[]=bug -f labels[]=owner-reviewed'
check 2 "$T/G2" 'gh api -X PATCH repos/o/r/issues/7 -F labels=owner-reviewed'
check 2 "$T/G2" 'gh api repos/o/r/issues/7/labels --input labels.json'
check 2 "$T/G2" "gh api repos/o/r/issues/7/labels --input $T/G2/named.json"
check 2 "$T/G2" "gh api repos/o/r/issues/7/labels --input - <<'EOF'${nl}{\"labels\":[\"owner-reviewed\"]}${nl}EOF"
check 2 "$T/G2" 'gh api -X PATCH repos/o/r/labels/approved -f new_name=owner-reviewed'
check 2 "$T/G2" 'gh pr merge 7'
# The /pap:reviewed skill runs its script through the Bash tool when a person
# invokes it; the hook lets the script through, as it does any script, and
# still refuses the direct gh call above. Rule 16.2 and the skill's
# disable-model-invocation keep the agent from the script; since rule 23.4
# the script acts as the owner, and an agent running it by path is an
# escape the hook cannot tell from the person's invocation.
check 0 "$T/G2" 'sh plugins/pap/skills/reviewed/reviewed.sh "7 abc1234"'
check 0 "$T/G2" '/home/u/.claude/plugins/cache/pap/skills/reviewed/reviewed.sh "7" "abc1234"'
check 2 "$T/G2" 'gh pr merge --auto --squash 7'
check 2 "$T/G2" 'git push && gh pr merge 7 --merge --delete-branch'
check 2 "$T/U"  "cd $T/G2; gh pr merge"
check 2 "$T/G2" 'gh api -X PUT repos/o/r/pulls/7/merge'
check 2 "$T/G2" 'gh api --method=put repos/o/r/pulls/7/merge -f merge_method=squash'

# Near misses that must pass: removing the label, other labels and reads.
check 0 "$T/G2" 'gh pr edit 7 --remove-label owner-reviewed'
check 0 "$T/G2" 'gh pr edit 7 --add-label owner-reviewed-not'
check 0 "$T/G2" 'gh pr edit 7 --add-label class:feature --remove-label owner-reviewed'
check 0 "$T/G2" 'gh pr create --draft --title owner-reviewed --body x --label class:feature'
check 0 "$T/G2" 'gh pr view 7'
check 0 "$T/G2" "gh pr view 7 --json labels -q '.labels[].name' | grep owner-reviewed"
check 0 "$T/G2" 'git commit -m "docs: say why gh pr merge is refused"'
check 0 "$T/G2" "gh pr comment 7 --body 'please run gh pr merge and add owner-reviewed'"
check 0 "$T/G2" 'gh pr checks 7 --watch'
check 0 "$T/G2" 'gh label create owner-reviewed-not'
check 0 "$T/G2" 'gh label edit owner-reviewed --description "the owner reviewed it"'
check 0 "$T/G2" 'gh api -X DELETE repos/o/r/issues/7/labels/owner-reviewed'
check 0 "$T/G2" 'gh api repos/o/r/issues/7/labels -f "labels[]=owner-reviewed-not"'
check 0 "$T/G2" 'gh api repos/o/r/issues/7/labels --input other.json'
check 0 "$T/G2" 'gh api -X PATCH repos/o/r/issues/7 -f body="owner-reviewed"'
check 0 "$T/G2" 'gh api repos/o/r/pulls/7/merge'
check 0 "$T/G2" 'gh api repos/o/r/issues/7/comments -f body="gh pr merge"'
check 0 "$T/U"  'gh pr merge 7'
check 0 "$T/U"  'gh pr edit 7 --add-label owner-reviewed'

# Decision 0022: no force push from an agent, on any branch. G2 is on
# change/x, so the branch check passes and only the force check can refuse.
for force in '--force' '-f' '-uf' '-fu' '--force-with-lease' \
             '--force-with-lease=change/x:abc123' '--force-if-includes' \
             '--force-with-lease --force-if-includes'; do
  check 2 "$T/G2" "git push $force origin change/x"
  check 2 "$T/U"  "git -C $T/G2 push $force origin change/x"
  check 2 "$T/U"  "cd $T/G2 && git push $force"
done
check 2 "$T/G2" 'git push origin +change/x'
check 2 "$T/G2" "git push origin '+change/x'"
check 2 "$T/G2" 'git push origin +HEAD:refs/heads/change/x'
check 2 "$T/G2" 'git add . && git commit -m x && git push -f'
check 2 "$T/G2" 'git push --mirror origin'

# Near misses that must pass: a plain push, an upstream, a delete, the
# negated options, a force in a message, and a repository that does not
# adopt PAP.
check 0 "$T/G2" 'git push'
check 0 "$T/G2" 'git push origin change/x'
check 0 "$T/G2" 'git push -u origin change/x'
check 0 "$T/G2" 'git push origin --delete change/old'
check 0 "$T/G2" 'git push -d origin change/old'
check 0 "$T/G2" 'git push --no-force-with-lease origin change/x'
check 0 "$T/G2" 'git push --no-force-if-includes'
check 0 "$T/G2" "git commit -m 'docs: never git push --force'"
check 0 "$T/U"  'git push --force'

# A repository whose guard predates push-args (exit 64) lets the push through.
mkrepo "$T/O" && mkdir -p "$T/O/scripts" && git -C "$T/O" switch -q -c change/x
sed 's/^  push-args)$/  push-args-not-here)/' "$guard" > "$T/O/scripts/guard-branch.sh"
chmod +x "$T/O/scripts/guard-branch.sh"
check 0 "$T/O" 'git push --force'

# Rule 23.1, decision 0023: an agent's push to an SSH remote is refused,
# named or by default, and the HTTPS fix is named. S is on change/x with
# an SSH origin and an HTTPS remote beside it; U is not guarded.
mkrepo "$T/S" && adopt "$T/S" && git -C "$T/S" switch -q -c change/x
git -C "$T/S" remote add origin git@github.com:example-owner/example-repo.git
git -C "$T/S" remote add https https://github.com/example-owner/example-repo.git
git -C "$T/S" remote add scheme ssh://git@github.com/example-owner/example-repo.git
check 2 "$T/S" 'git push'
check 2 "$T/S" 'git push -u origin change/x'
check 2 "$T/S" 'git push scheme change/x'
check 2 "$T/S" 'git push git@github.com:example-owner/example-repo.git change/x'
check 2 "$T/U" "git -C $T/S push origin change/x"
git -C "$T/S" config branch.change/x.pushRemote origin
check 2 "$T/S" 'git push'
git -C "$T/S" config --unset branch.change/x.pushRemote
# Near misses: an HTTPS remote, an HTTPS URL, a local path, an unguarded
# repository with an SSH origin.
check 0 "$T/S" 'git push https change/x'
check 0 "$T/S" 'git push https://github.com/example-owner/example-repo.git change/x'
check 0 "$T/S" "git push $T/elsewhere.git change/x"
git -C "$T/S" config branch.change/x.pushRemote https
check 0 "$T/S" 'git push'
git -C "$T/S" config --unset branch.change/x.pushRemote
mkrepo "$T/US" && git -C "$T/US" remote add origin git@github.com:example-owner/example-repo.git
check 0 "$T/US" 'git push origin main'
# With the insteadOf rewrite pap agent-setup offers, an SSH origin pushes
# over HTTPS, so the push passes.
git config --global url.https://github.com/.insteadOf git@github.com:
check 0 "$T/S" 'git push -u origin change/x'
: > "$GIT_CONFIG_GLOBAL"
# The refusal names the fix.
n=$((n + 1))
msg="$(jq -nc --arg d "$T/S" '{tool_name: "Bash", cwd: $d, tool_input: {command: "git push"}}' | "$router" 2>&1 >/dev/null)"
if printf '%s\n' "$msg" | grep -qF 'git remote set-url origin https://github.com/example-owner/example-repo.git'; then
  printf 'ok %d - SSH push refusal names the set-url fix\n' "$n"
else
  printf 'not ok %d - SSH push refusal names the set-url fix\n' "$n"
  printf '%s\n' "$msg" | sed 's/^/# /'
  failed=$((failed + 1))
fi

# Without jq the router cannot parse; it complains only where the session's
# own repository is guarded, and never blocks.
mkdir -p "$T/bin"
for b in git cat; do ln -s "$(command -v "$b")" "$T/bin/$b"; done
for repo in G U; do
  n=$((n + 1))
  printf '{}' | env -i HOME="$HOME" PATH="$T/bin" CLAUDE_PROJECT_DIR="$T/$repo" \
    /bin/sh "$router" >/dev/null 2>&1
  rc=$?
  want=0
  [ "$repo" = G ] && want=1
  if [ "$rc" = "$want" ]; then
    printf 'ok %d - no jq, session in %s\n' "$n" "$repo"
  else
    printf 'not ok %d - no jq, session in %s (exit %s, expected %s)\n' "$n" "$repo" "$rc" "$want"
    failed=$((failed + 1))
  fi
done

printf '1..%d\n' "$n"
[ "$failed" = 0 ] || { printf '# %d of %d failed\n' "$failed" "$n"; exit 1; }
